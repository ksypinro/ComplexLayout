//
//  PagerVariant.swift
//  ComplexLayout
//
//  Selects which paging implementation tab 3 uses, so the three can be
//  compared against the same app, data and device.
//

import Foundation

/// The paging implementations kept side by side in this project.
///
/// Each is a specimen from the investigation into the 58 pt band that appeared
/// at the bottom of the display after a portrait→landscape rotation on iPad.
enum PagerVariant: String, CaseIterable, Identifiable, Sendable {

    /// The original: `TabView(.page)`. Reproduces the defect.
    case issue

    /// `TabView(.page)` with `UIHostingController.safeAreaRegions = []`.
    /// Measured to change nothing — kept as evidence, not as a candidate.
    case firstTry

    /// `ScrollView` + `LazyHStack` + `.scrollTargetBehavior(.paging)`. Fixes it,
    /// but replaces the pager.
    case fix1

    /// `TabView(.page)` kept, with a container view controller that tries to
    /// stop the safe area reaching SwiftUI's paging view. Does not work — see
    /// `OverviewSafeAreaCancellingContainer` for what was measured.
    case fix2

    /// Preserves TabView(.page); additional experiments live in CustomView_Fix3.
    case fix3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .issue: "Issue"
        case .firstTry: "1st Try"
        case .fix1: "Fix 1"
        case .fix2: "Fix 2"
        case .fix3: "Fix 3"
        }
    }

    var summary: String {
        switch self {
        case .issue: "TabView(.page) — shows the 58 pt band after rotation"
        case .firstTry: "TabView(.page) + safeAreaRegions = [] — no effect"
        case .fix1: "ScrollView paging — no band, but replaces the pager"
        case .fix2: "TabView kept; container tries to cancel the safe area — still bands"
        case .fix3: "TabView kept; refresh its layout when the container size changes"
        }
    }

    /// 1st Try's mechanism: `UIHostingController.safeAreaRegions = []`.
    /// Measured to have no effect on the paging view.
    var suppressesSafeAreaRegions: Bool { self == .firstTry }

    /// Fix 2's mechanism: wrap the hosting controller in a container that tries
    /// to stop the inherited safe area reaching it.
    ///
    /// Measured not to work. UIKit computes the safe area *per view
    /// controller*, so neither a parent view nor a parent controller can
    /// withhold it from a child hosting controller.
    var usesSafeAreaCancellingContainer: Bool { self == .fix2 }

    /// Whether SwiftUI is left without a safe area of its own, so overlays have
    /// to supply their own clearance instead of being placed inside one.
    var overlaysSupplyOwnClearance: Bool {
        suppressesSafeAreaRegions || usesSafeAreaCancellingContainer
    }

    // MARK: - Selection

    private static let defaultsKey = "PagerVariant.current"

    /// Posted after `current` changes, so the tab can be rebuilt around it.
    static let didChangeNotification = Notification.Name("PagerVariantDidChange")

    /// Persisted so a relaunch keeps whichever variant is being tested.
    static var current: PagerVariant {
        get {
            #if DEBUG
            if PagerExperiment.current != nil { return .fix3 }
            #endif
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
            return PagerVariant(rawValue: raw) ?? .fix1
        }
        set {
            guard newValue != current else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
