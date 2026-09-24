//
//  TabBarMinimizeSensor.swift
//  ComplexLayout
//
//  Reports whether the tab bar has minimized.
//

import UIKit

/// Tells its owner when the tab bar minimizes and expands.
///
/// There is no public API that states this directly: `UITabBarController` has
/// `tabBarMinimizeBehavior` going in but nothing coming back, no delegate
/// callback, and neither `tabBar.frame` nor `contentLayoutGuide` moves when
/// the bar collapses — both were measured and both stay put, because the bar
/// swaps between two internal platter views inside an unchanged frame.
///
/// The one public signal is `UITraitTabAccessoryEnvironment`, which the system
/// keeps up to date on views inside `UITabBarController.bottomAccessory`:
/// `.inline` once the bar has collapsed, `.regular` while it has not. So the
/// accessory is used here as a sensor and nothing else. It has zero height and
/// no content, which leaves the system drawing no accessory surface at all —
/// verified by screenshot — while still placing it in the tab bar's layout and
/// updating its trait in step with the bar's own animation.
///
/// That last part is why this is worth the indirection: the report arrives at
/// the same moment the bar moves, so anything positioned against the bar can
/// animate alongside it rather than chasing it from a scroll observer.
final class TabBarMinimizeSensor: UIView {

    /// Called with `true` when the tab bar minimizes, `false` when it expands.
    var onChange: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 0).isActive = true

        registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (view: Self, _) in
            view.report()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }

    private func report() {
        onChange?(traitCollection.tabAccessoryEnvironment == .inline)
    }
}
