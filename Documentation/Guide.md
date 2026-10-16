# Integrating HintKit

This checkout prepares version **0.2.0**. The published package is still
**0.1.0**. Bubble-tail and advanced styling examples below require this local
checkout until the 0.2.0 release is published. Existing API calls compile
unchanged. The new default appearance animation expands from the target;
select `.fade` for the previous fade-only effect.

Already using 0.1.0? Start with the README's
[upgrade instructions](../README.md#updating-from-010), including preview versus
release installation, dependency rules, and preserving existing behavior.

This guide uses a photo-selection button as an example. The same steps apply
to any UIKit button, image view, or other view in the current screen.

## 1. Add the package

Add `https://github.com/Hayyim-K/HintKit.git` in Xcode's **File → Add Package
Dependencies** dialog, choose version 0.1.0 or later, and link the HintKit
product to the app target. Your app's minimum iOS version must be 15 or later.

## 2. Keep one presenter for the screen

```swift
import UIKit
import HintKit

final class PhotoViewController: UIViewController {
    @IBOutlet private weak var photoButton: UIButton!

    private let hints = HintPresenter(
        store: HintStore(namespace: "photo-editor")
    )

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showPhotoHint()
    }

    private func showPhotoHint() {
        let hint = Hint(
            id: "photo.choose",
            title: NSLocalizedString("photo_hint_title", comment: "Photo hint title"),
            message: NSLocalizedString("photo_hint_message", comment: "Photo hint description"),
            imageName: "photo"
        )
        hints.show(
            hint,
            near: photoButton,
            in: self,
            options: HintOptions(displayPolicy: .untilCompleted)
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        hints.cancelAll()
        super.viewWillDisappear(animated)
    }
}
```

Keep `hints` as a property. A temporary local presenter would be released and
its card removed. Call UI APIs on the main actor, after the screen has appeared
and the target has a layout and window.

For `Localizable.strings`, the example's English content could be:

```text
"photo_hint_title" = "Choose a photo";
"photo_hint_message" = "Tap here to choose a photo.";
```

## 3. Record success and handle transitions

Before presenting a photo picker, alert, or another screen, call:

```swift
hints.cancelAll()
```

After the picker has actually returned an image and the app has accepted it:

```swift
hints.markCompleted("photo.choose")
```

Do not record completion merely because the user opened the picker. Canceling
the picker should leave the feature eligible for help next time.

The card's close button records an explicit dismissal. `cancelAll` records
neither dismissal nor successful feature use. With `.untilCompleted`, closing
a card leaves it eligible on a later visit; with `.untilDismissed`, an explicit
close also stops future automatic presentation.

## 4. Choose the appropriate presentation mode

Use `show` for a hint relevant to the current state. It returns `false` when
the hint cannot be shown, including when another card is active, history
excludes it, or the target has disappeared. A failed attempt does not consume
the `.once` policy.

Use `enqueue` for a sequence whose targets are already available on the
current screen:

```swift
hints.enqueue(photoHint, near: photoButton, in: self)
hints.enqueue(paletteHint, near: paletteButton, in: self)
```

The next eligible hint appears after the current one closes. An unavailable
request is skipped. For steps on different screens, let each screen present
its own hint when the relevant target becomes available.

To replay a hint from a help button without resetting stored history:

```swift
hints.show(
    photoHint,
    near: photoButton,
    in: self,
    options: HintOptions(displayPolicy: .always)
)
```

## 5. Adjust placement and appearance

```swift
let style = HintStyle(
    maximumWidth: 300,
    tintColor: .systemOrange,
    closeAccessibilityLabel: NSLocalizedString(
        "dismiss_hint", comment: "Accessibility label for closing a hint"
    )
)
let hints = HintPresenter(style: style)
```

`HintOptions(placement: .above)` prefers a card above the target; the other
side can be used when it is the only side with enough room. For a large image,
pass a `sourceRect` in that image view's own coordinates to anchor to a smaller
region. Positioning is relative to the host view, not to the entire device.

Text supports Dynamic Type and natural writing direction. Long descriptions
scroll. If neither side has enough space for a readable card, `show` returns
`false`. Prefer short explanations, especially at accessibility text sizes.

The card occupies part of the screen; touches in empty overlay areas pass
through to the underlying interface. Its target outline does not change the
target view's transform. Reduce Motion disables appearance motion and pulsing.

### Add a bubble tail (0.2.0 development)

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

### Customize fonts, borders, and shadows (0.2.0 development)

```swift
let style = HintStyle(
    cornerRadius: 24,
    backgroundColor: .secondarySystemBackground,
    foregroundColor: .label,
    tintColor: .systemTeal,
    titleFont: .systemFont(ofSize: 19, weight: .bold),
    messageFont: .systemFont(ofSize: 17),
    border: HintBorder(color: .systemTeal, width: 1.5),
    shadow: .custom(color: .black, opacity: 0.2, radius: 10,
                    offset: CGSize(width: 0, height: 4))
)
let hints = HintPresenter(style: style)
```

Use base fonts at the standard Large text category, without pre-scaling them.
HintKit scales custom fonts with `UIFontMetrics` and remeasures the card when
Dynamic Type changes. Set `scalesFontsForContentSizeCategory: false` to keep
font sizes fixed. Omit custom fonts to retain system headline/body styles.

The border uses point units and follows the entire card and tail. Omit it for
no border. Shadows accept a color, opacity from 0 through 1, blur radius, and
offset. `.none` disables shadows. The default `.automatic` preserves plain
cards without a shadow and the subtle shadow for tails. Dynamic `UIColor`
values update with the host's appearance. A style is shared by one presenter;
create a presenter with a different style for another screen or theme.

### Configure appearance motion (0.2.0 development)

```swift
let options = HintOptions(
    pointerStyle: .tail,
    appearanceAnimation: .fromAnchor,
    animationDuration: 0.22
)
hints.show(photoHint, near: photoButton, in: self, options: options)
```

`.fromAnchor` is the default: the entire card fades in and gently expands
from the target point. A supplied `sourcePoint` pins the animation to that
exact point; otherwise the nearest edge of the anchor is used. The highlight
stays fixed. Select `.fade` for fade-only appearance, or `.none` for immediate
appearance. `animates: false` disables appearance and highlight animations;
zero duration disables only appearance motion. Reduce Motion disables both.

## 6. Exclude guidance from exported images

Wrap the app's synchronous screenshot operation:

```swift
let image = hints.withHintsHidden {
    renderPostcard()
}
```

`renderPostcard()` represents your existing rendering function. The closure
hides HintKit's card, tail, and outline, then restores them, including after an error
or nested calls. It does not hide other UI supplied by the app. It is intended
for synchronous rendering; do not schedule capture for later inside it.

## 7. Check the standalone demo

Clone this repository and open
`Examples/HintKitDemo/HintKitDemo.xcodeproj`. Choose the **HintKitDemo** scheme
and an iPhone or iPad simulator, then run. The demo uses the package from this
checkout through a relative local dependency.

Try the Tail / Arrows / Both / None selector and System / Paper / Night themes.
Tap Photo, Palette, and Save,
try the close button, then replay help. Reset
demo history affects only the demo's namespace. The demo does not access the
photo library or save real images.

## Responsibility of the consuming app

HintKit manages cards, target outlines, queues, and local history. Your app
owns the screen's workflow: deciding which hint is relevant, supplying its
localized text, recording actual success, canceling guidance before modal
transitions, and hiding guidance around exports.

For Xcode Cloud or other CI, use the public package URL or keep the local
package inside the checked-out source. A local absolute path on a developer's
Mac is not available to a cloud runner.
