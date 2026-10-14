import UIKit

/// Pure geometry shared by initial placement and subsequent layout updates.
struct HintGeometry {
    let anchor: CGRect
    let safeBounds: CGRect
    let spacing: CGFloat

    func availableHeight(for placement: HintPlacement) -> CGFloat {
        switch placement {
        case .above: return max(0, anchor.minY - safeBounds.minY - spacing)
        case .below: return max(0, safeBounds.maxY - anchor.maxY - spacing)
        case .automatic: return max(availableHeight(for: .above), availableHeight(for: .below))
        }
    }

    func placements(preferred: HintPlacement) -> [HintPlacement] {
        let first: HintPlacement
        switch preferred {
        case .automatic: first = availableHeight(for: .above) > availableHeight(for: .below) ? .above : .below
        case .above, .below: first = preferred
        }
        return [first, first == .above ? .below : .above]
    }

    func frame(size: CGSize, placement: HintPlacement) -> CGRect? {
        guard size.width > 0, size.height > 0, size.width <= safeBounds.width,
              size.height <= availableHeight(for: placement) else { return nil }
        let x = min(max(anchor.midX - size.width / 2, safeBounds.minX), safeBounds.maxX - size.width)
        let y = placement == .above ? anchor.minY - spacing - size.height : anchor.maxY + spacing
        let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        return safeBounds.contains(frame) ? frame : nil
    }

    func arrowTag(frame: CGRect, placement: HintPlacement) -> Int {
        let relative = (anchor.midX - frame.minX) / frame.width
        let column = relative < 1 / 3 ? 0 : (relative > 2 / 3 ? 2 : 1)
        return (placement == .above ? 3 : 0) + column
    }
}
