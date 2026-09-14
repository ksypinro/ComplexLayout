//
//  CustomView_1stTry.swift
//  ComplexLayout
//
//  Specimen 2 of 3 — the attempted fix that did not work.
//

import SwiftUI

/// Paging with `TabView(.page)`, unchanged from `CustomView_Issue`.
///
/// **The pager here is deliberately identical to the Issue variant.** What this
/// specimen changes is on the UIKit side: `OverviewViewController` sets
/// `safeAreaRegions = []` for it (see `PagerVariant.zeroesHostingSafeArea`),
/// on the theory that giving SwiftUI no safe area would leave the paging view
/// nothing to subtract.
///
/// **It does not work, and the capture says why.** `safeAreaRegions` governs
/// SwiftUI's own layout system; the backing `PagingCollectionView` is a UIKit
/// collection view whose `safeAreaInsets` arrive through the UIView superview
/// chain. With the flag applied it still measured `T96 B20`, `contentSize`
/// still came back 3540×704, and the cell still sat at y = −58.
///
/// Kept as evidence that no SwiftUI-level modifier reaches that subtraction.
struct CustomView_1stTry: View {

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
