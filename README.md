# HintKit

This branch prepares **HintKit 0.2.0**. The current published release is
**0.1.0**; the 0.2.0 additions will be released after review.

Contextual, nonmodal UIKit hints for iOS 15 and later. The same implementation
works across supported iOS versions, without an Apple TipKit dependency.

Show a card next to a button or image, highlight the target, and remember which
features the user has learned. HintKit handles presentation; your app supplies
the content and decides when an action has actually succeeded.

<p>
  <img src="Documentation/Images/demo-light.png" width="260" alt="HintKit demo in light appearance, with a card pointing to the photo button">
  <img src="Documentation/Images/demo-dark.png" width="260" alt="HintKit demo in dark appearance">
</p>

- Anchored cards with automatic arrows, optional curved bubble tails, and safe-area placement.
- One visible hint at a time, with an optional queue and completion history.
- Customizable appearance and an optional animated target outline.
- Dynamic Type, VoiceOver, Reduce Motion, and right-to-left text support.
- JSON catalogs, localized content supplied by the app, and screenshot exclusion.
- No third-party dependencies. Distributed under the [MIT license](LICENSE).

HintKit includes a Swift package, an Xcode framework target, automated tests,
and a standalone demo. Both distribution forms use the same Swift files and
storyboard. The package manifest uses Swift tools version 5.9.

| Requirement | Version |
| --- | --- |
| App deployment target | iOS 15 or later |
| Swift package tools | Swift 5.9 or later, with an iOS SDK |
| Included Xcode projects | Xcode 16 or later |

For a step-by-step integration walkthrough, see the [integration guide](Documentation/Guide.md).

## Install with Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/Hayyim-K/HintKit.git`, and select version **0.1.0** or later.
Add the **HintKit** library product to your app target.

For a package manifest:

```swift
dependencies: [
    .package(url: "https://github.com/Hayyim-K/HintKit.git", from: "0.1.0")
]
```

Add `.product(name: "HintKit", package: "HintKit")` to your target's dependencies.
The package includes its storyboard and localized resources automatically.

## Try the demo

Open `Examples/HintKitDemo/HintKitDemo.xcodeproj`, select the shared
`HintKitDemo` scheme, and run on an iPhone or iPad simulator. It imports HintKit
as a local Swift package. Tap Photo, Palette, and Save to complete the sequence.
Show help again replays hints without resetting history. Reset demo history
affects only the demo's HintKit namespace.

Use the Tail / Arrows / Both / None selector to compare pointer styles.
The demo starts with Tail; the library default remains Arrows.
Use System / Paper / Night to compare fonts, backgrounds, borders, and shadows.

The demo simulates these actions; it does not choose or save real photos.

## Add to an app

For local development, add this repository's root directory as a local Swift
package dependency and link its `HintKit` product. Alternatively, add
`HintKit.xcodeproj`, depend on its framework target, and embed the resulting
framework in the app. Use one distribution form per app target.

For CI, the source must be checked out with the app or made available as a
package dependency. A path outside the checked-out repository is not available
on Xcode Cloud. Keep the `Main.storyboard` and `Resources` directory with the
package; HintKit loads them from its own bundle, not `Bundle.main`.

## Show a hint

Keep a presenter as a property of the host view controller. Call `show` after
the host has appeared and its target view is laid out. All UI APIs run on the
main actor.

```swift
import UIKit
import HintKit

final class PhotoViewController: UIViewController {
    @IBOutlet private weak var photoButton: UIButton!
    private let hints = HintPresenter()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hints.show(
            Hint(id: "photo.choose", title: "Choose a photo",
                 message: "Tap here to choose a photo.", imageName: "photo"),
            near: photoButton, in: self
        )
    }

    @IBAction private func photoChosen(_ sender: UIButton) {
        hints.markCompleted("photo.choose")
    }

    override func viewWillDisappear(_ animated: Bool) {
        hints.cancelAll()
        super.viewWillDisappear(animated)
    }
}
```

`show` returns `false` if another card is active, its display policy excludes it,
the host has another presented controller, the target is hidden/offscreen, or
there is not enough room to fit a readable card. Failed attempts do not consume
history. The target must belong to the host's view hierarchy and window.

Cards are child view controllers inside the host, not modal presentations.
Empty overlay areas pass touches through to the existing interface. The card
is placed within the safe area, above or below the anchor by default. Descriptions scroll
when necessary. A display link tracks movement and scrolling of the target;
the card closes if its anchor disappears. Keyboard appearance, app inactivity,
and host disappearance cancel active and pending hints.

For a large view, `sourceRect` can specify a smaller anchor region in that
view's coordinates. `HintOptions.placement` expresses a preference; the other
side is used if it is the only side with enough space.

