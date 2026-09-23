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
	let searchController = SearchViewController()

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
            makeOverviewTab(),
            makeSearchTab()
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

    /// Tab 4 — searches every other tab.
    ///
    /// `UISearchTab` rather than a `UITab` carrying a magnifying glass. The
    /// system supplies the symbol and localized title, separates it from the
    /// other tabs at the trailing edge, and — because no `prominentTabIdentifier`
    /// is set and this tab activates its field on appearance — gives it the
    /// prominent treatment in the bar.
    private func makeSearchTab() -> UISearchTab {
        let tab = UISearchTab { [weak self] tab in
			guard
				let self,
				let tab = tab as? UISearchTab
			else { return UINavigationController() }
			
			tab.automaticallyActivatesSearch = true
            return UINavigationController(rootViewController: searchController)
        }
        // Opening a tab whose only purpose is search should put the caret in
        // the field rather than ask for one more tap.
       // tab.automaticallyActivatesSearch = true
        // Pinned: always visible on the trailing edge, image only.
        tab.preferredPlacement = .pinned
        return tab
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
