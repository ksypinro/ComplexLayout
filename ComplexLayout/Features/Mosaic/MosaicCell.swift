//
//  MosaicCell.swift
//  ComplexLayout
//

import UIKit

final class MosaicCell: UICollectionViewCell {

    private let gradientLayer = CAGradientLayer()
    private let symbolView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeLabel = BadgeLabel()
    private let textStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }

    // MARK: - Setup

    private func setUpViews() {
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = UIColor.white.withAlphaComponent(0.95)
        symbolView.setContentHuggingPriority(.required, for: .vertical)
        symbolView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.adjustsFontForContentSizeCategory = true

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(symbolView)
        contentView.addSubview(textStack)
        contentView.addSubview(badgeLabel)

        let layoutMargins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            symbolView.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
            symbolView.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),

            badgeLabel.topAnchor.constraint(equalTo: layoutMargins.topAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor),

            textStack.leadingAnchor.constraint(equalTo: layoutMargins.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: layoutMargins.trailingAnchor),
            textStack.bottomAnchor.constraint(equalTo: layoutMargins.bottomAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: symbolView.bottomAnchor, constant: 6)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // CALayer frames are not driven by Auto Layout, so keep it in sync here.
        gradientLayer.frame = contentView.bounds
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: contentView.layer.cornerRadius
        ).cgPath
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        symbolView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.18) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
            }
        }
    }

    // MARK: - Configuration

    func configure(with tile: MosaicTile) {
        // The gradient is a CALayer change; suppress the implicit animation so
        // recycled cells do not cross-fade while scrolling.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.colors = tile.tint.gradient.map(\.cgColor)
        CATransaction.commit()

        badgeLabel.text = tile.span.label
        titleLabel.text = tile.title
        subtitleLabel.text = tile.subtitle

        // Small tiles do not have the room for a subtitle or a large symbol.
        let isCompact = tile.span.unitCount < 2
        subtitleLabel.isHidden = isCompact

        titleLabel.font = .preferredFont(forTextStyle: isCompact ? .caption1 : .headline)
        subtitleLabel.font = .preferredFont(forTextStyle: .caption2)

        let symbolSize: CGFloat = isCompact ? 16 : (tile.span.unitCount >= 4 ? 30 : 24)
        symbolView.image = UIImage(
            systemName: tile.symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
        )

        let margin: CGFloat = isCompact ? 9 : 14
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: margin,
            leading: margin,
            bottom: margin,
            trailing: margin
        )

        accessibilityLabel = "\(tile.title), \(tile.subtitle), \(tile.span.label) tile"
        isAccessibilityElement = true
    }
}

// MARK: - Badge

/// Small capsule label showing a tile's footprint, e.g. `2×2`.
private final class BadgeLabel: UILabel {

    private let insets = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 10, weight: .bold)
        textColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.22)
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
