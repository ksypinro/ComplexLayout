//
//  LibraryViewController.swift
//  ComplexLayout
//
//  Bridges the SwiftUI list into the UIKit tab bar.
//

import SwiftUI
import UIKit

final class LibraryViewController: UIHostingController<LibraryListView> {

    init() {
        super.init(rootView: LibraryListView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LibraryListView())
    }
}
