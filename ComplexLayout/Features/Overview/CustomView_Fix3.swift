import SwiftUI
import UIKit

/// Keeps the original `TabView(.page)` and confines the workaround to the
/// controller embedded by each page.
struct CustomView_Fix3: View {
    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages) { page in
                Fix3ControllerView(
                    sections: page.sections,
                    contentInsets: contentInsets,
                    strategy: .current
                )
                .ignoresSafeArea()
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

// MARK: - Controller-local experiments

private enum Fix3Strategy: String {
    case compensateChild
    case invalidatePager
    case layoutPager
    case performPagerUpdates
    case disablePagerAdjustment
    case repairPageCell
    case baseline

    static var current: Self {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--fix3-strategy=")
        }), let strategy = Self(rawValue: String(argument.dropFirst("--fix3-strategy=".count))) {
            return strategy
        }
        #endif
        return .compensateChild
    }
}

private struct Fix3ControllerView: UIViewControllerRepresentable {
    let sections: [MosaicSection]
    let contentInsets: EdgeInsets
    let strategy: Fix3Strategy

    func makeUIViewController(context: Context) -> Fix3PageViewController {
        Fix3PageViewController(sections: sections, strategy: strategy)
    }

    func updateUIViewController(_ controller: Fix3PageViewController, context: Context) {
        controller.contentInsets = UIEdgeInsets(
            top: contentInsets.top,
            left: contentInsets.leading,
            bottom: contentInsets.bottom,
            right: contentInsets.trailing
        )
    }
}

/// A transparent containment layer around the unchanged MosaicViewController.
private final class Fix3PageViewController: UIViewController {
    private let mosaic: MosaicViewController
    private let strategy: Fix3Strategy
    private var scheduledRepair = false

    var contentInsets = UIEdgeInsets.zero {
        didSet { mosaic.contentInsetOverride = contentInsets }
    }

    init(sections: [MosaicSection], strategy: Fix3Strategy) {
        self.mosaic = MosaicViewController(sections: sections)
        self.strategy = strategy
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = false

        addChild(mosaic)
        mosaic.view.translatesAutoresizingMaskIntoConstraints = false
        mosaic.view.clipsToBounds = false
        view.addSubview(mosaic.view)
        NSLayoutConstraint.activate([
            mosaic.view.topAnchor.constraint(equalTo: view.topAnchor),
            mosaic.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mosaic.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mosaic.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        mosaic.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scheduleRepairIfNeeded()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        mosaic.view.transform = .identity
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.scheduleRepairIfNeeded()
        }
    }

    private func scheduleRepairIfNeeded() {
        guard !scheduledRepair else { return }
        scheduledRepair = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduledRepair = false
            self.applyStrategy()
        }
    }

    private func applyStrategy() {
        guard let pager = pagingCollectionView() else { return }

        switch strategy {
        case .compensateChild:
            compensateChildPosition()
        case .invalidatePager:
            pager.collectionViewLayout.invalidateLayout()
            pager.setNeedsLayout()
        case .layoutPager:
            pager.collectionViewLayout.invalidateLayout()
            pager.layoutIfNeeded()
        case .performPagerUpdates:
            pager.performBatchUpdates(nil)
        case .disablePagerAdjustment:
            pager.contentInsetAdjustmentBehavior = .never
            pager.contentInset = .zero
            pager.collectionViewLayout.invalidateLayout()
        case .repairPageCell:
            repairContainingPageCell()
        case .baseline:
            break
        }
    }

    private func compensateChildPosition() {
        guard let window = view.window else { return }
        let screenFrame = view.convert(view.bounds, to: window.screen.coordinateSpace)
        mosaic.view.transform = CGAffineTransform(translationX: 0, y: -screenFrame.minY)
    }

    /// Diagnostic only: this relies on SwiftUI's current UIKit implementation.
    private func repairContainingPageCell() {
        var candidate = view.superview
        while let current = candidate {
            if current is UICollectionViewCell {
                var frame = current.frame
                frame.origin.y = 0
                current.frame = frame
                return
            }
            candidate = current.superview
        }
    }

    private func pagingCollectionView() -> UICollectionView? {
        var candidate = view.superview
        while let current = candidate {
            if let collection = current as? UICollectionView, collection.isPagingEnabled {
                return collection
            }
            candidate = current.superview
        }
        return nil
    }
}
