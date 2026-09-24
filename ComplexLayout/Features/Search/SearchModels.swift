//
//  SearchModels.swift
//  ComplexLayout
//
//  The index behind the search tab, and the vocabulary it uses to say where a
//  result came from.
//

import SwiftUI
import UIKit

// MARK: - Destinations

/// A top-level destination, named in one place so the tab bar, the search
/// index and the result rows cannot drift apart about what a tab is called.
nonisolated enum AppTab: String, CaseIterable {
    case mosaic
    case library
    case overview

    /// Identifier of the matching `UITab`.
    ///
    /// Search results store this rather than a tab index: people can reorder
    /// and hide tabs from the sidebar, so a position is not a stable way to
    /// name a destination, but `UITabBarController.tab(forIdentifier:)` is.
    var tabIdentifier: String { "com.complexlayout.tab.\(rawValue)" }

    var title: String {
        switch self {
        case .mosaic: "Mosaic"
        case .library: "Library"
        case .overview: "Overview"
        }
    }

    /// The outline variant on purpose.
    ///
    /// Under Liquid Glass the system picks the filled variant itself when a
    /// tab is selected, so handing it a `.fill` symbol takes that away and
    /// leaves the tab looking selected whether it is or not.
    var symbolName: String {
        switch self {
        case .mosaic: "square.grid.3x3"
        case .library: "list.bullet.rectangle"
        case .overview: "square.stack.3d.up"
        }
    }

    /// Short line describing the tab, shown when search offers it as a
    /// destination to browse rather than as a match.
    var summary: String {
        switch self {
        case .mosaic: "Tiles laid out by a custom collection view layout"
        case .library: "Sectioned SwiftUI list of playlists and settings"
        case .overview: "Paged header and content, one page per mosaic section"
        }
    }

    var tint: UIColor {
        switch self {
        case .mosaic: .systemIndigo
        case .library: .systemPink
        case .overview: .systemOrange
        }
    }
}

// MARK: - Result provenance

/// Where a result lives: the tab that owns it, and the page or section inside
/// that tab.
///
/// Results are grouped by this value, so "which part of the app is this from"
/// is answered by the section header the row sits under instead of being left
/// for the reader to infer from the title.
nonisolated struct SearchSource: Hashable {

    let tab: AppTab

    /// The section or page inside the tab, e.g. `"Featured"`.
    ///
    /// `nil` when the result *is* the destination rather than something
    /// contained by it — the rows search offers for the tabs themselves.
    let container: String?

    /// Header text, e.g. `"Mosaic · Featured"`.
    var title: String {
        guard let container else { return tab.title }
        return "\(tab.title) · \(container)"
    }
}

// MARK: - Entries

/// One searchable thing, flattened out of whichever model owns it.
nonisolated struct SearchEntry: Hashable, Identifiable {

    let id: UUID
    let title: String
    let subtitle: String
    /// The longer description, where the underlying model has one.
    let detail: String?
    let symbolName: String
    let tint: UIColor
    let source: SearchSource

    /// Lowercased title, kept beside the display title so matching does not
    /// re-lowercase the whole index on every keystroke.
    fileprivate let foldedTitle: String
    /// Everything else worth matching, lowercased and joined.
    fileprivate let foldedBody: String

    fileprivate init(
        title: String,
        subtitle: String,
        detail: String? = nil,
        symbolName: String,
        tint: UIColor,
        source: SearchSource
    ) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.symbolName = symbolName
        self.tint = tint
        self.source = source
        self.foldedTitle = title.folded
        self.foldedBody = [subtitle, detail ?? "", source.title].joined(separator: " ").folded
    }
}

