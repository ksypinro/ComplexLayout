//
//  CustomView.swift
//  ComplexLayout
//
//  The scrolling content beneath the header — dispatches to one of the three
//  paging specimens.
//

import SwiftUI

/// The third tab's content: three horizontally paged `CustomPageView`s.
///
/// The pager itself is whichever `PagerVariant` is currently selected, so the
/// implementations can be compared against the same app, data and device. See
/// `CustomView_Issue`, `CustomView_1stTry` and `CustomView_Fix1`.
///
/// `selection` is shared with `OverviewHeaderView`, so paging — by swipe or by
/// tapping a header cell — keeps the highlighted header cell and the visible
/// page in step.
struct CustomView: View {

    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets
    let variant: PagerVariant

    var body: some View {
        switch variant {
        case .issue:
            CustomView_Issue(pages: pages, selection: $selection, contentInsets: contentInsets)
        case .firstTry:
            CustomView_1stTry(pages: pages, selection: $selection, contentInsets: contentInsets)
        case .fix1:
            CustomView_Fix1(pages: pages, selection: $selection, contentInsets: contentInsets)
        case .fix3:
            CustomView_Fix3(pages: pages, selection: $selection, contentInsets: contentInsets)
        case .fix2:
            CustomView_Fix2(pages: pages, selection: $selection, contentInsets: contentInsets)
        }
    }
}
