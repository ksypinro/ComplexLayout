//
//  CustomView_Fix1.swift
//  ComplexLayout
//
//  Specimen 3 of 3 — the working fix.
//

import SwiftUI

/// Paging with `ScrollView` + `.scrollTargetBehavior(.paging)`.
///
/// The defect in the other two variants comes from there being *two*
/// independently computed heights — the page cell's and the paging container's
/// content height — which agree on a fresh layout and disagree after a rotation
/// re-layout. Here each page's frame is set explicitly from the container's own
/// size, so there is no second derived height to drift.
///
/// Verified after rotation on an 11-inch iPad Air: page host and mosaic
/// collection view both at `screenFrame (0,0) 1180×820`, scroll content size
/// 3540×820 (full height, not 704), `contentInset` T216 B20, no white band at
/// either edge.
struct CustomView_Fix1: View {

    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets

    /// The scroll view's own notion of the visible page, kept in sync with
    /// `selection` in both directions below.
    @State private var scrolledPage: Int?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        CustomPageView(page: page, contentInsets: contentInsets)
                            // Explicit, from the container. This is the property
                            // the TabView could not hold on to across a rotation.
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolledPage)
            .onAppear { scrolledPage = selection }
            .onChange(of: scrolledPage) { _, page in
                guard let page, page != selection else { return }
                selection = page
            }
            .onChange(of: selection) { _, page in
                guard scrolledPage != page else { return }
                withAnimation(.snappy(duration: 0.3)) { scrolledPage = page }
            }
        }
        .ignoresSafeArea()
    }
}
