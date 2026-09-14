//
//  OverviewView.swift
//  ComplexLayout
//
//  Tab 3 — root SwiftUI view: a floating header that doubles as the page
//  indicator, over paged content that scrolls behind it to the display edges.
//

import SwiftUI

struct OverviewView: View {

    /// Published from the hosting controller. Used by every variant, so the
    /// pager is the only thing that differs between them.
    let safeArea: OverviewSafeArea

    /// Which paging implementation to build. Fixed for this controller's
    /// lifetime; changing it rebuilds the tab.
    let variant: PagerVariant

    private let pages = OverviewPage.sample

    /// Owned here so the header and the paged content stay in step.
    @State private var selection = 0

    /// Clearance the overlays must add for themselves. Zero whenever SwiftUI
    /// still has a safe area of its own to place them in.
    private var chromeInsets: EdgeInsets {
        variant.overlaysSupplyOwnClearance ? safeArea.insets : EdgeInsets()
    }

    var body: some View {
        CustomView(
            pages: pages,
            selection: $selection,
            // Absolute: everything that should stay clear at the top (status
            // bar plus header) and at the bottom (tab bar).
            contentInsets: EdgeInsets(
                top: safeArea.insets.top + OverviewHeaderView.reservedHeight,
                leading: 0,
                bottom: safeArea.insets.bottom,
                trailing: 0
            ),
            variant: variant
        )
        // An overlay rather than `safeAreaInset`: the content below spans the
        // full screen by design, so there is no safe area for the header to
        // contribute to.
        //
        // Overlays are normally placed inside the safe area already, so no
        // extra clearance is wanted — except under the variants that withhold
        // the safe area from SwiftUI, which then have none to be placed inside.
        // Applying it unconditionally double-pads the header by the full inset.
        .overlay(alignment: .top) {
            OverviewHeaderView(pages: pages, selection: $selection)
                .padding(.top, chromeInsets.top)
        }
        .overlay(alignment: .bottomLeading) {
            // Told what this tab was actually built with, rather than reading
            // the stored setting itself — see `VariantSwitcher`.
            VariantSwitcher(running: variant)
                .padding(.leading, 16)
                .padding(.bottom, chromeInsets.bottom + 12)
        }
    }
}

// MARK: - Variant switcher

/// Debug control for swapping paging implementations without a rebuild.
///
/// `running` is the variant this tab was actually constructed with, passed down
/// from the controller. The switcher deliberately keeps **no state of its own**:
/// an earlier version mirrored `PagerVariant.current` into `@State`, which gave
/// two sources of truth that could — and did — disagree. The chip reported one
/// implementation while the app ran another, which silently invalidates any
/// testing done through it.
///
/// Reading `running` instead means the label cannot lie: it is derived from the
/// object graph that is on screen.
///
/// Delete this overlay and `PagerVariant` once a single implementation is
/// settled on; nothing else depends on it.
private struct VariantSwitcher: View {

    let running: PagerVariant

    var body: some View {
        Menu {
            ForEach(PagerVariant.allCases) { option in
                Button {
                    // Only writes the stored setting. The rebuild it triggers is
                    // what changes `running`, so the label follows reality
                    // rather than anticipating it.
                    PagerVariant.current = option
                } label: {
                    if option == running {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                    Text(option.summary)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "switch.2")
                    .font(.system(size: 11, weight: .semibold))
                Text(running.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.bar))
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        }
        .accessibilityLabel("Paging implementation: \(running.title)")
    }
}
