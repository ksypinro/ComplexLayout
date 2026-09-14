//
//  MainTabBarController.swift
//  ComplexLayout
//
//  Root of the app. Owns the three top-level tabs.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = [
            makeMosaicTab(),
            makeLibraryTab(),
            makeOverviewTab()
        ]

        // Keep the bar opaque while content scrolls underneath it.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        observeVariantChanges()
        #if DEBUG
        if PagerExperiment.current != nil { selectedIndex = 2 }
        #endif
    }

    // MARK: - Paging variant

    private var variantObserver: NSObjectProtocol?

    /// Rebuilds tab 3 when the paging implementation is switched, since the
    /// variant also decides how the hosting controller is configured and so
    /// cannot be swapped inside the existing SwiftUI tree.
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

    private func rebuildOverviewTab() {
        guard var controllers = viewControllers, controllers.count == 3 else { return }
        let selected = selectedIndex
        controllers[2] = makeOverviewTab()
        setViewControllers(controllers, animated: false)
        selectedIndex = selected
        assert(
            (controllers[2] as? OverviewViewController)?.builtVariant == PagerVariant.current
                || controllers[2] is OverviewSafeAreaCancellingContainer,
            "Rebuilt tab does not match the stored variant"
        )
    }

    // MARK: - Tabs

    /// Tab 1 — UIKit collection view driven by a custom mosaic layout.
    private func makeMosaicTab() -> UIViewController {
        let mosaic = MosaicViewController()
        let navigation = UINavigationController(rootViewController: mosaic)
        navigation.navigationBar.prefersLargeTitles = true
        navigation.tabBarItem = UITabBarItem(
            title: "Mosaic",
            image: UIImage(systemName: "square.grid.3x3"),
            selectedImage: UIImage(systemName: "square.grid.3x3.fill")
        )
        return navigation
    }

    /// Tab 2 — SwiftUI `List` with multiple sections, hosted in UIKit.
    ///
    /// No `UINavigationController` here on purpose: the SwiftUI view owns its
    /// own `NavigationStack`, and nesting the two would produce a double bar.
    private func makeLibraryTab() -> UIViewController {
        let library = LibraryViewController()
        library.tabBarItem = UITabBarItem(
            title: "Library",
            image: UIImage(systemName: "list.bullet.rectangle"),
            selectedImage: UIImage(systemName: "list.bullet.rectangle.fill")
        )
        return library
    }

    /// Tab 3 — SwiftUI header + content view, hosted in UIKit.
    ///
    /// Deliberately not wrapped in a `UINavigationController`: the hosting
    /// controller's view then spans the whole screen and the only safe area
    /// reaching SwiftUI is the status bar and the tab bar, which is what lets
    /// the content scroll to the physical edges the way tab 1 does.
    private func makeOverviewTab() -> UIViewController {
        let variant = PagerVariant.current
        let overview: UIViewController = variant.usesSafeAreaCancellingContainer
            ? OverviewSafeAreaCancellingContainer(variant: variant)
            : OverviewViewController(variant: variant)
        overview.tabBarItem = UITabBarItem(
            title: "Overview",
            image: UIImage(systemName: "square.stack.3d.up"),
            selectedImage: UIImage(systemName: "square.stack.3d.up.fill")
        )
        return overview
    }
}
