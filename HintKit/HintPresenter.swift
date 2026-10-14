import UIKit

/// Presents one nonmodal hint at a time inside an existing view controller.
/// Keep this object alive for as long as its hints should remain visible.
@MainActor
public final class HintPresenter: NSObject {
    public let store: HintStore
    public let style: HintStyle
    public var onShow: ((Hint) -> Void)?
    public var onDismiss: ((Hint, HintDismissalReason) -> Void)?
    public var currentHint: Hint? { current?.request.hint }
    public var pendingCount: Int { pending.count }

    private var current: HintSession?
    private var pending: [HintRequest] = []
    private var displayLink: CADisplayLink?
    private var captureDepth = 0

    public init(store: HintStore? = nil, style: HintStyle? = nil) {
        self.store = store ?? HintStore()
        self.style = style ?? HintStyle()
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(interactionInterrupted),
                           name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(interactionInterrupted),
                           name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(accessibilityChanged),
                           name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(accessibilityChanged),
                           name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    /// Returns false when another hint is active, the policy rejects the hint,
    /// or its host/anchor cannot safely display a card. Call after viewDidAppear.
    @discardableResult
    public func show(_ hint: Hint, near target: UIView, in host: UIViewController,
                     sourceRect: CGRect? = nil, options: HintOptions = HintOptions(),
                     onDismiss: ((HintDismissalReason) -> Void)? = nil) -> Bool {
        guard current == nil else { return false }
        return present(HintRequest(hint: hint, target: target, host: host,
                                   sourceRect: sourceRect, options: options, callback: onDismiss))
    }

    /// Shows eligible queued hints in order. Requests hold host and target weakly.
    public func enqueue(_ hint: Hint, near target: UIView, in host: UIViewController,
                        sourceRect: CGRect? = nil, options: HintOptions = HintOptions(),
                        onDismiss: ((HintDismissalReason) -> Void)? = nil) {
        pending.append(HintRequest(hint: hint, target: target, host: host,
                                   sourceRect: sourceRect, options: options, callback: onDismiss))
        advanceQueue()
    }

    public func dismiss(reason: HintDismissalReason = .programmatic, animated: Bool = true) {
        guard let session = current, !session.isDismissing else { return }
        session.isDismissing = true
        session.overlay.isUserInteractionEnabled = false
        session.card.onDismiss = nil
        session.card.onHostDisappear = nil
        session.card.onLayoutChange = nil
        displayLink?.invalidate()
        displayLink = nil
        switch reason {
        case .userDismissed: store.markDismissed(session.request.hint.id)
        case .actionPerformed: store.markCompleted(session.request.hint.id)
        case .programmatic, .anchorUnavailable: break
        }
        let finish = { [weak self, session] in
            session.remove()
            guard let self, self.current === session else { return }
            self.current = nil
            session.request.callback?(reason)
            self.onDismiss?(session.request.hint, reason)
            self.advanceQueue()
        }
        if animated && session.request.options.animates && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.15, animations: {
                session.overlay.alpha = 0
            }, completion: { _ in finish() })
        } else {
            finish()
        }
    }

    /// Cancels pending requests as well as the current card before a transition.
    public func cancelAll(animated: Bool = false) {
        pending.removeAll()
        dismiss(reason: .programmatic, animated: animated)
    }

    /// Records actual feature use and closes a matching hint if it is visible.
    public func markCompleted(_ id: String, animated: Bool = true) {
        store.markCompleted(id)
        if currentHint?.id == id { dismiss(reason: .actionPerformed, animated: animated) }
    }

    /// Excludes cards and highlights from synchronous screenshot/export work.
    /// Nested calls are supported, including when the operation throws.
    public func withHintsHidden<Result>(_ operation: () throws -> Result) rethrows -> Result {
        captureDepth += 1
        current?.overlay.isHidden = true
        defer {
            captureDepth -= 1
            if captureDepth == 0 { current?.overlay.isHidden = false }
        }
        return try operation()
    }

    private func advanceQueue() {
        while current == nil && !pending.isEmpty {
            if present(pending.removeFirst()) { break }
        }
    }

    private func present(_ request: HintRequest) -> Bool {
        guard !request.hint.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [style.maximumWidth, style.screenMargin, style.anchorSpacing, style.cornerRadius].allSatisfy(\.isFinite),
              style.cornerRadius >= 0,
              store.shouldDisplay(request.hint.id, policy: request.options.displayPolicy),
              let host = request.host, let target = request.target,
              canPresent(host: host, target: target),
              let card = HintViewController.make(hint: request.hint, style: style)
        else { return false }
        host.view.layoutIfNeeded()
        let overlay = HintOverlayView(frame: host.view.bounds)
        let session = HintSession(request: request, card: card, overlay: overlay)
        guard layout(session) else { return false }

        current = session
        host.addChild(card)
        host.view.addSubview(overlay)
        overlay.addSubview(card.view)
        card.didMove(toParent: host)
        overlay.isHidden = captureDepth > 0
        card.onDismiss = { [weak self] in self?.dismiss(reason: .userDismissed) }
        card.onHostDisappear = { [weak self] in self?.cancelAll() }
        card.onLayoutChange = { [weak self] in
            self?.current?.layoutKey = nil
            self?.refreshLayout()
        }
        overlay.onLayout = { [weak self] in self?.refreshLayout() }
        store.recordPresentation(request.hint.id)

        let proxy = HintDisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(HintDisplayLinkProxy.tick))
        link.preferredFramesPerSecond = 10
        link.add(to: .main, forMode: .common)
        displayLink = link
        overlay.configureHighlight(animated: request.options.animates)
        if request.options.animates && !UIAccessibility.isReduceMotionEnabled {
            card.view.alpha = 0
            UIView.animate(withDuration: 0.15) { card.view.alpha = 1 }
        }
        onShow?(request.hint)
        if current === session && captureDepth == 0 && request.options.announcesForVoiceOver
            && UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: [request.hint.title, request.hint.message]
                                    .filter { !$0.isEmpty }.joined(separator: ". "))
        }
        return true
    }

    private func canPresent(host: UIViewController, target: UIView) -> Bool {
        guard host.isViewLoaded, let window = host.view.window, !window.isHidden,
              target.window === window, target.isDescendant(of: host.view),
              host.presentedViewController == nil, !host.isBeingDismissed,
              !host.isMovingFromParent else { return false }
        var ancestor: UIView? = target
        while let view = ancestor {
            if view.isHidden || view.alpha <= 0.01 { return false }
            if view === host.view { break }
            ancestor = view.superview
        }
        return true
    }

    private func layout(_ session: HintSession) -> Bool {
        guard let host = session.request.host, let target = session.request.target,
              canPresent(host: host, target: target) else { return false }
        let source = session.request.sourceRect ?? target.bounds
        guard source.width > 0, source.height > 0,
              [source.minX, source.minY, source.width, source.height].allSatisfy(\.isFinite)
        else { return false }
        let bounds = host.view.bounds
        let offset = CGPoint(x: -bounds.minX, y: -bounds.minY)
        let anchor = target.convert(source, to: host.view).offsetBy(dx: offset.x, dy: offset.y)
        let margin = style.screenMargin
        guard style.maximumWidth.isFinite, margin.isFinite, style.anchorSpacing.isFinite,
              style.maximumWidth > 0, margin >= 0, style.anchorSpacing >= 0 else { return false }
        let safe = host.view.safeAreaLayoutGuide.layoutFrame
            .offsetBy(dx: offset.x, dy: offset.y).insetBy(dx: margin, dy: margin)
        guard !safe.isEmpty, anchor.intersects(CGRect(origin: .zero, size: bounds.size)) else { return false }
        // A scrolled-out anchor must not leave a detached hint on screen.
        var ancestor = target.superview
        while let view = ancestor, view !== host.view {
            if view.clipsToBounds && !target.convert(source, to: view).intersects(view.bounds) {
                return false
            }
            ancestor = view.superview
        }

        let key = HintLayoutKey(bounds: bounds, anchor: anchor, safe: safe,
                                category: session.card.traitCollection.preferredContentSizeCategory.rawValue)
        if session.layoutKey == key {
            session.overlay.updateHighlight(frame: anchor,
                color: style.tintColor.resolvedColor(with: host.traitCollection),
                visible: session.request.options.highlightsTarget)
            return true
        }

        let geometry = HintGeometry(anchor: anchor, safeBounds: safe, spacing: style.anchorSpacing)
        let width = min(style.maximumWidth, safe.width)
        for placement in geometry.placements(preferred: session.request.options.placement) {
            session.card.setAutomaticArrow(placement == .above ? 4 : 1)
            guard let size = session.card.fittingSize(width: width,
                                                       maximumHeight: geometry.availableHeight(for: placement)),
                  let frame = geometry.frame(size: size, placement: placement) else { continue }
            session.card.setAutomaticArrow(geometry.arrowTag(frame: frame, placement: placement))
            session.overlay.frame = bounds
            session.card.view.frame = frame
            session.overlay.updateHighlight(frame: anchor,
                color: style.tintColor.resolvedColor(with: host.traitCollection),
                visible: session.request.options.highlightsTarget)
            session.layoutKey = key
            return true
        }
        return false
    }

    fileprivate func refreshLayout() {
        guard let session = current, !session.isDismissing, !session.isLayingOut else { return }
        session.isLayingOut = true
        let valid = layout(session)
        session.isLayingOut = false
        if !valid {
            pending.removeAll()
            dismiss(reason: .anchorUnavailable, animated: false)
        }
    }

    @objc private func interactionInterrupted() { cancelAll() }
    @objc private func accessibilityChanged() {
        current?.layoutKey = nil
        refreshLayout()
        current?.overlay.configureHighlight(animated: current?.request.options.animates ?? false)
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
        let session = current
        Task { @MainActor in session?.remove() }
    }
}

