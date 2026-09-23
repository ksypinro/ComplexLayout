//
//  SearchViewController.swift
//  ComplexLayout
//
//  Root of the search tab. Owns the `UISearchController`, offers the standard
//  suggestion list, and routes a chosen result back to the tab it came from.
//

import UIKit

/// The search tab's landing screen.
///
/// Three surfaces are layered here, which is the division of labour
/// `UISearchController` expects:
///
/// - **This controller's own view** is the idle state. A dedicated search tab
///   that opens to nothing is a dead end, so it lists the places a search can
///   reach before anything has been typed.
/// - **The suggestion list** is drawn by the system from `searchSuggestions`,
///   below the field. Picking one inserts a `UISearchToken` that scopes the
///   query to a single tab.
/// - **`SearchResultsViewController`** is the results controller, presented by
///   the search controller once the query is non-empty.
final class SearchViewController: UIViewController {

    private typealias DataSource = UICollectionViewDiffableDataSource<AppTab, SearchSource>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<AppTab, SearchSource>

    private let resultsController = SearchResultsViewController()
    private lazy var searchController = UISearchController(searchResultsController: resultsController)

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!

    // MARK: - Lifecycle

    /// Configures search here rather than in `viewDidLoad`.
    ///
    /// The tab's `viewControllerProvider` does not run until the search tab is
    /// first selected, and the tab bar begins its transition as soon as it has
    /// the controller back. Configuring in the initializer means the
    /// navigation item already names its search controller before the provider
    /// returns, rather than acquiring one partway through that transition.
    ///
    /// Worth knowing if you are chasing a layout problem here: this on its own
    /// did *not* fix the first-appearance flash that used to affect this tab.
    /// That had two other causes — see `preferredSearchBarPlacement` below and
    /// `prewarmTextInput()` in `MainTabBarController`.
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground
        configureSearchController()
        configureCollectionView()
        configureDataSource()
    }

    // MARK: - Search controller

    private func configureSearchController() {
        title = "Search"
        resultsController.delegate = self

        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Mosaic, Library and Overview"
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.delegate = self

        // The idle list below is a useful place to be while the field is
        // focused but empty, so don't dim it out from under the user.
        searchController.obscuresBackgroundDuringPresentation = false

        // Integrated, which on iPhone means the navigation controller hands
        // the field to the bar at the bottom of the screen — where search
        // lives in a search tab, and where this one ends up regardless.
        //
        // Asking for `.stacked` here instead is what caused the field to flash
        // over the content on the tab's first appearance. Stacked puts the
        // field in the navigation bar at the top, the search tab then moves it
        // down into the tab bar's glass, and until that relocation settles the
        // browse list underneath is laid out for the wrong bar and scrolls up
        // through the field. Naming the placement the system is going to use
        // leaves nothing to relocate, so the first laid-out frame is correct.
        navigationItem.searchController = searchController
        navigationItem.preferredSearchBarPlacement = .integrated
        navigationItem.hidesSearchBarWhenScrolling = false
        searchController.searchSuggestions = Self.scopeSuggestions

        navigationItem.largeTitleDisplayMode = .inline
    }

    /// One suggestion per tab, offered as a way to narrow the search.
    ///
    /// `representedObject` carries the raw value rather than the `AppTab`
    /// itself: the property is `Any?` and crosses into Objective-C, so a
    /// bridgeable `String` survives the round trip where a Swift enum would
    /// need boxing.
    private static let scopeSuggestions: [UISearchSuggestionItem] = AppTab.allCases.map { tab in
        let suggestion = UISearchSuggestionItem(
            localizedSuggestion: "Search in \(tab.title)",
            localizedDescription: tab.summary,
            iconImage: UIImage(systemName: tab.symbolName)
        )
        suggestion.representedObject = tab.rawValue
        return suggestion
    }

    /// The tab the query is currently narrowed to, or `nil` for all of them.
    ///
    /// Read back off the field rather than mirrored in a stored property, so
    /// deleting the token — which the text field lets people do directly —
    /// widens the search without needing to be observed.
    private var activeScope: AppTab? {
        guard let raw = searchController.searchBar.searchTextField.tokens
            .compactMap({ $0.representedObject as? String })
            .first
        else { return nil }
        return AppTab(rawValue: raw)
    }

    // MARK: - Idle list

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary

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
        // Counted once rather than per dequeue: the cell provider runs on every
        // scroll, and the index does not change while the app is running.
        let counts = SearchIndex.shared.entries.reduce(into: [SearchSource: Int]()) { counts, entry in
            counts[entry.source, default: 0] += 1
        }

        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, SearchSource> { cell, _, source in
            var content = cell.defaultContentConfiguration()
            content.text = source.container ?? source.tab.title
            let count = counts[source] ?? 0
            content.secondaryText = count == 1 ? "1 item" : "\(count) items"
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: source.tab.symbolName)
            content.imageProperties.tintColor = source.tab.tint
            content.imageProperties.reservedLayoutSize = CGSize(width: 28, height: 28)
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }

        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, indexPath in
            guard let tab = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            var content = UIListContentConfiguration.header()
            content.text = tab.title
            content.secondaryText = tab.summary
            view.contentConfiguration = content
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, source in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: source)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }

        // One section per tab, listing the pages and sections inside it — the
        // same provenance the results group by, shown up front so the shape of
        // what is searchable is visible before anyone types.
        var snapshot = Snapshot()
        for tab in AppTab.allCases {
            let sources = SearchIndex.grouped(SearchIndex.shared.entries(in: tab)).map(\.source)
            guard !sources.isEmpty else { continue }
            snapshot.appendSections([tab])
            snapshot.appendItems(sources, toSection: tab)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Routing

    /// Switches the tab bar to `tab` and dismisses search.
    ///
    /// Looked up by identifier rather than by index because the tab bar and
    /// sidebar let people reorder and hide tabs, which makes a position an
    /// unreliable way to name a destination.
    private func open(_ tab: AppTab) {
        searchController.isActive = false
        guard
            let tabBarController,
            let destination = tabBarController.tab(forIdentifier: tab.tabIdentifier)
        else { return }
        tabBarController.selectedTab = destination
    }
}

