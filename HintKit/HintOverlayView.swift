import UIKit

@MainActor
final class HintOverlayView: UIView {
    var onLayout: (() -> Void)?
    let content = HintPassthroughView()
    private let bubble = CAShapeLayer()
    private let border = CAShapeLayer()
    private let borderMask = CAShapeLayer()
    private let highlight = CAShapeLayer()
    private(set) var appearanceAnimator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
        content.frame = bounds
        bubble.name = "HintKit.bubble"
        border.name = "HintKit.border"
        border.fillColor = UIColor.clear.cgColor
        border.lineJoin = .round
        border.zPosition = 1
        borderMask.fillColor = UIColor.black.cgColor
        border.mask = borderMask
        highlight.name = "HintKit.highlight"
        highlight.fillColor = UIColor.clear.cgColor
        highlight.lineWidth = 2
        layer.addSublayer(highlight)
        addSubview(content)
        content.layer.addSublayer(bubble)
        content.layer.addSublayer(border)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    // Empty areas pass touches directly to the existing app interface.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Bounds and center stay well-defined while the content is transformed.
        content.bounds = CGRect(origin: .zero, size: bounds.size)
        content.center = CGPoint(x: bounds.midX, y: bounds.midY)
        onLayout?()
    }

    func setHintsHidden(_ hidden: Bool) {
        isHidden = hidden
        content.isHidden = hidden
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

    func updateBubble(_ geometry: HintBubbleGeometry?, frame: CGRect, style: HintStyle,
                      traits: UITraitCollection) {
        let path = geometry?.path() ?? UIBezierPath(roundedRect: frame,
            cornerRadius: min(style.cornerRadius, frame.width / 2, frame.height / 2)).cgPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bubble.frame = content.bounds
        border.frame = content.bounds
        borderMask.frame = border.bounds
        bubble.fillColor = style.backgroundColor.resolvedColor(with: traits).cgColor
        bubble.path = path
        bubble.shadowPath = path
        switch style.shadow {
        case .automatic:
            setShadow(color: .black, opacity: geometry == nil ? 0 : 0.14,
                      radius: 8, offset: CGSize(width: 0, height: 3), traits: traits)
        case .none:
            setShadow(color: .black, opacity: 0, radius: 0, offset: .zero, traits: traits)
        case let .custom(color, opacity, radius, offset):
            setShadow(color: color, opacity: opacity, radius: radius, offset: offset, traits: traits)
        }
        // Clip a doubled stroke to the silhouette to keep the border entirely inside it.
        border.isHidden = style.border == nil || style.border?.width == 0
        border.path = path
        border.strokeColor = style.border?.color.resolvedColor(with: traits).cgColor
        border.lineWidth = (style.border?.width ?? 0) * 2
        borderMask.path = path
        CATransaction.commit()
    }

    private func setShadow(color: UIColor, opacity: Float, radius: CGFloat, offset: CGSize,
                           traits: UITraitCollection) {
        bubble.shadowColor = color.resolvedColor(with: traits).cgColor
        bubble.shadowOpacity = opacity
        bubble.shadowRadius = radius
        bubble.shadowOffset = offset
    }

    func animateAppearance(from origin: CGPoint, options: HintOptions,
                           reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled) {
        finishAppearance()
        guard options.animates, !reduceMotion, options.animationDuration > 0,
              options.appearanceAnimation != .none else { return }
        content.alpha = 0
        if options.appearanceAnimation == .fromAnchor {
            content.transform = HintAppearanceGeometry.initialTransform(origin: origin, bounds: content.bounds)
        }
        let animator = UIViewPropertyAnimator(duration: options.animationDuration, curve: .easeOut)
        appearanceAnimator = animator
        animator.addAnimations { [weak self] in
            self?.content.alpha = 1
            self?.content.transform = .identity
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, self.appearanceAnimator === animator else { return }
            self.appearanceAnimator = nil
        }
        animator.startAnimation()
    }

    func finishAppearance() {
        let animator = appearanceAnimator
        appearanceAnimator = nil
        if let animator, animator.state == .active {
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        }
        content.alpha = 1
        content.transform = .identity
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

@MainActor
final class HintPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}
