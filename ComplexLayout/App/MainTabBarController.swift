//
//  MainTabBarController.swift
//  ComplexLayout
//
//  Root of the app. Declares the top-level tabs, and the search tab that
//  reaches across all of them.
//

import UIKit

/// The app's root container.
///
/// Built with the declarative `UITab` API rather than `viewControllers`. Two
/// things follow from that and neither is available to the older array:
///
/// - Each tab's view controller is built by a closure the system calls the
///   first time the tab is shown, so tabs nobody opens cost nothing.
/// - Tabs can nest. `UITabGroup` turns the overview pages into a section, and
///   on iPad the same declaration renders as a sidebar as well as a tab bar.
///
/// Nothing here configures a `UITabBarAppearance`. Under Liquid Glass the bar
/// is a floating glass surface that samples the content scrolling beneath it,
/// and a custom background would paint over the material and the scroll edge
/// effect that keeps the labels legible.
final class MainTabBarController: UITabBarController {

    /// Namespaced so customization persists against these tabs specifically,
    /// rather than against whatever happens to occupy the same position later.
    private static let customizationID = "com.complexlayout.tabs"

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTabs()
        configureNavigationStyle()
        observeVariantChanges()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--open-overview") {
            select(.overview)
        }
        #endif
    }

    /// Deliberately not in `viewDidLoad`: a view has to be in a window before
    /// it can become first responder, and it is not one yet at that point.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prewarmTextInput()
    }

    // MARK: - Tabs

    private func configureTabs() {
        tabs = [
            makeMosaicTab(),
            makeLibraryTab(),
            makeOverviewTab()
        ]
    }

    /// Tab 1 — UIKit collection view driven by a custom mosaic layout.
    ///
    /// Fixed placement: it is the app's landing tab, so it stays on the
    /// leading edge and is not something customization can move or drop.
    private func makeMosaicTab() -> UITab {
        let tab = UITab(
            title: AppTab.mosaic.title,
            image: UIImage(systemName: AppTab.mosaic.symbolName),
            identifier: AppTab.mosaic.tabIdentifier
        ) { _ in
            let mosaic = MosaicViewController()
            let navigation = UINavigationController(rootViewController: mosaic)
            navigation.navigationBar.prefersLargeTitles = true
            return navigation
        }
        tab.preferredPlacement = .fixed
        return tab
    }

    /// Tab 2 — SwiftUI `List` with multiple sections, hosted in UIKit.
    ///
    /// No `UINavigationController` here on purpose: the SwiftUI view owns its
    /// own `NavigationStack`, and nesting the two would produce a double bar.
    private func makeLibraryTab() -> UITab {
        UITab(
            title: AppTab.library.title,
            image: UIImage(systemName: AppTab.library.symbolName),
            identifier: AppTab.library.tabIdentifier
        ) { _ in
            LibraryViewController()
        }
    }

    /// Tab 3 — SwiftUI header + paged content, hosted in UIKit.
    ///
    /// A group rather than a plain tab. In the tab bar it behaves as one item
    /// and opens the pager; in the iPad sidebar it expands into a section
    /// listing the pages, so the pages become addressable without paging
    /// through them.
    ///
    /// The group's own controller is deliberately not wrapped in a
    /// `UINavigationController`: the hosting controller's view then spans the
    /// whole screen and the only safe area reaching SwiftUI is the status bar
    /// and the tab bar, which is what lets the content scroll to the physical
    /// edges the way tab 1 does.
    private func makeOverviewTab() -> UITabGroup {
        let variant = PagerVariant.current

        let pages = OverviewPage.sample.map { page in
            UITab(
                title: page.label,
                image: UIImage(systemName: page.symbolName),
                identifier: Self.pageIdentifier(for: page)
            ) { _ in
                // The same content the page shows inside the pager, without
                // the pager chrome — see `CustomPageView`, which seeds its
                // embedded mosaic from exactly this array.
                UINavigationController(
                    rootViewController: MosaicViewController(sections: page.sections)
                )
            }
        }

        let group = UITabGroup(
            title: AppTab.overview.title,
            image: UIImage(systemName: AppTab.overview.symbolName),
            identifier: AppTab.overview.tabIdentifier,
            children: pages
        ) { _ in
            variant.usesSafeAreaCancellingContainer
                ? OverviewSafeAreaCancellingContainer(variant: variant)
                : OverviewViewController(variant: variant)
        }

        // Keep the group itself reachable in the sidebar: selecting the
        // section header opens the pager, which is the thing this tab exists
        // to demonstrate and is not reachable from any single page.
        group.isSidebarDestination = true
        return group
    }

    // MARK: - Search accessory

    private lazy var searchPill: SearchPillView = {
        let view = SearchPillView()
        view.onTap = { [weak self] in self?.presentSearch() }
        return view
    }()

    /// Floats search above the tab bar instead of putting it inside.
    ///
    /// As a `UISearchTab` this was a fourth tab competing with the three
    /// content destinations, even though it is an action rather than a place.
    ///
    /// Not `bottomAccessory` either, which was the first thing tried: the
    /// accessory draws its own glass the full width of the screen and gives no
    /// way to shrink or soften it, so it covered the content it was meant to
    /// float over. See `SearchPillView`.
    ///
    /// Pinned to `contentLayoutGuide`, which is the area left unobscured by
    /// the tab bar or sidebar. The pill therefore sits just above the bar
    /// wherever the bar happens to be, and follows it down when it minimizes,
    /// without this having to know the bar's height on any platform.
    private func configureSearchPill() {
        searchPill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchPill)

        // Measured from the safe area rather than `contentLayoutGuide`: the
        // guide's bottom edge shifts by the height the accessory below
        // reserves, so anchoring to it would move the pill whenever that
        // changed. The safe area's bottom is the home indicator and stays put.
        let bottom = searchPill.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: PillOffset.aboveExpandedBar
        )
        pillBottomConstraint = bottom

        NSLayoutConstraint.activate([
            searchPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottom
        ])

        // Nothing in the layout moves when the bar minimizes, so the pill has
        // to be told. See `TabBarMinimizeSensor` for why the signal comes from
        // an empty accessory.
        let sensor = TabBarMinimizeSensor()
        sensor.onChange = { [weak self] isMinimized in
            self?.moveSearchPill(minimized: isMinimized)
        }
        bottomAccessory = UITabAccessory(contentView: sensor)
    }

    private var pillBottomConstraint: NSLayoutConstraint?

    /// Where the pill's bottom edge sits, relative to the safe area's.
    ///
    /// Both measured against the bar as it is actually drawn: the expanded bar
    /// runs to 57pt above the safe area's bottom edge, the collapsed one to
    /// 3pt, and the pill clears each by the same small margin.
    private enum PillOffset {
        /// Just clear of the top edge of the full-height bar.
        static let aboveExpandedBar: CGFloat = -57
        /// Down into the row the collapsed bar occupies, alongside it rather
        /// than stranded above it.
        static let besideMinimizedBar: CGFloat = -3
    }

    /// Drops the pill into the collapsed bar's row, or lifts it back above the
    /// expanded one.
    ///
    /// Spring-animated to sit with the bar's own movement: the sensor reports
    /// in step with that animation, so the two travel together instead of the
    /// pill snapping after the bar has already settled.
    private func moveSearchPill(minimized: Bool) {
        guard let pillBottomConstraint else { return }

        let target = minimized ? PillOffset.besideMinimizedBar : PillOffset.aboveExpandedBar
        guard pillBottomConstraint.constant != target else { return }
        pillBottomConstraint.constant = target

        // Nothing to animate before the view is on screen; the first report
        // arrives as the sensor lands in its window.
        guard view.window != nil else {
            view.layoutIfNeeded()
            return
        }

        UIView.animate(springDuration: 0.45, bounce: 0.15) {
            self.view.layoutIfNeeded()
        }
    }

    /// Opens search, growing it out of the pill that was tapped.
    ///
    /// A zoom transition rather than the default sheet slide: the pill and the
    /// search field are the same control at two sizes, so the movement should
    /// read as one expanding rather than as a new screen arriving over the old
    /// one.
    private func presentSearch() {
        let search = SearchViewController()
        search.onSelectTab = { [weak self] tab in
            guard let self else { return }
            // Dismiss first, then select: switching tabs underneath a sheet
            // that is still up leaves the wrong tab behind when it closes.
            dismiss(animated: true) { self.select(tab) }
        }
        search.onFinish = { [weak self] in self?.dismiss(animated: true) }

        let navigation = UINavigationController(rootViewController: search)
        navigation.preferredTransition = .zoom { [weak self] _ in
            self?.searchPill.zoomSourceView
        }
        present(navigation, animated: true)
    }

    private static func pageIdentifier(for page: OverviewPage) -> String {
        "\(AppTab.overview.tabIdentifier).page.\(page.id)"
    }

    // MARK: - Text input warm-up

    private var hasPrewarmedTextInput = false

    /// Starts the text input system once, quietly, just after launch.
    ///
    /// The first `becomeFirstResponder` in a process is slow — the input
    /// session has to be stood up before anything can accept typing. The
    /// search tab activates its field the moment it appears, so on the first
    /// visit that cost landed in the middle of the tab transition: the field
    /// was docked in the tab bar, but the search controller had not finished
    /// becoming active, so there was no cancel button and the browse list
    /// underneath was still laid out for a bar without a search field and
    /// scrolled up through it. It corrected itself a second or two later,
    /// which is exactly how long the cold start took.
    ///
    /// Paying that cost here, while the app is idle and the user has not yet
    /// reached the search tab, means the activation is instant when they do.
    /// Verified by hand first: warming the input system through another tab's
    /// search field before opening this one made the flash disappear.
    ///
    /// The field is never seen. It has a zero frame, and it resigns inside the
    /// same turn of the run loop it became first responder in, so no keyboard
    /// is ever presented.
    private func prewarmTextInput() {
        guard !hasPrewarmedTextInput else { return }
        hasPrewarmedTextInput = true

        let field = UITextField()
        view.addSubview(field)
        field.becomeFirstResponder()
        field.resignFirstResponder()
        field.removeFromSuperview()
    }

    // MARK: - Presentation

    private func configureNavigationStyle() {
        // Let the same tab declaration render as a sidebar where there is room
        // for one. The system shows the sidebar in landscape on iPad and the
        // tab bar in portrait, and lets people switch between them.
        mode = .tabSidebar

        // Let the bar recede while reading and come back on the way up. The
        // content in every tab is top-aligned and scrolls down, which is the
        // case `.onScrollDown` is for.
        tabBarMinimizeBehavior = .onScrollDown

        // Persist whatever people rearrange in the tab bar and sidebar.
        customizationIdentifier = Self.customizationID

        configureSearchPill()
    }

    /// Selects a top-level tab by identifier.
    ///
    /// By identifier and not by index: customization can reorder and hide
    /// tabs, so a position stops being a dependable way to name one.
    private func select(_ appTab: AppTab) {
        guard let destination = tab(forIdentifier: appTab.tabIdentifier) else { return }
        selectedTab = destination
    }

    // MARK: - Paging variant

    private var variantObserver: NSObjectProtocol?

    /// Rebuilds the overview tab when the paging implementation is switched,
    /// since the variant also decides how the hosting controller is configured
    /// and so cannot be swapped inside the existing SwiftUI tree.
    private func observeVariantChanges() {
        variantObserver = NotificationCenter.default.addObserver(
            forName: PagerVariant.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Deferred a turn on purpose. The notification is posted from a
                // SwiftUI button action, so this would otherwise replace a view
                // controller in the middle of a SwiftUI update — which was
                // observed dropping the rebuild and leaving the stored setting
                // and the running implementation out of step.
                DispatchQueue.main.async {
                    self?.rebuildOverviewTab()
                }
            }
        }
    }

    /// Swaps in a freshly built overview group.
    ///
    /// `UITab.viewController` is read-only, so the tab object itself is the
    /// unit of replacement. The new group's provider is not called until the
    /// tab is shown, which is what keeps the rebuild cheap.
    private func rebuildOverviewTab() {
        guard let index = tabs.firstIndex(where: { $0.identifier == AppTab.overview.tabIdentifier })
        else { return }

        // Selection has to be restored by hand: the replacement is a different
        // object, and a child page may have been what was selected.
        let wasSelected = selectedTab.map { selected in
            selected.identifier == AppTab.overview.tabIdentifier
                || selected.parent?.identifier == AppTab.overview.tabIdentifier
        } ?? false

        var rebuilt = tabs
        rebuilt[index] = makeOverviewTab()
        setTabs(rebuilt, animated: false)

        if wasSelected {
            select(.overview)
        }

        assert(
            tab(forIdentifier: AppTab.overview.tabIdentifier) is UITabGroup,
            "Rebuilt overview tab is no longer a group"
        )
    }
}