// MARK: - UISearchResultsUpdating

extension SearchViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        let scope = activeScope

        // A token on its own is a complete request — "everything in Library" —
        // so it lists the tab rather than waiting for text that may never come.
        let matches = if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let scope {
            SearchIndex.shared.entries(in: scope)
        } else {
            SearchIndex.shared.entries(matching: query, scope: scope)
        }
        resultsController.show(matches, for: query)

        // Offer the scope suggestions only while the search is unscoped and
        // still open-ended. Once a token is in the field, or a query is being
        // typed, the suggestion list is in the way of the results.
        let isNarrowing = scope != nil || !query.isEmpty
        searchController.searchSuggestions = isNarrowing ? nil : Self.scopeSuggestions

        // The results controller is revealed automatically only once the field
        // holds text, and a lone token leaves it empty. Ask for it by hand so
        // picking a suggestion lands on results rather than on the idle list.
        searchController.showsSearchResultsController = isNarrowing
    }

    /// Called when someone picks a row from the system suggestion list.
    func updateSearchResults(
        for searchController: UISearchController,
        selecting suggestion: any UISearchSuggestion
    ) {
        guard
            let raw = suggestion.representedObject as? String,
            let tab = AppTab(rawValue: raw)
        else { return }

        // A token rather than a scope bar: it reads inside the field as part
        // of the query, and stays deletable with the keyboard.
        let token = UISearchToken(
            icon: UIImage(systemName: tab.symbolName),
            text: tab.title
        )
        token.representedObject = tab.rawValue

        let field = searchController.searchBar.searchTextField
        field.tokens = [token]
        updateSearchResults(for: searchController)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {

    /// Restores the suggestion list when the field is cleared back to empty,
    /// so cancelling out of a search returns to the starting state.
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.searchTextField.tokens = []
        searchController.searchSuggestions = Self.scopeSuggestions
    }
}

// MARK: - SearchResultsViewControllerDelegate

extension SearchViewController: SearchResultsViewControllerDelegate {

    func searchResults(_ controller: SearchResultsViewController, didSelect entry: SearchEntry) {
        open(entry.source.tab)
    }
}

// MARK: - UICollectionViewDelegate

extension SearchViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let source = dataSource.itemIdentifier(for: indexPath) else { return }
        open(source.tab)
    }
}
