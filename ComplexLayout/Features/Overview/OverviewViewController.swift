//
//  OverviewViewController.swift
//  ComplexLayout
//
//  Hosts the third tab's SwiftUI view inside UIKit.
//

import SwiftUI
import UIKit

final class OverviewViewController: UIHostingController<OverviewView> {

    private let safeArea: OverviewSafeArea
    /// The variant this controller was constructed with.
    private(set) var builtVariant: PagerVariant = .fix1

    init(variant: PagerVariant = .current) {
        let safeArea = OverviewSafeArea()
        self.safeArea = safeArea
        super.init(rootView: OverviewView(safeArea: safeArea, variant: variant))

        self.builtVariant = variant

        // The distinguishing change of `PagerVariant.firstTry`. Measured to
        // have no effect on the defect — see `CustomView_1stTry`.
        if variant.suppressesSafeAreaRegions {
            safeAreaRegions = []
        }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        let safeArea = OverviewSafeArea()
        self.safeArea = safeArea
        super.init(coder: aDecoder, rootView: OverviewView(safeArea: safeArea, variant: .current))
    }

    /// Injects the real safe area from outside.
    ///
    /// Used by `OverviewSafeAreaCancellingContainer`, which has cancelled this
    /// controller's own insets and so is the only place left that still knows
    /// what they were.
    func apply(safeArea insets: UIEdgeInsets) {
        publish(insets)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        publishSafeArea()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // A rotation can settle the insets without a separate
        // `viewSafeAreaInsetsDidChange`, so re-read them here too.
        publishSafeArea()
    }

    /// Mirrors the controller's own UIKit safe area into the SwiftUI layout.
    ///
    /// Skipped under Fix 2: its container has deliberately zeroed these insets,
    /// so reading them here would publish zero. The container supplies the real
    /// values through `apply(safeArea:)` instead.
    private func publishSafeArea() {
        guard !builtVariant.usesSafeAreaCancellingContainer else { return }
        publish(resolvedSafeAreaInsets())
    }

    private func publish(_ resolved: UIEdgeInsets) {
        let insets = EdgeInsets(
            top: resolved.top,
            leading: resolved.left,
            bottom: resolved.bottom,
            trailing: resolved.right
        )
        if safeArea.insets != insets {
            safeArea.insets = insets
        }
    }

    /// `safeAreaRegions = []` stops the insets reaching SwiftUI; it should not
    /// stop them reaching this view. If it ever does, fall back to the nearest
    /// ancestor that still reports them rather than laying out against zero.
    private func resolvedSafeAreaInsets() -> UIEdgeInsets {
        let own = view.safeAreaInsets
        if own != .zero { return own }
        if let parentInsets = parent?.view.safeAreaInsets, parentInsets != .zero {
            return parentInsets
        }
        return view.window?.safeAreaInsets ?? .zero
    }
}
