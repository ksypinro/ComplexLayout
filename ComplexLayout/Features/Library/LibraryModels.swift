//
//  LibraryModels.swift
//  ComplexLayout
//
//  Model types backing the SwiftUI list in tab 2.
//

import SwiftUI

struct LibraryItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String
    var symbolName: String
    var tint: Color
    var badge: Int?
    var detail: String
}

struct LibrarySection: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var footer: String?
    var items: [LibraryItem]
}

// MARK: - Sample data

extension LibrarySection {

    static let sample: [LibrarySection] = [
        LibrarySection(
            title: "Recently Played",
            footer: "Synced across your devices.",
            items: [
                LibraryItem(
                    title: "Morning Set",
                    subtitle: "24 tracks · 1 hr 38 min",
                    symbolName: "sunrise",
                    tint: .orange,
                    badge: 3,
                    detail: "A slow-building playlist that starts ambient and lands somewhere close to upbeat by the last third."
                ),
                LibraryItem(
                    title: "Deep Focus",
                    subtitle: "61 tracks · 4 hr 02 min",
                    symbolName: "waveform",
                    tint: .indigo,
                    detail: "Instrumental only. No vocals, no sudden dynamics, nothing that pulls attention away from the work."
                ),
                LibraryItem(
                    title: "Field Recordings",
                    subtitle: "12 tracks · 47 min",
                    symbolName: "mic",
                    tint: .teal,
                    detail: "Rain on canvas, harbour ropes, a train platform at midnight. Collected over two years."
                )
            ]
        ),
        LibrarySection(
            title: "Collections",
            footer: nil,
            items: [
                LibraryItem(
                    title: "Albums",
                    subtitle: "182 albums",
                    symbolName: "square.stack",
                    tint: .pink,
                    badge: 12,
                    detail: "Everything saved to the library, newest first."
                ),
                LibraryItem(
                    title: "Artists",
                    subtitle: "94 artists",
                    symbolName: "person.2",
                    tint: .purple,
                    detail: "Grouped alphabetically, with featured appearances folded in."
                ),
                LibraryItem(
                    title: "Downloaded",
                    subtitle: "3.4 GB available offline",
                    symbolName: "arrow.down.circle",
                    tint: .green,
                    detail: "Available without a network connection. Managed automatically when storage runs low."
                ),
                LibraryItem(
                    title: "Shared With You",
                    subtitle: "7 new this week",
                    symbolName: "person.crop.circle.badge.plus",
                    tint: .blue,
                    badge: 7,
                    detail: "Links people sent you in Messages, gathered in one place."
                )
            ]
        ),
        LibrarySection(
            title: "Settings",
            footer: "Changes apply the next time the app launches.",
            items: [
                LibraryItem(
                    title: "Playback",
                    subtitle: "Crossfade, gapless, EQ",
                    symbolName: "slider.horizontal.3",
                    tint: .gray,
                    detail: "Crossfade is set to 4 seconds. Gapless playback is on for albums that declare it."
                ),
                LibraryItem(
                    title: "Storage",
                    subtitle: "12.8 GB of 64 GB used",
                    symbolName: "internaldrive",
                    tint: .brown,
                    detail: "Downloads take up 3.4 GB. Cached artwork accounts for another 480 MB."
                ),
                LibraryItem(
                    title: "Notifications",
                    subtitle: "New releases only",
                    symbolName: "bell.badge",
                    tint: .red,
                    detail: "You are notified when an artist you follow releases something new. Everything else is muted."
                )
            ]
        )
    ]
}
