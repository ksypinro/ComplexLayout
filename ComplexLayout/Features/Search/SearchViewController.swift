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

    /// Called when a result is chosen, with the tab it came from.
    ///
    /// A closure rather than a walk up to `tabBarController`: search is
    /// presented as a sheet now, so the tab bar is its *presenting* controller
    /// rather than an ancestor. Handing the destination back to whoever put
    /// this on screen keeps that decision out of here.
    var onSelectTab: ((AppTab) -> Void)?

    /// Called when the user is done searching and the sheet should close.
    var onFinish: (() -> Void)?

    private let resultsController = SearchResultsViewController()
    private lazy var searchController = UISearchController(searchResultsController: resultsController)

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!

    // MARK: - Lifecycle

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

    private var hasActivatedSearch = false

    /// Focuses the field once, after the sheet has finished arriving.
    ///
    /// Deliberately not earlier: the presentation grows this sheet out of the
    /// accessory pill, and taking first responder while that is still running
    /// makes the keyboard race the transition. `viewDidAppear` is the first
    /// moment both are finished. The search tab used to get this for free from
    /// `automaticallyActivatesSearch`, which went with the tab.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasActivatedSearch else { return }
        hasActivatedSearch = true
        searchController.isActive = true

        // Deferred a turn on purpose. `isActive` starts the search
        // controller's own presentation, and until that settles the search bar
        // is not yet placed in the navigation bar — a first responder request
        // made now is simply dropped, which showed up as a field that looked
        // focused, cancel button and all, but swallowed every keystroke.
        DispatchQueue.main.async { [weak self] in
            self?.searchController.searchBar.becomeFirstResponder()
        }
    }

    // MARK: - Search controller

    private func configureSearchController() {
        title = "Search"
        resultsController.delegate = self

        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.searchBar.placeholder = "Mosaic, Library and Overview"
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.delegate = self

        // The idle list below is a useful place to be while the field is
        // focused but empty, so don't dim it out from under the user.
        searchController.obscuresBackgroundDuringPresentation = false

        // Stacked: the field sits below the title, full width, as the thing
        // this sheet exists for.
        //
        // This asked for `.integrated` while search was a tab, because the tab
        // bar took the field over and floated it in its own glass at the
        // bottom — and naming a placement the system was going to override
        // cost a visible relocation on first appearance. Off the tab bar there
        // is nothing to override it, so stacked is both what is asked for and
        // what gets rendered.
        navigationItem.searchController = searchController
        navigationItem.preferredSearchBarPlacement = .stacked
        navigationItem.hidesSearchBarWhenScrolling = false

        // Stacked placement suppresses the suggestion list by default, and the
        // scope suggestions are the whole of the empty state here.
        searchController.ignoresSearchSuggestionsForSearchBarPlacementStacked = false
        searchController.searchSuggestions = Self.scopeSuggestions

        navigationItem.largeTitleDisplayMode = .inline
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.onFinish?() }
        )
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

    /// Hands the chosen destination back to whoever presented search.
    private func open(_ tab: AppTab) {
        // Resign first so the keyboard is already on its way out when the
        // dismissal starts, rather than collapsing partway through it.
        searchController.searchBar.resignFirstResponder()
        onSelectTab?(tab)
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

// MARK: - UISearchControllerDelegate

extension SearchViewController: UISearchControllerDelegate {

    /// Focuses the field once the search controller has finished presenting.
    ///
    /// Asking for first responder alongside `isActive = true` is too early —
    /// the search controller is still presenting, the field is not in the
    /// window yet, and the request is dropped: the cancel button appears but
    /// typing goes nowhere. This is the callback that says the field is real.
    func didPresentSearchController(_ searchController: UISearchController) {
        searchController.searchBar.becomeFirstResponder()

        // Activating in code does not drive a results update the way typing
        // does, so the first thing shown would otherwise be an empty panel
        // instead of the scope suggestions. Ask for the update explicitly.
        updateSearchResults(for: searchController)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {

    /// Cancel closes search rather than emptying it.
    ///
    /// The sheet opens straight into an active field, so a cancel that only
    /// deactivated the search would strand the user on an idle screen they
    /// never asked for, with the way out — the navigation bar's Done button —
    /// hidden underneath the search bar that is still presented. Treating
    /// cancel as "I am finished" matches what the control looks like it does.
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.searchTextField.tokens = []
        searchController.searchSuggestions = Self.scopeSuggestions
        onFinish?()
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
