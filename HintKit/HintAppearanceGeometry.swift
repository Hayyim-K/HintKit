import UIKit

/// UIView transforms use the container center; this translation fixes the target point during scaling.
struct HintAppearanceGeometry {
    static func initialTransform(origin: CGPoint, bounds: CGRect, scale: CGFloat = 0.88) -> CGAffineTransform {
        CGAffineTransform(translationX: (origin.x - bounds.midX) * (1 - scale),
                          y: (origin.y - bounds.midY) * (1 - scale))
            .scaledBy(x: scale, y: scale)
    }
}
