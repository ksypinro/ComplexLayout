//
//  SearchPillView.swift
//  ComplexLayout
//
//  The floating search pill that sits above the tab bar.
//

import UIKit

/// A compact glass capsule that opens search.
///
/// Deliberately *not* a `UITabAccessory`. The accessory was tried first, and
/// it is structurally the wrong shape for this: it draws its own glass across
/// the full width of the screen — visible even with the content view hidden —
/// and exposes nothing but `contentView`, so neither its size nor its opacity
/// can be brought down. A bar that wide sits on top of the content it is
/// floating over, which is the opposite of what this pill is for.
///
/// Placed by hand instead, so it can stay small and nearly clear, the way the
/// Home Screen's own search pill does above the dock.
final class SearchPillView: UIView {

    /// Called when the pill is tapped.
    var onTap: (() -> Void)?

    private let button = UIButton(type: .system)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureButton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func configureButton() {
        var configuration = UIButton.Configuration.clearGlass()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        configuration.title = "Search"
        configuration.imagePadding = 4
        configuration.baseForegroundColor = .label
        // Sized to the text rather than to the screen: the pill should read as
        // a button floating over the content, not as a bar covering it.
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 6, leading: 12, bottom: 6, trailing: 14
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .footnote)
            return attributes
        }

        button.configuration = configuration
        button.accessibilityLabel = "Search"
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// The view the presentation zooms out of, so the sheet appears to grow
    /// from the pill rather than sliding up from the bottom of the screen.
    var zoomSourceView: UIView { button }
}
