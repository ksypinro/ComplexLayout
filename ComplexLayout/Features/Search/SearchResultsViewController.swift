//
//  SearchResultsViewController.swift
//  ComplexLayout
//
//  The results controller handed to `UISearchController`. Shows matches
//  grouped by the tab and page they came from.
//

import UIKit

@MainActor
protocol SearchResultsViewControllerDelegate: AnyObject {
    /// The user picked a result and wants to be taken to it.
    func searchResults(_ controller: SearchResultsViewController, didSelect entry: SearchEntry)
}

/// The view controller `UISearchController` presents over the search tab.
///
/// It draws one section per `SearchSource`, so a run of results reads as
/// "these three came from Mosaic · Featured, this one from Library · Settings"
/// rather than as one undifferentiated list.
final class SearchResultsViewController: UIViewController {

    private typealias DataSource = UICollectionViewDiffableDataSource<SearchSource, UUID>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<SearchSource, UUID>

    weak var delegate: SearchResultsViewControllerDelegate?

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!

    /// The entries currently on screen, by id, so selection can resolve a row
    /// back to its model without reaching into the snapshot.
    private var entriesByID: [UUID: SearchEntry] = [:]

    /// The query behind the current results, used only for the empty state's
    /// "No results for …" line.
    private var query: String = ""

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Opaque, and matching the idle list it covers.
        //
        // The search controller does not dim what is behind it here — the
        // browse list stays usable while the field is focused and empty — so
        // this view has to be the thing that hides it once results appear.
        // Without a background the empty state, which draws no surface of its
        // own, renders straight over the browse list.
        //
        // This is content, not a bar: the Liquid Glass advice against custom
        // backgrounds is about navigation surfaces, and the collection view
        // above stays clear so the material still reads through at the edges.
        view.backgroundColor = .systemGroupedBackground

        configureCollectionView()
        configureDataSource()
    }

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        // The rows are destinations rather than content, so nothing here is
        // swipe-deletable and the separators can sit under the text.
        configuration.headerTopPadding = 0

        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .onDrag
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, SearchEntry> { cell, _, entry in
            var content = cell.defaultContentConfiguration()
            content.text = entry.title
            content.secondaryText = entry.subtitle
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.numberOfLines = 1
            content.image = UIImage(systemName: entry.symbolName)
            content.imageProperties.tintColor = entry.tint
            // Pin the symbol box so titles line up down the list regardless of
            // how wide each individual glyph happens to be.
            content.imageProperties.reservedLayoutSize = CGSize(width: 28, height: 28)
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }

        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, indexPath in
            guard let source = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            var content = UIListContentConfiguration.header()
            // The header is what names the origin: tab first, then the page or
            // section inside it.
            content.text = source.title
            content.image = UIImage(systemName: source.tab.symbolName)
            content.imageProperties.tintColor = source.tab.tint
            content.imageProperties.maximumSize = CGSize(width: 16, height: 16)
            view.contentConfiguration = content
        }

        dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
            guard let entry = self?.entriesByID[id] else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: entry)
        }

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
    }

    // MARK: - Content

    /// Replaces the visible results.
    ///
    /// - Parameters:
    ///   - entries: the matches, already ranked. Grouping happens here so
    ///     callers only have to hand over an ordered list.
    ///   - query: the text that produced them, for the empty state.
    func show(_ entries: [SearchEntry], for query: String) {
        self.query = query
        entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

        var snapshot = Snapshot()
        for group in SearchIndex.grouped(entries) {
            snapshot.appendSections([group.source])
            snapshot.appendItems(group.entries.map(\.id), toSection: group.source)
        }
        dataSource.apply(snapshot, animatingDifferences: false)

        updateEmptyState(hasResults: !entries.isEmpty)
    }

    /// Shows the system's standard "no results" state, which carries the
    /// magnifying glass and the searched-for term, instead of an empty list.
    private func updateEmptyState(hasResults: Bool) {
        guard !hasResults, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            contentUnavailableConfiguration = nil
            return
        }
        var configuration = UIContentUnavailableConfiguration.search()
        configuration.text = "No Results"
        configuration.secondaryText = "No items in this app match “\(query)”."
        contentUnavailableConfiguration = configuration
    }
}

// MARK: - UICollectionViewDelegate

extension SearchResultsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let entry = entriesByID[id]
        else { return }
        delegate?.searchResults(self, didSelect: entry)
    }
}
