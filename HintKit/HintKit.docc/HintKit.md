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

## Topics

### Content and presentation

- ``Hint``
- ``HintPresenter``
- ``HintOptions``
- ``HintStyle``

### History and catalogs

- ``HintStore``
- ``HintStatus``
- ``HintDisplayPolicy``
- ``HintCatalog``
- ``HintCatalogError``
