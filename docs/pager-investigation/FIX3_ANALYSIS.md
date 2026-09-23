# Fix 3: preserve `TabView(.page)` by refreshing the pager

## Conclusion

The 58-point band can be removed without replacing the original pager or the
`UIViewControllerRepresentable` structure. `CustomView_Fix3` assigns the
`TabView` an identity derived from the full-screen container size. A rotation
therefore creates a fresh paging container for the new size instead of asking
the old `PagingCollectionView` to re-layout through its defective rotation
path.

The hierarchy remains:

```text
UITabBarController
  UIHostingController<OverviewView>
    TabView(.page)
      UIViewControllerRepresentable
        MosaicViewController
          UICollectionView
```

## What the additional controls established

The defect is not unique to `MosaicViewController`, its custom collection-view
layout, or its constraints. A plain empty `UIViewController` page reproduced
the same pager content height of 704 and page-cell origin of -58.

A SwiftUI `List` also produced the same native pager displacement when tested
with the same full-screen safe-area modifiers. This can be visually hidden by
the List's own opaque background and safe-area behavior, but the captured
`UIKitPagingCell` was still at y = -58. The representable makes the symptom
more apparent; it is not required for the pager's incorrect geometry.

## Experiment matrix

All landscape measurements followed a portrait-to-landscape rotation on the
iPad Air 11-inch (M4), iPadOS 27.0 simulator.

| Experiment | Pager content height | Page-cell y | Result |
| --- | ---: | ---: | --- |
| Original representable page | 704 | -58 | Failed |
| SwiftUI `List` page | 704 | -58 | Failed geometrically |
| Plain `UIViewController` representable | 704 | -58 | Failed |
| Representable `sizeThatFits` | 704 | -58 | Failed |
| Explicit page frame | 704 | -58 | Failed; distorted descendant height |
| SwiftUI overlay wrapper | 704 | -58 | Failed |
| `GeometryReader` inside each page | 704 | -58 | Failed |
| Zero scroll-content margins | 704 | -58 | Failed |
| Remove page `.ignoresSafeArea()` | 704 | -58 | Failed; mosaic became 724 pt high |
| Rebuild individual pages by size | 704 | -58 plus stale page | Failed |
| Rebuild the `TabView` by size | 820 | 0 | Passed |

The distinction between the last two tests matters. The error belongs to the
pager instance. Refreshing content underneath it cannot repair the pager's
cached content-size decision.

## Fix 3 verification

The final automated test selected page 2 from the header, rotated to landscape,
paged to page 3 with a horizontal drag, rotated back to portrait, then rotated
to the opposite landscape orientation. Native UIKit captures were taken at
each settled checkpoint.

| Checkpoint | Pager height | Visible cell y | Mosaic screen frame |
| --- | ---: | ---: | --- |
| Selected page, portrait | 1180 | 0 | 820 x 1180 at (0,0) |
| First landscape | 820 | 0 | 1180 x 820 at (0,0) |
| After paging in landscape | 820 | 0 | 1180 x 820 at (0,0) |
| Returned portrait | 1180 | 0 | 820 x 1180 at (0,0) |
| Opposite landscape | 820 | 0 | 1180 x 820 at (0,0) |

At every checkpoint the mosaic kept its expected absolute insets and initial
offset: top 216, bottom 20, `contentOffset.y = -216`. No captured layout was
ambiguous. The interaction test passed, including selection surviving pager
recreation and swipe-to-page updating the header.

## Trade-off

Changing the `TabView` identity recreates its representable children whenever
the container size changes. Page selection survives because it is owned by
`OverviewView`, above the identity boundary. Each mosaic controller's vertical
scroll position resets to its initial position. Preserving per-page vertical
offsets would require storing them outside the recreated controllers and
restoring them after construction.

The test covers repeated device rotation on one iPadOS 27.0 simulator. Split
View, Stage Manager resizing, iPhone, accessibility size changes, and live
window resizing have not yet been verified.
