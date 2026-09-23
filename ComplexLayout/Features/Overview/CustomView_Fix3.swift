import SwiftUI

/// Structure-preserving investigation: UIKit root → SwiftUI TabView(.page)
/// → UIViewControllerRepresentable → MosaicViewController.
/// Existing Issue / 1st Try / Fix 1 / Fix 2 implementations are unchanged.
struct CustomView_Fix3: View {
    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets

    var body: some View {
        #if DEBUG
        if let experiment = PagerExperiment.current {
            ExperimentPager(experiment: experiment, pages: pages, selection: $selection, contentInsets: contentInsets)
        } else {
            pager
        }
        #else
        pager
        #endif
    }

    private var pager: some View {
        GeometryReader { proxy in
            TabView(selection: $selection) {
                ForEach(pages) { page in
                    CustomPageView(page: page, contentInsets: contentInsets)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .id(proxy.size)
        }
        .ignoresSafeArea()
    }
}
