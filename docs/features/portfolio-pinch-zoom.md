# Feature Brief: Portfolio Pinch-to-Zoom

> **Status:** Shipped 2026-05-26
> **Owner:** Aiden
> **Code:** `fl-client-ios/fl-client-ios/Core/UI/PinchToZoom.swift`
> **Applied at:** `fl-client-ios/fl-client-ios/Features/Browse/Views/PortfolioProjectsSection.swift` (carousel image cell)

---

## What it does

Instagram-style pinch zoom on portfolio photos. While the user pinches with two fingers:

- The photo lifts to a key-window overlay so it visually **escapes every parent clip** (the carousel cell's `.clipped()`, the project card's rounded `clipShape`, the enclosing scroll view).
- It **scales around the pinch-start point** — the spot under the user's fingers stays pinned as the image grows. Not around the view's center.
- It **pans freely** with the live centroid — moving both fingers across the screen drags the photo 1:1, no bounded translation formula.
- **Springs back** to the original frame on release, the overlay removes, the original re-shows.

No rotation. No persistent zoom. The gesture only lives for the duration of the touch.

---

## Architecture

**Don't try to do this in pure SwiftUI.** `scaleEffect` always respects the nearest enclosing clip context — adding `zIndex` or `compositingGroup` doesn't change that. The image stays trapped inside its container regardless of how high you bump the z-index.

The working pattern is **UIKit interop**:

1. `UIViewControllerRepresentable` wraps the SwiftUI content in a custom `UIHostingController` subclass (`PinchableHostingController`).
2. The hosting controller attaches `UIPinchGestureRecognizer` directly to its own `view` — the view that actually displays the SwiftUI content and naturally receives touches.
3. On `.began`: `snapshotView(afterScreenUpdates: false)` captures the rendered content, the snapshot is added to the **key window** at the source's screen-space frame, and the original is hidden (`alpha = 0`).
4. On `.changed`: scale + translation is applied to the snapshot via `CALayer.anchorPoint` (set to the pinch-start point in unit coords) + `layer.position` (set to the live centroid in window coords) + `transform = CGAffineTransform(scaleX: scale, y: scale)`.
5. On `.ended` / `.cancelled` / `.failed`: spring-back animation to identity transform, then overlay is removed and original's alpha restored.

---

## Things that DON'T work (don't try these again)

**❌ Transparent `.overlay` UIViewRepresentable with hitTest gating.** Overriding `hitTest` to return nil unless `event.allTouches.count >= 2` seems clever, but iOS hit-tests touches **sequentially**. When two fingers land simultaneously, the FIRST finger's hit-test sees `allTouches.count == 1`, the override returns nil, that touch goes to the SwiftUI view underneath, and the recognizer never sees it. The pinch never recognizes.

**❌ `.background` UIViewRepresentable holding a bridge UIView for snapshot.** The bridge frame timing and window-attachment ordering are awkward in `.background`; the gesture never reliably fires through to the SwiftUI gesture detection layer.

**❌ Pure SwiftUI `MagnifyGesture` + `scaleEffect` + `zIndex(99)`.** Works as a gesture (fires reliably) but the zoom is bounded by parent clipping. The "popping out" effect is not achievable in pure SwiftUI.

---

## Parent-gesture interference

When the photo is inside a sheet / modal / scroll view, pinching used to drag the background along. Two-layer fix in `PinchableHostingController`:

1. `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` returns `false` for any `UIPanGestureRecognizer` (sheet drag-to-dismiss, scroll views), `true` otherwise.
2. On pinch `.began`, walk up the ancestor view chain, collect every enabled `UIPanGestureRecognizer`, set `isEnabled = false`. Restore on `.ended` / `.cancelled` / `.failed`. Belt + suspenders — covers the case where a parent pan has already moved into `.began` before the pinch recognizes.

Without both layers, the modal under the photo follows along when you pan.

---

## Where it's applied (and where it's NOT)

**Applied:** `PortfolioProjectsSection.swift` — the `CarouselMediaCell`'s `.IMAGE` branch:

```swift
DownsampledImageView(url: ..., contentMode: .fill) { ... }
    .pinchToZoom()
```

**NOT a project-wide default.** Adding `.pinchToZoom()` to other images is intentional opt-in. The window-overlay technique:

- Has nontrivial per-instance cost (a `UIHostingController` per image).
- Suspends ancestor pan gestures globally for the duration of the pinch — fine for a photo carousel, potentially surprising for an avatar embedded in a scrollable settings list.
- Hides the original via `alpha = 0` during the gesture, which can look odd if the source view has surrounding chrome (overlapping captions, like-button hearts, etc.).

If you want a different feel for other photos (e.g. tap-to-fullscreen, center-only zoom, no escape from clipping), **build a separate modifier** rather than reusing `pinchToZoom()`. Possible variants worth a second file someday:

- `.tapToLightbox()` — present `PortfolioGalleryView` as a fullScreenCover; no in-place pinch.
- `.scaleOnPinch()` — pure SwiftUI `MagnifyGesture` + `scaleEffect`, no overlay; lighter, stays inside clipping.

---

## Known limitations

- **First touch jitter.** The very first `.changed` callback after `.began` snaps the layer's `position` to the centroid, which can shift the snapshot by a pixel or two if the user's fingers aren't perfectly still. Cosmetic.
- **Snapshot freshness.** `snapshotView(afterScreenUpdates: false)` captures whatever's currently rendered. If the image is still loading (Kingfisher placeholder visible), the overlay shows that placeholder. The user has to wait for the image to load before pinching for a clean snapshot.
- **Multiple simultaneous pinches.** A second pinch starting while the first is still animating its spring-back will create a second overlay. Probably fine in practice (the user can't realistically do this with one hand) but not explicitly guarded.

---

## Iteration history (for future-me)

This took longer than it should have. The thread for next time:

1. **Pure SwiftUI** worked but wouldn't escape clipping (`scaleEffect` respects `.clipped()`).
2. **First UIKit attempt** used a transparent overlay UIView with hitTest gating — broke gesture reception (the hit-test sequencing problem above).
3. **Second attempt** used SwiftUI `MagnifyGesture` for detection + UIKit overlay for the lift via a bridge UIView in `.background` — also didn't reliably fire.
4. **Third attempt (current)** put the SwiftUI content inside a custom `UIHostingController` and attached the recognizer to the hosting view itself. The view actually receives touches because it's the rendered content, not a transparent sibling.

If a future iOS release adds a SwiftUI-native window-overlay primitive that bypasses parent clipping, this whole file becomes deletable.
