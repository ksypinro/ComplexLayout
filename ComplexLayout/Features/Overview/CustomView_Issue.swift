//
//  CustomView_Issue.swift
//  ComplexLayout
//
//  Specimen 1 of 3 — the original implementation. Reproduces the defect.
//

import SwiftUI

/// Paging with `TabView(.page)`.
///
/// **This variant is expected to fail.** After a portrait→landscape rotation,
/// SwiftUI's backing `PagingCollectionView` re-derives its content height as
/// (bounds − safeAreaInsets) — 820 − 96 − 20 = 704 on an 11-inch iPad Air —
/// while its page cell stays the full 820. The layout centres the cell in the
/// shorter content, so the cell lands at (704 − 820) / 2 = −58 and its bottom
/// edge stops at 762, leaving a 58 pt band of exposed background.
///
/// The insets reach the collection view through the UIView superview chain, so
/// `.ignoresSafeArea()` below does not prevent the subtraction — the paging
/// view was measured still reporting `T96 B20` with it applied.
struct CustomView_Issue: View {

    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages) { page in
                CustomPageView(page: page, contentInsets: contentInsets)
                    .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}
