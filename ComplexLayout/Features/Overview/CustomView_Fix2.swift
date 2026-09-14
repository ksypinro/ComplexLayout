//
//  CustomView_Fix2.swift
//  ComplexLayout
//
//  Specimen 4 of 4 — keeps TabView(.page) and fixes the cause instead.
//

import SwiftUI

/// Paging with `TabView(.page)`, unchanged from `CustomView_Issue`.
///
/// **The pager here is deliberately identical to the Issue variant**, because
/// the pager was never the thing that needed changing. The defect comes from
/// `PagingCollectionView` re-deriving its content height as
/// (bounds − safeAreaInsets) on a rotation re-layout, and those insets arrive
/// through the **UIView superview chain**.
///
/// So this variant tried to remove the subtrahend rather than the pager, via
/// `OverviewSafeAreaCancellingContainer`.
///
/// **It does not work.** Three separate mechanisms were measured failing to
/// stop those insets reaching the paging view — see that file for the numbers.
/// The paging view still reported `T96 B20`, `contentSize` still came back
/// 3540×704, and the cell still sat at y = −58.
///
/// Kept as evidence that `TabView(.page)` cannot satisfy both "content reaches
/// the physical edges" and "survives rotation" through public API. `Fix 1`
/// replaces the pager instead, and does.
struct CustomView_Fix2: View {

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
