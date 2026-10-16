import UIKit

@MainActor
final class HintOverlayView: UIView {
    var onLayout: (() -> Void)?
    private let bubble = CAShapeLayer()
    private let highlight = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
        bubble.name = "HintKit.bubble"
        bubble.isHidden = true
        bubble.shadowColor = UIColor.black.cgColor
        bubble.shadowOpacity = 0.14
        bubble.shadowRadius = 8
        bubble.shadowOffset = CGSize(width: 0, height: 3)
        layer.addSublayer(bubble)
        highlight.fillColor = UIColor.clear.cgColor
        highlight.lineWidth = 2
        layer.addSublayer(highlight)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    // Empty areas pass touches directly to the existing app interface.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }

    func updateHighlight(frame: CGRect, color: UIColor, visible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.isHidden = !visible
        highlight.strokeColor = color.cgColor
        highlight.path = UIBezierPath(roundedRect: frame.insetBy(dx: -3, dy: -3),
                                      cornerRadius: 8).cgPath
        CATransaction.commit()
    }

    func updateBubble(_ geometry: HintBubbleGeometry?, color: UIColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bubble.isHidden = geometry == nil
        bubble.fillColor = color.cgColor
        bubble.path = geometry?.path()
        bubble.shadowPath = bubble.path
        CATransaction.commit()
    }

    func configureHighlight(animated: Bool) {
        highlight.removeAnimation(forKey: "HintKit.pulse")
        guard animated && !UIAccessibility.isReduceMotionEnabled else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.25
        pulse.toValue = 1
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = 3
        highlight.add(pulse, forKey: "HintKit.pulse")
    }
}
