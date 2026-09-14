//
//  MosaicViewController.swift
//  ComplexLayout
//
//  Tab 1 — a UICollectionView driven by MosaicLayout, showing tiles of
//  1×1, 2×1, 1×2 and 2×2 footprints across several sections.
//

import UIKit

final class MosaicViewController: UIViewController {

    // Diffable data source keyed by identifier rather than by value: tile
    // contents can then change (see `shuffleSpans`) without the snapshot
    // holding on to a stale copy of the model.
    private typealias DataSource = UICollectionViewDiffableDataSource<String, UUID>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<String, UUID>

    private var sections: [MosaicSection]
    private var tilesByID: [UUID: MosaicTile] = [:]

    /// Explicit scroll insets, for when this controller is embedded.
    ///
    /// Tab 1 leaves this `nil` and lets the collection view derive its insets
    /// from the safe area. Tab 3 hosts the controller in a view that spans the
    /// whole screen, where the safe area is not a dependable source, and passes
    /// the insets in directly instead.
    var contentInsetOverride: UIEdgeInsets? {
        didSet {
            guard isViewLoaded, contentInsetOverride != oldValue else { return }
            applyContentInsets()
        }
    }

    private let mosaicLayout = MosaicLayout()
    private var collectionView: UICollectionView!
    private var dataSource: DataSource!

    // MARK: - Init

    /// - Parameter sections: the tiles to lay out. Defaults to the full sample
    ///   set, which is what tab 1 shows; tab 3 seeds each of its pages with a
    ///   single section instead.
    init(sections: [MosaicSection] = MosaicSection.sampleSections()) {
        self.sections = sections
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Mosaic"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "shuffle"),
            style: .plain,
            target: self,
            action: #selector(shuffleSpans)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Shuffle tile sizes"

        indexTiles()
        setUpCollectionView()
        setUpDataSource()
        applySnapshot(animated: false)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateColumnCount()
    }

    // MARK: - Setup

    private func indexTiles() {
        tilesByID = Dictionary(
            uniqueKeysWithValues: sections.flatMap(\.tiles).map { ($0.id, $0) }
        )
    }

    private func setUpCollectionView() {
        mosaicLayout.delegate = self

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: mosaicLayout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        applyContentInsets()
    }

    private func applyContentInsets() {
        guard let insets = contentInsetOverride else {
            // Tab 1: the safe area is the source of truth.
            collectionView.contentInsetAdjustmentBehavior = .automatic
            collectionView.contentInset = .zero
            collectionView.verticalScrollIndicatorInsets = .zero
            return
        }
        // Embedded: take the insets verbatim, so nothing is counted twice.
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = insets
        collectionView.verticalScrollIndicatorInsets = insets
    }

    private func setUpDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<MosaicCell, UUID> {
            [weak self] cell, _, identifier in
            guard let tile = self?.tilesByID[identifier] else { return }
            cell.configure(with: tile)
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<MosaicSectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.sections[safe: indexPath.section] else { return }
            header.configure(with: section)
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, identifier in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: identifier
            )
        }

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = Snapshot()
        snapshot.appendSections(sections.map(\.id))
        for section in sections {
            snapshot.appendItems(section.tiles.map(\.id), toSection: section.id)
        }
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    /// Wider layouts get more columns, so tiles do not become oversized on iPad.
    private func updateColumnCount() {
        let width = view.bounds.width
        let columns: Int
        switch width {
        case ..<500: columns = 4
        case ..<820: columns = 6
        default: columns = 8
        }
        mosaicLayout.columnCount = columns
    }

    // MARK: - Actions

    /// Reassigns a random footprint to every tile to show the layout re-packing.
    @objc private func shuffleSpans() {
        for (identifier, var tile) in tilesByID {
            tile.span = TileSpan.all.randomElement() ?? .small
            tilesByID[identifier] = tile
        }
        for sectionIndex in sections.indices {
            for tileIndex in sections[sectionIndex].tiles.indices {
                let identifier = sections[sectionIndex].tiles[tileIndex].id
                if let tile = tilesByID[identifier] {
                    sections[sectionIndex].tiles[tileIndex] = tile
                }
            }
        }

        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.2
        ) {
            self.mosaicLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
        }
    }
}

// MARK: - MosaicLayoutDelegate

extension MosaicViewController: MosaicLayoutDelegate {

    func mosaicLayout(_ layout: MosaicLayout, spanForItemAt indexPath: IndexPath) -> TileSpan {
        guard
            let identifier = dataSource.itemIdentifier(for: indexPath),
            let tile = tilesByID[identifier]
        else { return .small }
        return tile.span
    }

    func mosaicLayout(_ layout: MosaicLayout, hasHeaderInSection section: Int) -> Bool {
        true
    }
}

// MARK: - UICollectionViewDelegate

extension MosaicViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Utilities

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