## Bubble tails and exact targets (0.2.0 development)

<img src="Documentation/Images/demo-tail.png" width="280" alt="HintKit card with an attached curved tail pointing to the photo button">

Opt in to a curved tail that joins the card background and points to its target:

```swift
hints.show(
    Hint(id: "photo.choose", title: "Choose a photo", message: "Tap here."),
    near: photoButton,
    in: self,
    sourcePoint: CGPoint(x: photoButton.bounds.midX, y: photoButton.bounds.minY),
    options: HintOptions(placement: .above, pointerStyle: .tail)
)
```

`sourcePoint` is optional. It is expressed in the target view's own coordinates
and must be inside `sourceRect` (or `target.bounds` when no rectangle is given).
Without a point, the tail aims at the nearest edge of the visible anchor region.
`sourceRect` still controls the region used for placement and highlighting, so a
precise tip does not require a zero-sized rectangle or a separate invisible view.

| `HintOptions.pointerStyle` | Presentation |
| --- | --- |
| `.arrows` | Existing SF Symbol arrows; the default for existing callers. |
| `.tail` | A curved tail attached to the card background. |
| `.tailAndArrows` | Both the tail and the existing arrows. |
| `.none` | No pointer decoration. |

`highlightsTarget` independently controls the target outline in all four modes.
Existing `Hint.arrows` tags and JSON files keep their original meaning.

Cards can prefer `.above`, `.below`, `.left`, or `.right`. In automatic tail mode,
HintKit first tries above/below, then the horizontal sides if there is too little
vertical room. Existing automatic arrow mode continues to use above/below.
Left/right are physical directions and are not mirrored by RTL text layout.

Use `HintStyle(tailLength: 14, tailWidth: 26)` to change the tail's dimensions in
points. `tailLength` reserves additional space between card and anchor, on top
of `anchorSpacing`. An explicit point deeper inside the target can make the
actual tail longer. The base stays clear of rounded corners; the tip keeps its
exact target position even when the card has to shift near a screen edge.

The tail and card use one background path, including with translucent colors.
They remain nonmodal: the tail never intercepts touches or becomes a separate
VoiceOver element. Movement, scrolling, appearance changes, dismissal, and
`withHintsHidden` cover the entire bubble. A clipped/offscreen exact point
causes the hint to close rather than leave a detached pointer.

These additions are in the current checkout and are not part of the published
0.1.0 tag. Use the local package to try them before the next release.

## Queue and history

```swift
hints.enqueue(photoHint, near: photoButton, in: self)
hints.enqueue(paletteHint, near: paletteButton, in: self)
```

Eligible hints appear one at a time. Dismissal advances the queue, without
background threads or semaphores. Hosts and anchors are held weakly.
Callbacks run once for hints that were actually shown, not skipped requests.
Use `cancelAll` before presenting a photo picker, alert, or another screen.

The default policy is `untilDismissed`:

| Policy | Display condition |
| --- | --- |
| `always` | Ignore history; useful for a help button. |
| `once` | No previous successful presentation. |
| `untilDismissed` | Neither explicitly dismissed nor completed. |
| `untilCompleted` | Feature use has not been recorded; closing the card is insufficient. |

Call `markCompleted` when the relevant action actually succeeds. Programmatic
cancellation does not mark the feature completed or explicitly dismissed.

```swift
let store = HintStore(namespace: "photo-editor")
let hints = HintPresenter(store: store)
let replay = HintOptions(displayPolicy: .always)
hints.show(photoHint, near: photoButton, in: self, options: replay)
```

`HintStore` persists counts, dismissal, and completion in UserDefaults.
Namespaces isolate independent flows. `reset(id)` affects one hint;
`resetAll()` affects only the current namespace, never unrelated app settings.
Tests can inject a separate UserDefaults suite.

## JSON and localization

`HintCatalog` accepts the original Space Wildfires JSON array format:

```json
[
  {
    "id": "photo.choose",
    "title": "Choose a photo",
    "message": "Tap here to choose a photo.",
    "imageName": "photo",
    "arrows": []
  }
]
```

```swift
let catalog = try HintCatalog(contentsOf: jsonURL)
if let hint = catalog["photo.choose"] {
    hints.show(hint, near: photoButton, in: self)
}
```

Empty and duplicate identifiers throw `HintCatalogError`. Invalid JSON throws
the underlying decoding error. `title`, `imageName`, and `arrows` can be omitted.
Leave `arrows` empty for automatic direction. Legacy tags 0–2 represent upper
left/center/right arrows and 3–5 represent lower arrows.

