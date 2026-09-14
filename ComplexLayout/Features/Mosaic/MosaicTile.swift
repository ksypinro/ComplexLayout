//
//  MosaicTile.swift
//  ComplexLayout
//
//  Model types backing the mosaic collection view.
//

import UIKit

/// The footprint a tile occupies in the mosaic grid, measured in grid units.
///
/// `columns` is the horizontal span and `rows` the vertical one, so a
/// `TileSpan(columns: 1, rows: 2)` is a tall 1×2 tile.
struct TileSpan: Hashable {
    let columns: Int
    let rows: Int

    /// 1×1 — a single grid unit, used to fill gaps between the larger tiles.
    static let small = TileSpan(columns: 1, rows: 1)
    /// 1×2 — one column wide, two rows tall.
    static let tall = TileSpan(columns: 1, rows: 2)
    /// 2×1 — two columns wide, one row tall.
    static let wide = TileSpan(columns: 2, rows: 1)
    /// 2×2 — a square double tile.
    static let large = TileSpan(columns: 2, rows: 2)

    /// Every span the sample data draws from.
    static let all: [TileSpan] = [.small, .tall, .wide, .large]

    /// Human readable footprint, e.g. `"2×1"`.
    var label: String { "\(columns)×\(rows)" }

    /// Number of grid units covered — used to decide how much detail a tile shows.
    var unitCount: Int { columns * rows }
}

/// Colour ramp applied to a tile's gradient background.
enum TileTint: CaseIterable, Hashable {
    case indigo, teal, amber, rose, mint, violet, sky, coral

    var gradient: [UIColor] {
        switch self {
        case .indigo: [UIColor(hex: 0x6366F1), UIColor(hex: 0x3730A3)]
        case .teal: [UIColor(hex: 0x14B8A6), UIColor(hex: 0x0F5F5A)]
        case .amber: [UIColor(hex: 0xF59E0B), UIColor(hex: 0xB45309)]
        case .rose: [UIColor(hex: 0xF43F5E), UIColor(hex: 0x9F1239)]
        case .mint: [UIColor(hex: 0x34D399), UIColor(hex: 0x047857)]
        case .violet: [UIColor(hex: 0xA855F7), UIColor(hex: 0x6D28D9)]
        case .sky: [UIColor(hex: 0x38BDF8), UIColor(hex: 0x0369A1)]
        case .coral: [UIColor(hex: 0xFB923C), UIColor(hex: 0xC2410C)]
        }
    }
}

/// A single cell in the mosaic.
struct MosaicTile: Identifiable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var symbolName: String
    var span: TileSpan
    var tint: TileTint

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        symbolName: String,
        span: TileSpan,
        tint: TileTint
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.span = span
        self.tint = tint
    }
}

/// A titled group of tiles, rendered with a section header.
struct MosaicSection: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    var tiles: [MosaicTile]
}

// MARK: - Sample data

extension MosaicSection {

    static func sampleSections() -> [MosaicSection] {
        [
            MosaicSection(
                id: "featured",
                title: "Featured",
                subtitle: "Mixed 2×2, 2×1 and 1×2 tiles",
                tiles: [
                    MosaicTile(title: "Northern Lights", subtitle: "Aurora over Tromsø", symbolName: "sparkles", span: .large, tint: .indigo),
                    MosaicTile(title: "Tide Pools", subtitle: "Low tide, Big Sur", symbolName: "water.waves", span: .tall, tint: .teal),
                    MosaicTile(title: "Golden Hour", subtitle: "Twenty minutes of light", symbolName: "sun.horizon", span: .small, tint: .amber),
                    MosaicTile(title: "Street Level", subtitle: "Lisbon, on foot", symbolName: "camera.macro", span: .small, tint: .rose),
                    MosaicTile(title: "Long Exposure", subtitle: "Traffic trails at dusk", symbolName: "timelapse", span: .wide, tint: .violet),
                    MosaicTile(title: "Alpine", subtitle: "Above the treeline", symbolName: "mountain.2", span: .large, tint: .mint),
                    MosaicTile(title: "Fog Bank", subtitle: "Marine layer", symbolName: "cloud.fog", span: .tall, tint: .sky),
                    MosaicTile(title: "Ember", subtitle: "Campfire study", symbolName: "flame", span: .small, tint: .coral),
                    MosaicTile(title: "Dunes", subtitle: "Wind-carved ridges", symbolName: "sun.dust", span: .wide, tint: .amber)
                ]
            ),
            MosaicSection(
                id: "collections",
                title: "Collections",
                subtitle: "Curated sets, updated weekly",
                tiles: [
                    MosaicTile(title: "Architecture", subtitle: "142 photos", symbolName: "building.columns", span: .wide, tint: .sky),
                    MosaicTile(title: "Portraits", subtitle: "88 photos", symbolName: "person.crop.square", span: .tall, tint: .rose),
                    MosaicTile(title: "Macro", subtitle: "37 photos", symbolName: "leaf", span: .small, tint: .mint),
                    MosaicTile(title: "Night Sky", subtitle: "64 photos", symbolName: "moon.stars", span: .large, tint: .indigo),
                    MosaicTile(title: "Film Scans", subtitle: "210 photos", symbolName: "film", span: .small, tint: .amber),
                    MosaicTile(title: "Black & White", subtitle: "96 photos", symbolName: "circle.lefthalf.filled", span: .wide, tint: .violet),
                    MosaicTile(title: "Coastline", subtitle: "51 photos", symbolName: "sailboat", span: .tall, tint: .teal),
                    MosaicTile(title: "Motion", subtitle: "29 photos", symbolName: "figure.run", span: .small, tint: .coral)
                ]
            ),
            MosaicSection(
                id: "recent",
                title: "Recently Added",
                subtitle: "From the last seven days",
                tiles: [
                    MosaicTile(title: "Harbour", subtitle: "Tuesday", symbolName: "ferry", span: .tall, tint: .sky),
                    MosaicTile(title: "Market Day", subtitle: "Tuesday", symbolName: "basket", span: .small, tint: .amber),
                    MosaicTile(title: "Rooftops", subtitle: "Wednesday", symbolName: "house.lodge", span: .small, tint: .coral),
                    MosaicTile(title: "Rain Study", subtitle: "Thursday", symbolName: "cloud.rain", span: .wide, tint: .indigo),
                    MosaicTile(title: "Greenhouse", subtitle: "Friday", symbolName: "camera.aperture", span: .large, tint: .mint),
                    MosaicTile(title: "Late Train", subtitle: "Saturday", symbolName: "tram.fill", span: .tall, tint: .violet),
                    MosaicTile(title: "Low Sun", subtitle: "Sunday", symbolName: "sunset", span: .small, tint: .rose)
                ]
            )
        ]
    }
}
