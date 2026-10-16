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
        case .left, .right: return safeBounds.height
        case .automatic: return max(availableHeight(for: .above), availableHeight(for: .below))
        }
    }

    func availableWidth(for placement: HintPlacement) -> CGFloat {
        switch placement {
        case .left: return max(0, anchor.minX - safeBounds.minX - spacing)
        case .right: return max(0, safeBounds.maxX - anchor.maxX - spacing)
        case .above, .below, .automatic: return safeBounds.width
        }
    }

    func placements(preferred: HintPlacement, allowsHorizontal: Bool = false) -> [HintPlacement] {
        let vertical: [HintPlacement] = availableHeight(for: .above) > availableHeight(for: .below)
            ? [.above, .below] : [.below, .above]
        let horizontal: [HintPlacement] = availableWidth(for: .left) > availableWidth(for: .right)
            ? [.left, .right] : [.right, .left]
        switch preferred {
        case .automatic: return vertical + (allowsHorizontal ? horizontal : [])
        case .above: return [.above, .below] + (allowsHorizontal ? horizontal : [])
        case .below: return [.below, .above] + (allowsHorizontal ? horizontal : [])
        case .left: return [.left, .right] + vertical
        case .right: return [.right, .left] + vertical
        }
    }

    func frame(size: CGSize, placement: HintPlacement) -> CGRect? {
        guard size.width > 0, size.height > 0, size.width <= availableWidth(for: placement),
              size.height <= availableHeight(for: placement) else { return nil }
        let centeredX = min(max(anchor.midX - size.width / 2, safeBounds.minX), safeBounds.maxX - size.width)
        let centeredY = min(max(anchor.midY - size.height / 2, safeBounds.minY), safeBounds.maxY - size.height)
        let origin: CGPoint
        switch placement {
        case .above: origin = CGPoint(x: centeredX, y: anchor.minY - spacing - size.height)
        case .below: origin = CGPoint(x: centeredX, y: anchor.maxY + spacing)
        case .left: origin = CGPoint(x: anchor.minX - spacing - size.width, y: centeredY)
        case .right: origin = CGPoint(x: anchor.maxX + spacing, y: centeredY)
        case .automatic: return nil
        }
        let frame = CGRect(origin: origin, size: size)
        return safeBounds.contains(frame) ? frame : nil
    }

    func tip(for placement: HintPlacement) -> CGPoint {
        switch placement {
        case .above: return CGPoint(x: anchor.midX, y: anchor.minY)
        case .below, .automatic: return CGPoint(x: anchor.midX, y: anchor.maxY)
        case .left: return CGPoint(x: anchor.minX, y: anchor.midY)
        case .right: return CGPoint(x: anchor.maxX, y: anchor.midY)
        }
    }

    func arrowTag(frame: CGRect, placement: HintPlacement, point: CGPoint? = nil) -> Int {
        let relative = ((point?.x ?? anchor.midX) - frame.minX) / frame.width
        let column = relative < 1 / 3 ? 0 : (relative > 2 / 3 ? 2 : 1)
        let bottom = placement == .above || ((placement == .left || placement == .right) && (point?.y ?? anchor.midY) >= frame.midY)
        return (bottom ? 3 : 0) + column
    }
}
