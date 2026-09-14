//
//  OverviewModels.swift
//  ComplexLayout
//
//  Model types shared by the third tab's header and its pages.
//

import SwiftUI

/// One page of the tab, together with the figure the header shows for it.
///
/// The header cells and the paged content are driven by the same array, so a
/// cell and the page it highlights cannot drift apart.
struct OverviewPage: Identifiable, Hashable {
    /// Also the page's position, and the value bound to the `TabView`.
    let id: Int
    var value: String
    var label: String
    var symbolName: String
    var tint: Color
    /// Tiles this page hands to its embedded `MosaicViewController`.
    var sections: [MosaicSection]
}

// MARK: - Sample data

extension OverviewPage {

    /// One page per section of the tab 1 sample data. Each page shows the
    /// whole mosaic, rotated so its own section leads — distinct content per
    /// page, and enough of it that the pages actually scroll.
    static let sample: [OverviewPage] = {
        let mosaic = MosaicSection.sampleSections()
        let chrome: [(symbol: String, tint: Color)] = [
            ("sparkles", .orange),
            ("square.grid.2x2", .indigo),
            ("clock", .green)
        ]

        return zip(mosaic, chrome).enumerated().map { index, pair in
            let (section, style) = pair
            return OverviewPage(
                id: index,
                value: "\(section.tiles.count)",
                label: section.title,
                symbolName: style.symbol,
                tint: style.tint,
                sections: Array(mosaic[index...] + mosaic[..<index])
            )
        }
    }()
}
