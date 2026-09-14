//
//  OverviewSafeAreaCancellingContainer.swift
//  ComplexLayout
//
//  Fix 2's mechanism: stop the safe area before SwiftUI's paging view sees it.
//

import UIKit

/// A view that reports no safe area to anything below it.
///
/// `safeAreaInsets` is overridden rather than adjusted because
/// `additionalSafeAreaInsets` cannot do this job: UIKit only *adds* with that
/// property. Setting it to the negative of the inherited area was measured to
/// change nothing — the hosting view still reported `T96 B20`, identical to its
/// parent, and the paging cell stayed at y = −58.
///
/// `trueSafeAreaInsets` keeps the real values reachable, since the container
/// still has to publish them to SwiftUI for the header and content insets.
final class SafeAreaZeroingView: UIView {

    /// What UIKit actually computed, before this class hides it.
    var trueSafeAreaInsets: UIEdgeInsets { super.safeAreaInsets }

    override var safeAreaInsets: UIEdgeInsets { .zero }
}

/// Hosts `OverviewViewController` behind a view that reports no safe area.
///
/// SwiftUI's paged `TabView` is backed by a UIKit collection view that derives
/// its content height as (bounds − safeAreaInsets) when it re-lays out after a
/// rotation, while its page cell stays the full bounds height. The mismatch is
/// resolved by centring, which displaces every page by half the difference —
/// 58 pt on an 11-inch iPad Air in landscape.
///
/// **This container does not fix the defect.** It is kept as the record of
/// three public-API mechanisms that were each measured failing to withhold the
/// safe area from the paging view:
///
/// | Mechanism | Result |
/// | --- | --- |
/// | `UIHostingController.safeAreaRegions = []` | SwiftUI-level only; paging view still `T96 B20` |
/// | negative `additionalSafeAreaInsets` | UIKit only *adds*; hosting view identical to its parent |
/// | overriding `safeAreaInsets` on this view | this view reports `T0 B0`; its child still gets `T96 B20` |
///
/// The last one is the conclusive measurement. UIKit computes the safe area
/// **per view controller** — note the child hosting controller receives `T96`
/// while this container's own wrapper has `T32`, because the tab bar's 64 pt is
/// applied to each controller directly rather than inherited through the view
/// tree. So no parent view or parent controller can withhold it, and
/// `additionalSafeAreaInsets`, the only supported lever, cannot subtract.
final class OverviewSafeAreaCancellingContainer: UIViewController {

    private let hosting: OverviewViewController

    init(variant: PagerVariant) {
        self.hosting = OverviewViewController(variant: variant)
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SafeAreaZeroingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)

        publishSafeArea()
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

    /// Hands SwiftUI the real insets, which it can no longer see for itself.
    private func publishSafeArea() {
        let real = (view as? SafeAreaZeroingView)?.trueSafeAreaInsets ?? view.safeAreaInsets
        hosting.apply(safeArea: real)
    }
}