@MainActor
private final class HintRequest {
    let hint: Hint
    weak var target: UIView?
    weak var host: UIViewController?
    let sourceRect: CGRect?
    let options: HintOptions
    let callback: ((HintDismissalReason) -> Void)?

    init(hint: Hint, target: UIView, host: UIViewController, sourceRect: CGRect?,
         options: HintOptions, callback: ((HintDismissalReason) -> Void)?) {
        self.hint = hint
        self.target = target
        self.host = host
        self.sourceRect = sourceRect
        self.options = options
        self.callback = callback
    }
}

@MainActor
private final class HintSession {
    let request: HintRequest
    let card: HintViewController
    let overlay: HintOverlayView
    var isDismissing = false
    var isLayingOut = false
    var layoutKey: HintLayoutKey?

    init(request: HintRequest, card: HintViewController, overlay: HintOverlayView) {
        self.request = request
        self.card = card
        self.overlay = overlay
    }

    func remove() {
        card.onDismiss = nil
        card.onHostDisappear = nil
        card.onLayoutChange = nil
        overlay.onLayout = nil
        card.willMove(toParent: nil)
        card.view.removeFromSuperview()
        card.removeFromParent()
        overlay.removeFromSuperview()
    }
}

private struct HintLayoutKey: Equatable {
    let bounds: CGRect
    let anchor: CGRect
    let safe: CGRect
    let category: String
}

@MainActor
private final class HintDisplayLinkProxy: NSObject {
    weak var owner: HintPresenter?
    init(owner: HintPresenter) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) {
        guard let owner else { link.invalidate(); return }
        owner.refreshLayout()
    }
}
