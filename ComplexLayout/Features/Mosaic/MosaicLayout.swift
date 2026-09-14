//
//  MosaicLayout.swift
//  ComplexLayout
//
//  A custom UICollectionViewLayout that packs tiles of differing footprints
//  (1×1, 2×1, 1×2, 2×2, …) into a fixed column grid.
//

import UIKit

protocol MosaicLayoutDelegate: AnyObject {
    /// Footprint, in grid units, for the item at `indexPath`.
    func mosaicLayout(_ layout: MosaicLayout, spanForItemAt indexPath: IndexPath) -> TileSpan
    /// Whether the section draws a header. Defaults to `true`.
    func mosaicLayout(_ layout: MosaicLayout, hasHeaderInSection section: Int) -> Bool
}

extension MosaicLayoutDelegate {
    func mosaicLayout(_ layout: MosaicLayout, hasHeaderInSection section: Int) -> Bool { true }
}

/// Lays tiles out on a grid of `columnCount` equal columns.
///
/// Placement uses a skyline packing pass: the layout tracks the current bottom
/// edge of every column and drops each tile into the run of adjacent columns
/// where it comes to rest highest. That keeps mixed tile sizes tightly packed
/// without the caller having to hand-author a group structure the way a
/// compositional layout would require.
final class MosaicLayout: UICollectionViewLayout {

    weak var delegate: MosaicLayoutDelegate?

    /// Number of grid columns. The widest tile is clamped to this.
    var columnCount: Int = 4 {
        didSet { if columnCount != oldValue { invalidateLayout() } }
    }

    /// Horizontal gap between columns.
    var interItemSpacing: CGFloat = 10 {
        didSet { if interItemSpacing != oldValue { invalidateLayout() } }
    }

    /// Vertical gap between rows.
    var lineSpacing: CGFloat = 10 {
        didSet { if lineSpacing != oldValue { invalidateLayout() } }
    }

    /// Padding around each section's tiles.
    var sectionInset = UIEdgeInsets(top: 4, left: 16, bottom: 28, right: 16) {
        didSet { invalidateLayout() }
    }

    /// Height of a section header. Ignored for sections that report no header.
    var headerHeight: CGFloat = 56 {
        didSet { if headerHeight != oldValue { invalidateLayout() } }
    }

    /// Height of one grid row, as a multiple of the column width.
    /// `1.0` makes a 1×1 tile square.
    var rowAspectRatio: CGFloat = 1.0 {
        didSet { if rowAspectRatio != oldValue { invalidateLayout() } }
    }

    // MARK: - Cached state

    private var itemAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var headerAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    /// All attributes ordered by `frame.minY`, for the binary search in
    /// `layoutAttributesForElements(in:)`.
    private var orderedAttributes: [UICollectionViewLayoutAttributes] = []
    /// Tallest element produced by the last pass; the lookback distance the
    /// binary search needs in order not to miss a tall tile that starts above
    /// the query rect.
    private var maxElementHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0
    /// Collection view width the cached attributes were computed against.
    private var preparedBoundsWidth: CGFloat = 0

    // MARK: - UICollectionViewLayout

    override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }

        itemAttributes.removeAll(keepingCapacity: true)
        headerAttributes.removeAll(keepingCapacity: true)
        orderedAttributes.removeAll(keepingCapacity: true)
        maxElementHeight = 0
        contentHeight = 0

        let insets = collectionView.adjustedContentInset
        preparedBoundsWidth = collectionView.bounds.width
        contentWidth = preparedBoundsWidth - insets.left - insets.right

        let usableWidth = contentWidth - sectionInset.left - sectionInset.right
        let totalSpacing = interItemSpacing * CGFloat(columnCount - 1)
        let columnWidth = (usableWidth - totalSpacing) / CGFloat(columnCount)
        guard columnCount > 0, columnWidth > 0 else { return }

        let rowHeight = columnWidth * rowAspectRatio
        var cursorY: CGFloat = 0

        for section in 0..<collectionView.numberOfSections {
            if delegate?.mosaicLayout(self, hasHeaderInSection: section) ?? true {
                let indexPath = IndexPath(item: 0, section: section)
                let attributes = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    with: indexPath
                )
                attributes.frame = CGRect(
                    x: sectionInset.left,
                    y: cursorY,
                    width: usableWidth,
                    height: headerHeight
                )
                headerAttributes[indexPath] = attributes
                maxElementHeight = max(maxElementHeight, headerHeight)
                cursorY += headerHeight
            }

            cursorY += sectionInset.top

            // Bottom edge of each column, seeded at the section's top edge.
            var columnBottoms = [CGFloat](repeating: cursorY, count: columnCount)
            let itemCount = collectionView.numberOfItems(inSection: section)

            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: section)
                let span = delegate?.mosaicLayout(self, spanForItemAt: indexPath) ?? .small
                let columns = min(max(span.columns, 1), columnCount)
                let rows = max(span.rows, 1)

                // Pick the run of `columns` adjacent columns whose lowest common
                // starting edge is highest up the page; ties go to the leftmost run.
                var bestColumn = 0
                var bestY = CGFloat.greatestFiniteMagnitude
                for start in 0...(columnCount - columns) {
                    let restingY = columnBottoms[start..<(start + columns)].max() ?? cursorY
                    if restingY < bestY - 0.5 {
                        bestY = restingY
                        bestColumn = start
                    }
                }

                let width = CGFloat(columns) * columnWidth + CGFloat(columns - 1) * interItemSpacing
                let height = CGFloat(rows) * rowHeight + CGFloat(rows - 1) * lineSpacing
                let originX = sectionInset.left + CGFloat(bestColumn) * (columnWidth + interItemSpacing)

                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(x: originX, y: bestY, width: width, height: height)
                itemAttributes[indexPath] = attributes
                maxElementHeight = max(maxElementHeight, height)

                for column in bestColumn..<(bestColumn + columns) {
                    columnBottoms[column] = bestY + height + lineSpacing
                }
            }

            if itemCount > 0 {
                // Drop the trailing line spacing added by the last row.
                cursorY = (columnBottoms.max() ?? cursorY) - lineSpacing
            }
            cursorY += sectionInset.bottom
        }

        contentHeight = cursorY
        orderedAttributes = (Array(headerAttributes.values) + Array(itemAttributes.values))
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !orderedAttributes.isEmpty else { return nil }

        // Anything intersecting `rect` must start no higher than
        // `rect.minY - maxElementHeight`, so that is a safe place to begin.
        var index = firstIndex(withMinYAtLeast: rect.minY - maxElementHeight)
        var visible: [UICollectionViewLayoutAttributes] = []

        while index < orderedAttributes.count {
            let attributes = orderedAttributes[index]
            if attributes.frame.minY > rect.maxY { break }
            if attributes.frame.intersects(rect) { visible.append(attributes) }
            index += 1
        }
        return visible
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        itemAttributes[indexPath]
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == UICollectionView.elementKindSectionHeader else { return nil }
        return headerAttributes[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // Only a width change re-flows the grid; plain scrolling does not.
        abs(newBounds.width - preparedBoundsWidth) > .ulpOfOne
    }

    // MARK: - Helpers

    /// Index of the first cached attribute whose `frame.minY` is `>= value`.
    private func firstIndex(withMinYAtLeast value: CGFloat) -> Int {
        var low = 0
        var high = orderedAttributes.count
        while low < high {
            let mid = (low + high) / 2
            if orderedAttributes[mid].frame.minY < value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