Localize title and message in the consuming app before constructing a Hint.
There is no dependency on a particular app's localization mechanism.
For a translated VoiceOver close label, pass `HintStyle(closeAccessibilityLabel:)`.
Text supports Dynamic Type and natural writing direction; directional arrows
remain tied to physical anchor coordinates in right-to-left interfaces.

## Appearance and export

Pass a `HintStyle` when creating the presenter. It applies to that presenter's
cards, including every pointer mode:

```swift
let style = HintStyle(
    maximumWidth: 300,
    cornerRadius: 24,
    backgroundColor: .secondarySystemBackground,
    foregroundColor: .label,
    tintColor: .systemOrange,
    titleFont: .systemFont(ofSize: 19, weight: .bold),
    messageFont: .systemFont(ofSize: 17),
    border: HintBorder(color: .systemOrange, width: 1.5),
    shadow: .custom(color: .black, opacity: 0.2, radius: 10,
                    offset: CGSize(width: 0, height: 4))
)
let hints = HintPresenter(style: style)
```

Custom fonts use unscaled base sizes at the standard Large text category.
HintKit scales them with `UIFontMetrics`; pass
`scalesFontsForContentSizeCategory: false` to keep their sizes fixed. `nil`
fonts retain the system headline/body styles. Dynamic colors follow the host's
light/dark appearance, including the border and shadow.

Borders follow the whole silhouette, including a tail, and draw inside it.
Omit `border` for no outline. `shadow: .none` removes the shadow; the default
`.automatic` keeps plain arrow cards unshadowed and gives tail cards a subtle
shadow. Shadows do not clip the text or intercept touches.

<p>
  <img src="Documentation/Images/demo-paper.png" width="260" alt="Paper theme with serif fonts, a warm background, border, and shadow">
  <img src="Documentation/Images/demo-night.png" width="260" alt="Night theme with custom fonts, a dark background, and teal border">
</p>

### Appearance animation (0.2.0 development)

Cards now gently expand from the target while fading in over 0.22 seconds.
An explicit `sourcePoint` is also the animation's origin. The background,
tail, border, shadow, and content move together; the target outline stays fixed.
Configure motion per presentation:

```swift
let options = HintOptions(
    pointerStyle: .tail,
    appearanceAnimation: .fromAnchor,
    animationDuration: 0.22
)
hints.show(photoHint, near: photoButton, in: self, options: options)
```

Choose `.fade` for the previous fade-only effect or `.none` for immediate
appearance. `animates: false` disables both appearance motion and outline
pulsing; a zero duration disables appearance motion only. Reduce Motion
disables all these animations. Existing calls compile unchanged; `.fromAnchor`
is the new default appearance animation in 0.2.0.

The highlight animates a separate layer, without modifying the target's
transform. Visible hints can be
announced to VoiceOver; disable this per presentation with
`announcesForVoiceOver: false` when the app provides its own announcement.

Hide cards and highlight layers during synchronous image capture:

```swift
let image = hints.withHintsHidden {
    renderPostcard()
}
```

Visibility is restored even if the operation throws. Nested capture blocks
are supported. The consuming app remains responsible for using this API
around its screenshot/export code.

## Tests

The shared HintKit Xcode scheme runs the tests under `Tests/HintKitTests`:

```sh
xcodebuild -project HintKit.xcodeproj -scheme HintKit \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=17.5' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Select a simulator installed on your Mac. The same tests are declared by the
Swift package and can be run from its package workspace in Xcode. They cover
JSON compatibility, persistence, eligibility, queueing, resource loading,
touch passthrough, close callbacks, moving anchors, long text, keyboard
cancellation, and export visibility.

The Xcode test targets use iOS 17 or later to match the XCTest runtime in the
current SDK. The HintKit library and demo app still support iOS 15.

The demo UI tests tap the highlighted controls, close a card, replay help,
and switch pointer modes and themes through the real app interface:

```sh
xcodebuild -project Examples/HintKitDemo/HintKitDemo.xcodeproj \
  -scheme HintKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2,arch=arm64' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

Adjust the destination and architecture for your Mac and installed simulators.

The initial release was verified with all 19 tests in both distribution forms
on iOS 17.5, the demo UI test on iOS 26.2, and an unsigned Release build for an
iPhone destination. Direct runtime verification on iOS 15 is still pending.
The 0.2.0 development branch adds coverage for tails, styling, and animation:
39 framework tests on iOS 17.5 and 3 demo UI tests on iOS 26.2 passed. The demo
build verifies the local Swift package and its resources.

## Contributing

Bug reports and pull requests are welcome. Include the iOS and Xcode versions,
the anchor's layout, and a small reproduction when reporting a placement issue.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

## License

HintKit is available under the [MIT license](LICENSE).
Copyright © 2024–2026 Vitalii Kukhar (Hayyim).
