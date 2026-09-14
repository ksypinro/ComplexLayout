//
//  OverviewHeaderView.swift
//  ComplexLayout
//
//  A floating capsule that doubles as the page indicator for the tab, styled
//  after the tab selector iPadOS floats at the top of a UITabBarController.
//

import SwiftUI

struct OverviewHeaderView: View {

    /// Height of the capsule itself.
    static let height: CGFloat = 100
    /// Gap between the top of the safe area and the capsule.
    static let topMargin: CGFloat = 8
    /// Gap between the capsule and where content comes to rest beneath it.
    static let bottomMargin: CGFloat = 12

    /// Vertical space the floating header needs below the top of the safe area.
    ///
    /// Content rests below this and scrolls behind the capsule, reappearing in
    /// the gap above it and at either side on its way to the display edge.
    static var reservedHeight: CGFloat { topMargin + height + bottomMargin }

    let pages: [OverviewPage]
    @Binding var selection: Int

    /// Lets the selected pill slide between cells instead of blinking.
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(pages) { page in
                Button {
                    withAnimation(.snappy(duration: 0.3)) { selection = page.id }
                } label: {
                    StatCell(
                        page: page,
                        isSelected: page.id == selection,
                        indicator: indicator
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(page.label), \(page.value)")
                .accessibilityAddTraits(page.id == selection ? [.isSelected] : [])
            }
        }
        // Inset so the selected pill never touches the capsule's edge.
        .padding(6)
        .frame(height: Self.height)
        // The capsule hugs its cells rather than spanning the width, so content
        // scrolling underneath stays visible either side of it.
        .background {
            Capsule()
                .fill(.bar)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .padding(.top, Self.topMargin)
        // Keeps the pill in step when the page changes by swipe rather than by
        // a tap on one of these cells.
        .animation(.snappy(duration: 0.3), value: selection)
    }
}

// MARK: - Stat cell

private struct StatCell: View {

    let page: OverviewPage
    let isSelected: Bool
    let indicator: Namespace.ID

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: page.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? page.tint : Color.secondary)

            Text(page.value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)

            Text(page.label)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .opacity(isSelected ? 1 : 0.6)
        .frame(minWidth: 92)
        .frame(maxHeight: .infinity)
        .background {
            if isSelected {
                Capsule()
                    .fill(page.tint.opacity(0.16))
                    .matchedGeometryEffect(id: "selectedPage", in: indicator)
            }
        }
        .contentShape(Capsule())
    }
}

#Preview {
    OverviewHeaderView(pages: OverviewPage.sample, selection: .constant(0))
}
