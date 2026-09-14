//
//  MosaicControllerView.swift
//  ComplexLayout
//
//  SwiftUI bridge for the tab 1 collection view.
//

import SwiftUI
import UIKit

/// Hosts `MosaicViewController` inside SwiftUI.
///
/// `UIViewControllerRepresentable` rather than `UIViewRepresentable`: the thing
/// being embedded is a view controller, and going through the view-controller
/// representable is what makes SwiftUI add it as a proper child — `addChild`,
/// appearance callbacks, trait propagation. Lifting only its `view` into a
/// `UIViewRepresentable` renders the same pixels but leaves the controller
/// outside the hierarchy, so none of that reaches it.
struct MosaicControllerView: UIViewControllerRepresentable {

    var sections: [MosaicSection] = MosaicSection.sampleSections()

    /// Absolute scroll insets: the status bar plus the header at the top, the
    /// tab bar at the bottom.
    ///
    /// Handed straight to the collection view rather than gone through the safe
    /// area. The controller's view spans the whole screen here, and what
    /// SwiftUI reports as its safe area does not survive the trip through a
    /// paged `TabView` reliably enough to build on.
    var contentInsets = EdgeInsets()

    func makeUIViewController(context: Context) -> MosaicViewController {
        MosaicViewController(sections: sections)
    }

    func updateUIViewController(_ controller: MosaicViewController, context: Context) {
        controller.contentInsetOverride = UIEdgeInsets(
            top: contentInsets.top,
            left: contentInsets.leading,
            bottom: contentInsets.bottom,
            right: contentInsets.trailing
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: MosaicViewController, context: Context) -> CGSize? {
        #if DEBUG
        if PagerExperiment.current == .proposedSize,
           let width = proposal.width, let height = proposal.height,
           width.isFinite, height.isFinite {
            return CGSize(width: width, height: height)
        }
        #endif
        return nil
    }
}
