//
//  CustomPageView.swift
//  ComplexLayout
//
//  One page of the paged content: the tab 1 collection view, embedded.
//

import SwiftUI

struct CustomPageView: View {

    let page: OverviewPage

    /// Absolute scroll insets for the embedded collection view. See `CustomView`.
    var contentInsets = EdgeInsets()

    var body: some View {
        MosaicControllerView(
            sections: page.sections,
            contentInsets: contentInsets
        )
        // Marking the TabView alone is not enough: the page still gets laid out
        // inside the safe area, which clips the collection view short of the
        // display edges and leaves a blank band top and bottom. This is what
        // makes the page itself span the full screen.
        .ignoresSafeArea()
    }
}

#Preview {
    CustomPageView(page: OverviewPage.sample[0])
}
