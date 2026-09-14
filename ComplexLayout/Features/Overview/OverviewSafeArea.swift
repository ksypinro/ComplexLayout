//
//  OverviewSafeArea.swift
//  ComplexLayout
//
//  Carries the UIKit safe area across into SwiftUI.
//

import SwiftUI

/// The safe area the tab lays out against, published from the hosting
/// controller.
///
/// Every variant reads its insets from here rather than from a `GeometryReader`,
/// so the only thing that differs between them is the pager itself. It is also
/// required for `PagerVariant.firstTry`, where `safeAreaRegions = []` leaves
/// SwiftUI with no safe area of its own to measure.
@Observable
final class OverviewSafeArea {
    var insets = EdgeInsets()
}
