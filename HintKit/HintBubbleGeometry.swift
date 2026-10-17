import UIKit

/// One continuous outline prevents seams between a translucent card and its tail.
struct HintBubbleGeometry {
    let frame: CGRect
    let tip: CGPoint
    let placement: HintPlacement
    let cornerRadius: CGFloat
    let tailWidth: CGFloat

    var radius: CGFloat {
        let sideLength = placement == .above || placement == .below ? frame.width : frame.height
        let baseWidth = min(tailWidth, sideLength)
        return max(0, min(cornerRadius, frame.width / 2, frame.height / 2, (sideLength - baseWidth) / 2))
    }

    func path() -> CGPath {
        let r = radius
        let path = UIBezierPath()
        let left = frame.minX, right = frame.maxX, top = frame.minY, bottom = frame.maxY
        path.move(to: CGPoint(x: left + r, y: top))
        edge(path, to: CGPoint(x: right - r, y: top), hasTail: placement == .below)
        path.addQuadCurve(to: CGPoint(x: right, y: top + r), controlPoint: CGPoint(x: right, y: top))
        edge(path, to: CGPoint(x: right, y: bottom - r), hasTail: placement == .left)
        path.addQuadCurve(to: CGPoint(x: right - r, y: bottom), controlPoint: CGPoint(x: right, y: bottom))
        edge(path, to: CGPoint(x: left + r, y: bottom), hasTail: placement == .above)
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - r), controlPoint: CGPoint(x: left, y: bottom))
        edge(path, to: CGPoint(x: left, y: top + r), hasTail: placement == .right)
        path.addQuadCurve(to: CGPoint(x: left + r, y: top), controlPoint: CGPoint(x: left, y: top))
        path.close()
        return path.cgPath
    }

    private func edge(_ path: UIBezierPath, to end: CGPoint, hasTail: Bool) {
        let start = path.currentPoint
        let length = hypot(end.x - start.x, end.y - start.y)
        guard hasTail, length > 0 else { path.addLine(to: end); return }
        let direction = CGVector(dx: (end.x - start.x) / length, dy: (end.y - start.y) / length)
        let normal = CGVector(dx: direction.dy, dy: -direction.dx)
        let depth = (tip.x - start.x) * normal.dx + (tip.y - start.y) * normal.dy
        guard depth > 0 else { path.addLine(to: end); return }
        let half = min(tailWidth, length) / 2
        let projected = (tip.x - start.x) * direction.dx + (tip.y - start.y) * direction.dy
        let center = min(max(projected, half), length - half)
        func along(_ distance: CGFloat) -> CGPoint {
            CGPoint(x: start.x + direction.dx * distance, y: start.y + direction.dy * distance)
        }
        let first = along(center - half)
        let second = along(center + half)
        let nearTip = CGPoint(x: tip.x - normal.dx * depth * 0.25,
                              y: tip.y - normal.dy * depth * 0.25)
        path.addLine(to: first)
        path.addCurve(to: tip,
                      controlPoint1: along(center - half * 0.25), controlPoint2: nearTip)
        path.addCurve(to: second, controlPoint1: nearTip,
                      controlPoint2: along(center + half * 0.25))
        path.addLine(to: end)
    }
}
