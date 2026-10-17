# ``HintKit``

Contextual, nonmodal UIKit hints for iOS 15 and later.

## Overview

Create a ``Hint``, then use ``HintPresenter`` to display it near a view in an
existing view controller. The presenter keeps one card visible, tracks its
anchor, and preserves interaction with the rest of the app. Use ``HintStore``
to persist completion and dismissal, or ``HintCatalog`` to load JSON hints.

The Swift package and Xcode framework share the same implementation. Cards
load from HintKit's own resource bundle. The consuming app supplies localized
content and calls `withHintsHidden` during image export.

Use `HintOptions(pointerStyle: .tail)` for an attached bubble tail, or
`.tailAndArrows` to combine it with symbol arrows. The default remains `.arrows`.
An optional `sourcePoint` in the target view's coordinates pins the tail tip to
an exact point. Placement supports all four sides, while target highlighting
remains an independent option. Tails are nonmodal and hidden during exports.

Customize background, text, and tint colors with ``HintStyle``. Optional title
and message fonts scale through Dynamic Type by default. ``HintBorder`` follows
the entire card silhouette, including the tail. ``HintShadow`` supports an
automatic default, no shadow, or custom color, opacity, radius, and offset.

``HintAppearanceAnimation`` controls appearance through ``HintOptions``.
The default `fade` retains the released 0.15-second appearance. Opt in to
`fromAnchor` to gently expand and fade the card from its target, or choose
`none` to show it immediately.
The duration is configurable, `animates` remains the master switch, and Reduce
Motion disables appearance and highlight animations.

The default card layout centers a larger icon beside the title and description.
The close control sits separately in the corner, and long descriptions can
scroll. The refreshed layout retains the released colors and system fonts
unless a custom style is supplied.

## Topics

### Content and presentation

- ``Hint``
- ``HintPresenter``
- ``HintOptions``
- ``HintStyle``
- ``HintPointerStyle``
- ``HintPlacement``

### Appearance

- ``HintBorder``
- ``HintShadow``
- ``HintAppearanceAnimation``

### History and catalogs

- ``HintStore``
- ``HintStatus``
- ``HintDisplayPolicy``
- ``HintCatalog``
- ``HintCatalogError``
