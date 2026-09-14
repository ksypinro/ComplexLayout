//
//  MosaicSectionHeaderView.swift
//  ComplexLayout
//

import UIKit

final class MosaicSectionHeaderView: UICollectionReusableView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }

    private func setUpViews() {
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label

        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel

        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .tertiaryLabel
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 1

        let rowStack = UIStackView(arrangedSubviews: [textStack, countLabel])
        rowStack.axis = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            rowStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
        ])
    }

    func configure(with section: MosaicSection) {
        titleLabel.text = section.title
        subtitleLabel.text = section.subtitle
        countLabel.text = "\(section.tiles.count) tiles"
    }
}
