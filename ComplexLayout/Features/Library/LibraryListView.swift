//
//  LibraryListView.swift
//  ComplexLayout
//
//  Tab 2 — a sectioned SwiftUI List, hosted inside UIKit.
//

import SwiftUI

struct LibraryListView: View {

    @State private var sections: [LibrarySection] = LibrarySection.sample
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSections) { section in
                    Section {
                        ForEach(section.items) { item in
                            NavigationLink(value: item) {
                                LibraryRow(item: item)
                            }
                        }
                    } header: {
                        Text(section.title)
                    } footer: {
                        if let footer = section.footer {
                            Text(footer)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search library")
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
            .overlay {
                if filteredSections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    /// Sections filtered by the search field, dropping any that end up empty.
    private var filteredSections: [LibrarySection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sections }

        return sections.compactMap { section in
            let matches = section.items.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query)
            }
            guard !matches.isEmpty else { return nil }
            var filtered = section
            filtered.items = matches
            return filtered
        }
    }
}

// MARK: - Row

private struct LibraryRow: View {

    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.tint.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: item.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let badge = item.badge {
                Text("\(badge)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.tint))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

private struct LibraryDetailView: View {

    let item: LibraryItem

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item.tint.gradient)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: item.symbolName)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.title3.weight(.semibold))
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("About") {
                Text(item.detail)
                    .font(.callout)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LibraryListView()
}
