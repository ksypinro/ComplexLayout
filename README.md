# ComplexLayout

iOS app built around a `UITabBarController` root with three tabs.

## Requirements

- Xcode 16 or later (developed against Xcode 27)
- iOS 17.0 deployment target
- iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`)

Open `ComplexLayout.xcodeproj` and run the `ComplexLayout` scheme.

## Structure

```
ComplexLayout/
├── App/
│   ├── AppDelegate.swift            @main, wires SceneDelegate in code
│   ├── SceneDelegate.swift          Builds the window, installs the tab bar
│   └── MainTabBarController.swift   Root controller, owns the three tabs
├── Features/
│   ├── Mosaic/                      Tab 1 — UIKit collection view
│   ├── Library/                     Tab 2 — SwiftUI list
│   └── Overview/                   Tab 3 — SwiftUI header + paged mosaics
├── Support/
│   └── UIColor+Hex.swift
└── Resources/
    └── Assets.xcassets
```

The app target uses a file system synchronized group, so files added anywhere
under `ComplexLayout/` are picked up by the target automatically — there is no
need to register them in the project file.

The `Info.plist` is generated from build settings
(`GENERATE_INFOPLIST_FILE = YES`). The scene delegate is attached in
`AppDelegate.application(_:configurationForConnecting:options:)` rather than
through a scene manifest, so there is no plist to edit when that class moves.

## Tab 1 — Mosaic

A `UICollectionView` driven by `MosaicLayout`, a custom `UICollectionViewLayout`
that packs tiles of differing footprints into a fixed column grid:

| Span          | Footprint |
| ------------- | --------- |
| `.small`      | 1×1       |
| `.tall`       | 1×2       |
| `.wide`       | 2×1       |
| `.large`      | 2×2       |

Placement uses a skyline pass: the layout tracks the bottom edge of every column
and drops each tile into the run of adjacent columns where it comes to rest
highest, breaking ties leftmost. Sizes come from the view controller through
`MosaicLayoutDelegate`, so the mix is data-driven rather than hand-authored the
way a compositional layout's group tree would have to be.

Other details worth knowing:

- Column count adapts to width (4 / 6 / 8), set in `viewWillLayoutSubviews`.
- `layoutAttributesForElements(in:)` binary searches an array ordered by `minY`,
  offset by the tallest cached element so a tall tile starting above the query
  rect is not missed.
- Only a width change invalidates the layout, not ordinary scrolling.
- The data source is keyed by `UUID` rather than by model value, so a tile's
  contents can change without the snapshot holding a stale copy. The shuffle
  button in the navigation bar reassigns every span to show the re-pack.

## Tab 2 — Library

A SwiftUI `List` with three sections (headers, footers, badges, search and a
push destination), hosted in UIKit by `LibraryViewController`, a
`UIHostingController` subclass.

The SwiftUI view owns its own `NavigationStack`, so this tab is deliberately
*not* wrapped in a `UINavigationController` — nesting the two would produce two
navigation bars.

## Tab 3 — Overview

A SwiftUI view (`OverviewView`) hosted by `OverviewViewController`, a
`UIHostingController` subclass. It is a floating capsule header
(`OverviewHeaderView`, an `HStack` of three stats) over `CustomView`, a paged
`TabView` of three `CustomPageView`s.

Each `CustomPageView` embeds tab 1's `MosaicViewController` through
`MosaicControllerView`. `MosaicViewController` gained an
`init(sections:)` — defaulting to the full sample set, which is what tab 1 still
uses — so each page can be seeded with the mosaic rotated to lead with its own
section.

### Embedding the tab 1 controller

`MosaicControllerView` is a `UIViewControllerRepresentable`, not a
`UIViewRepresentable`. The thing being embedded is a view controller, and going
through the view-controller representable is what makes SwiftUI add it as a
proper child — `addChild`, appearance callbacks, trait and safe area
propagation. Lifting only its `view` into a `UIViewRepresentable` renders the
same pixels but leaves the controller outside the hierarchy, so none of that
reaches it, including the safe area the section below depends on.

### Header as page indicator

`OverviewView` owns `selection` and hands the same binding to both the header
and the `TabView`, so the two cannot drift apart: swiping a page moves the
header highlight, and tapping a header cell pages the content. The built-in
paging dots are off (`indexDisplayMode: .never`) since the header does that job.
The underline slides between cells with `matchedGeometryEffect`.

Header cells and pages come from one array, `OverviewPage.sample` in
`OverviewModels.swift`, built from the tab 1 sample sections — so a cell's
figure and label describe the page it highlights by construction.

Tap-to-page is not required for the highlight to work; drop the `Button`
wrapper in `OverviewHeaderView` if the header should be display-only.

### Edge-to-edge scrolling

This tab must scroll to the physical edges of the device the way tab 1 does. In
tab 1 that falls out of the collection view being pinned to `view`'s own edges
rather than its safe area layout guide, so the bars contribute only a *content
inset* and tiles pass behind them.

Getting the same result through a paged `TabView` took two separate fixes, and
either one alone leaves a blank band at the top and bottom:

1. **The page has to span the full screen.** `.ignoresSafeArea()` on the
   `TabView` is not enough — it still lays each page out inside the safe area,
   so the collection view is clipped short of the display edges. `CustomPageView`
   carries its own `.ignoresSafeArea()`, which is what actually makes the page
   full-bleed.
2. **The insets have to come from outside the safe area.** What SwiftUI reports
   as the embedded controller's safe area does not survive the trip through a
   paged `TabView` dependably, so `MosaicViewController` takes a
   `contentInsetOverride`: when set, it switches the collection view to
   `contentInsetAdjustmentBehavior = .never` and uses the given insets verbatim.
   Tab 1 leaves it `nil` and keeps deriving insets from the safe area as before.

`OverviewView` measures the absolute values with `GeometryReader` —
`safeAreaInsets.top + OverviewHeaderView.height` at the top, `safeAreaInsets
.bottom` at the bottom — and passes them down through `CustomView` to each page.
Because the insets are taken verbatim, they must be absolute; an earlier version
passed only the delta and the status bar ended up counted twice.

Because the content spans the full screen by design, the header is attached with
`.overlay(alignment: .top)` rather than `.safeAreaInset` — there is no safe area
left for it to contribute to. The overlay itself still respects the safe area,
so it lands just below the status bar.

### The header: a floating capsule

`OverviewHeaderView` is styled after the tab selector iPadOS floats at the top
of a `UITabBarController` — and on iPad it sits directly beneath that selector
in the same idiom.

- The capsule hugs its three cells rather than spanning the width, so content
  scrolling underneath stays visible either side of it.
- It fills with the `.bar` material, so content shows through blurred as it
  passes behind.
- The selected page is marked by an inner pill that slides between cells with
  `matchedGeometryEffect`, rather than by an underline.

Geometry lives in three constants: `height` (the capsule), `topMargin` (gap
below the safe area) and `bottomMargin` (gap before content rests).
`reservedHeight` sums them, and is what `OverviewView` adds to
`safeAreaInsets.top` when computing the content inset — so moving or resizing
the capsule keeps the content resting correctly underneath it with no other
edits.

Because the content spans the full screen, tiles pass behind the capsule,
reappear in the gap above it and at either side, and carry on to the display
edge — the same way content behaves under the floating tab bar at the bottom.

Whatever replaces `CustomPageView` has to preserve both properties above or the
edge-to-edge scrolling breaks: it must span the full screen, and it must apply
the insets as a scroll *content inset* rather than as padding or a frame inset.
