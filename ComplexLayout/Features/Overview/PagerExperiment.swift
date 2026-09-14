import SwiftUI

/// Debug-only, launch-selected experiments. Production structure is unchanged.
#if DEBUG
enum PagerExperiment: String {
    case baseline, swiftUI, swiftUIList, swiftUIColor, plainController, proposedSize, flexibleFrame
    case explicitFrame, overlay, background, zstack, geometryPage, noPageIgnore
    case listNoIgnore, rebuildPager, rebuildPage, zeroMargins

    static var current: Self? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--pager-experiment=")
        }) else { return nil }
        return Self(rawValue: String(argument.dropFirst("--pager-experiment=".count)))
    }
}

struct ExperimentPager: View {
    let experiment: PagerExperiment
    let pages: [OverviewPage]
    @Binding var selection: Int
    let contentInsets: EdgeInsets

    var body: some View {
        if experiment == .rebuildPager || experiment == .rebuildPage {
            GeometryReader { proxy in
                if experiment == .rebuildPager {
                    pager(size: nil).id("\(proxy.size.width)x\(proxy.size.height)")
                } else {
                    TabView(selection: $selection) {
                        ForEach(pages) { page in
                            CustomPageView(page: page, contentInsets: contentInsets)
                                .id("\(page.id)-\(proxy.size.width)x\(proxy.size.height)")
                                .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
        } else if experiment == .zeroMargins {
            pager(size: nil).contentMargins(.vertical, 0, for: .scrollContent)
        } else if experiment == .explicitFrame {
            GeometryReader { proxy in
                pager(size: proxy.size)
            }
            .ignoresSafeArea()
        } else {
            pager(size: nil)
        }
    }

    private func pager(size: CGSize?) -> some View {
        TabView(selection: $selection) {
            ForEach(pages) { page in
                if let size {
                    ExperimentPage(experiment: experiment, page: page, insets: contentInsets)
                        .frame(width: size.width, height: size.height)
                        .tag(page.id)
                } else {
                    ExperimentPage(experiment: experiment, page: page, insets: contentInsets)
                        .tag(page.id)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}

private struct ExperimentPage: View {
    let experiment: PagerExperiment
    let page: OverviewPage
    let insets: EdgeInsets

    private var mosaic: MosaicControllerView {
        MosaicControllerView(sections: page.sections, contentInsets: insets)
    }

    @ViewBuilder var body: some View {
        switch experiment {
        case .listNoIgnore:
            List(0..<40) { index in
                Text("Page \(page.id) · Row \(index)")
                    .frame(height: 100)
                    .listRowBackground(page.tint.opacity(0.3))
            }
        case .swiftUIList:
            List(0..<40) { index in
                Text("Page \(page.id) · Row \(index)")
                    .frame(height: 100)
                    .listRowBackground(page.tint.opacity(0.3))
            }
            .ignoresSafeArea()
        case .swiftUIColor:
            page.tint.overlay(Text("Page \(page.id)")).ignoresSafeArea()
        case .swiftUI:
            ScrollView {
                LazyVStack {
                    ForEach(0..<40) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(page.tint.gradient)
                            .frame(height: 100)
                            .overlay(Text("Page \(page.id) · Row \(index)"))
                    }
                }
                .padding(.top, insets.top)
                .padding(.bottom, insets.bottom)
            }
            .ignoresSafeArea()
        case .plainController:
            PlainControllerPage().ignoresSafeArea()
        case .flexibleFrame:
            mosaic.frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea()
        case .overlay:
            Color.clear.overlay { mosaic }.ignoresSafeArea()
        case .background:
            Color.clear.background { mosaic }.ignoresSafeArea()
        case .zstack:
            ZStack { Color.clear; mosaic }.ignoresSafeArea()
        case .geometryPage:
            GeometryReader { proxy in
                mosaic.frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()
        case .noPageIgnore:
            mosaic
        default:
            mosaic.ignoresSafeArea()
        }
    }
}

private struct PlainControllerPage: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemTeal
        controller.view.accessibilityIdentifier = "experiment.plain-controller"
        return controller
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
#endif