nonisolated private extension String {
    /// Lowercased and diacritic-stripped, so "Tromsø" matches "tromso".
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

// MARK: - The index

/// A flat, in-memory index over the app's sample data.
///
/// Built once and shared. The data is static and small enough that ranking the
/// whole array per keystroke is cheaper than maintaining a prefix tree, and it
/// keeps the ranking rules in one readable place.
nonisolated struct SearchIndex {

    static let shared = SearchIndex()

    let entries: [SearchEntry]

    private init() {
        var entries: [SearchEntry] = []

        // The tabs themselves, so searching "library" offers the destination
        // and not only the things inside it.
        entries += AppTab.allCases.map { tab in
            SearchEntry(
                title: tab.title,
                subtitle: tab.summary,
                symbolName: tab.symbolName,
                tint: tab.tint,
                source: SearchSource(tab: tab, container: nil)
            )
        }

        // Tab 1 — every tile, grouped under the section that holds it.
        for section in MosaicSection.sampleSections() {
            let source = SearchSource(tab: .mosaic, container: section.title)
            entries += section.tiles.map { tile in
                SearchEntry(
                    title: tile.title,
                    subtitle: tile.subtitle,
                    detail: "\(tile.span.label) tile",
                    symbolName: tile.symbolName,
                    tint: tile.tint.gradient.first ?? .systemIndigo,
                    source: source
                )
            }
        }

        // Tab 2 — every list row, grouped under its list section.
        for section in LibrarySection.sample {
            let source = SearchSource(tab: .library, container: section.title)
            entries += section.items.map { item in
                SearchEntry(
                    title: item.title,
                    subtitle: item.subtitle,
                    detail: item.detail,
                    symbolName: item.symbolName,
                    tint: UIColor(item.tint),
                    source: source
                )
            }
        }

        // Tab 3 — the pages, not their tiles.
        //
        // Each overview page carries a rotated copy of the whole mosaic, so
        // indexing page contents would enter every tile three more times and
        // bury the genuine matches under duplicates. The page itself is the
        // thing that is actually distinct here.
        entries += OverviewPage.sample.map { page in
            SearchEntry(
                title: page.label,
                subtitle: "Page \(page.id + 1) · \(page.value) tiles",
                symbolName: page.symbolName,
                tint: UIColor(page.tint),
                source: SearchSource(tab: .overview, container: "Page \(page.id + 1)")
            )
        }

        self.entries = entries
    }

    // MARK: Querying

    /// Entries matching `query`, best first, optionally limited to one tab.
    ///
    /// - Parameters:
    ///   - query: free text. Whitespace-only queries return nothing rather
    ///     than everything, so an empty field shows the browse state instead
    ///     of a wall of results.
    ///   - scope: when non-nil, only entries from this tab are considered.
    ///     This is what a search token in the field narrows to.
    func entries(matching query: String, scope: AppTab? = nil) -> [SearchEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folded
        guard !needle.isEmpty else { return [] }

        let candidates = scope.map { tab in entries.filter { $0.source.tab == tab } } ?? entries

        return candidates
            .compactMap { entry -> (entry: SearchEntry, rank: Int)? in
                guard let rank = entry.rank(for: needle) else { return nil }
                return (entry, rank)
            }
            // Rank first, then title, so equally good matches come back in a
            // stable order rather than in index order.
            .sorted { ($0.rank, $0.entry.title) < ($1.rank, $1.entry.title) }
            .map(\.entry)
    }

    /// Everything from one tab, in index order — what the browse rows open.
    func entries(in tab: AppTab) -> [SearchEntry] {
        entries.filter { $0.source.tab == tab && $0.source.container != nil }
    }

    /// The entries grouped by source, preserving the order they arrive in.
    static func grouped(_ entries: [SearchEntry]) -> [(source: SearchSource, entries: [SearchEntry])] {
        var order: [SearchSource] = []
        var buckets: [SearchSource: [SearchEntry]] = [:]
        for entry in entries {
            if buckets[entry.source] == nil { order.append(entry.source) }
            buckets[entry.source, default: []].append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

nonisolated private extension SearchEntry {

    /// How well this entry matches, lower being better, or `nil` for no match.
    ///
    /// The user searches by name, so the title is ranked ahead of everything
    /// else: an exact title beats a title prefix, which beats a match on a
    /// later word of the title, which beats a match anywhere in the body.
    func rank(for needle: String) -> Int? {
        if foldedTitle == needle { return 0 }
        if foldedTitle.hasPrefix(needle) { return 1 }
        if foldedTitle.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 2 }
        if foldedTitle.contains(needle) { return 3 }
        if foldedBody.contains(needle) { return 4 }
        return nil
    }
}
