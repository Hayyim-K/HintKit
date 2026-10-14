import UIKit
import XCTest
import HintKit

final class HintPresenterTests: XCTestCase {
    @MainActor
    private func fixture() -> (UIWindow, UIViewController, UIButton, HintPresenter) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let host = UIViewController()
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.makeKeyAndVisible()
        let target = UIButton(type: .system)
        target.setTitle("Photo", for: .normal)
        target.frame = CGRect(x: 80, y: 260, width: 180, height: 44)
        host.view.addSubview(target)
        host.view.layoutIfNeeded()
        let defaults = UserDefaults(suiteName: "HintKitTests." + UUID().uuidString)!
        return (window, host, target, HintPresenter(store: HintStore(userDefaults: defaults)))
    }

    private var options: HintOptions {
        HintOptions(displayPolicy: .always, animates: false, announcesForVoiceOver: false)
    }

    @MainActor
    private func find(_ id: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == id { return view }
        return view.subviews.lazy.compactMap { self.find(id, in: $0) }.first
    }

    @MainActor
    func testCardLoadsFromPackageAndDoesNotBecomeModalOrBlockTarget() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let originalTransform = target.transform
        XCTAssertTrue(presenter.show(Hint(id: "photo", title: "Choose a photo", message: "Tap the photo.",
                                         imageName: "photo"), near: target, in: host, options: options))
        let card = try XCTUnwrap(find("HintKit.card.photo", in: host.view))
        XCTAssertNil(host.presentedViewController)
        XCTAssertEqual(host.children.count, 1)
        XCTAssertEqual(target.transform, originalTransform)
        XCTAssertFalse(card.frame.intersects(target.frame))
        let safe = host.view.safeAreaLayoutGuide.layoutFrame
        XCTAssertTrue(safe.contains(card.frame))
        let point = CGPoint(x: target.frame.midX, y: target.frame.midY)
        XCTAssertTrue(host.view.hitTest(point, with: nil) === target)
    }

    @MainActor
    func testCloseButtonCallsDismissalOnceAndReleasesChild() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        var callbacks = 0
        var reason: HintDismissalReason?
        XCTAssertTrue(presenter.show(Hint(id: "photo", message: "Tap here."), near: target, in: host,
                                     options: options, onDismiss: { callbacks += 1; reason = $0 }))
        let close = try XCTUnwrap(find("HintKit.close", in: host.view) as? UIButton)
        // Unhosted package tests have no UIApplication action dispatcher.
        let receiver = try XCTUnwrap(close.allTargets.first as? NSObject)
        let action = try XCTUnwrap(close.actions(forTarget: receiver, forControlEvent: .touchUpInside)?.first)
        receiver.perform(NSSelectorFromString(action))
        receiver.perform(NSSelectorFromString(action))
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(reason, .userDismissed)
        XCTAssertNil(presenter.currentHint)
        XCTAssertTrue(host.children.isEmpty)
        XCTAssertTrue(presenter.store.status(for: "photo").isDismissed)
    }

    @MainActor
    func testQueueSkipsCompletedHintsAndAdvancesWithoutWaitingThreads() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let once = HintOptions(displayPolicy: .untilCompleted, animates: false, announcesForVoiceOver: false)
        presenter.store.markCompleted("skip")
        presenter.enqueue(Hint(id: "first", message: "First"), near: target, in: host, options: once)
        presenter.enqueue(Hint(id: "skip", message: "Skipped"), near: target, in: host, options: once)
        presenter.enqueue(Hint(id: "last", message: "Last"), near: target, in: host, options: once)
        XCTAssertEqual(presenter.currentHint?.id, "first")
        XCTAssertEqual(presenter.pendingCount, 2)
        presenter.markCompleted("first", animated: false)
        XCTAssertEqual(presenter.currentHint?.id, "last")
        XCTAssertEqual(presenter.pendingCount, 0)
        presenter.dismiss(reason: .userDismissed, animated: false)
        XCTAssertNil(presenter.currentHint)
    }

    @MainActor
    func testUnavailableAnchorDoesNotConsumeOncePolicy() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        target.isHidden = true
        let once = HintOptions(displayPolicy: .once, animates: false, announcesForVoiceOver: false)
        let hint = Hint(id: "photo", message: "Choose a photo")
        XCTAssertFalse(presenter.show(hint, near: target, in: host, options: once))
        XCTAssertEqual(presenter.store.status(for: "photo").presentationCount, 0)
        target.isHidden = false
        XCTAssertTrue(presenter.show(hint, near: target, in: host, options: once))
        presenter.cancelAll()
        XCTAssertFalse(presenter.show(hint, near: target, in: host, options: once))
    }

    @MainActor
    func testScreenshotExcludesCardAndHighlightAndRestoresVisibility() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "photo", message: "Text"), near: target, in: host, options: options))
        let card = try XCTUnwrap(find("HintKit.card.photo", in: host.view))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        func snapshot() -> Data? {
            host.view.layoutIfNeeded()
            return UIGraphicsImageRenderer(size: host.view.bounds.size, format: format).image { context in
                host.view.layer.render(in: context.cgContext)
            }.pngData()
        }
        let visible = snapshot()
        let hidden = presenter.withHintsHidden {
            XCTAssertTrue(card.superview?.isHidden == true)
            return presenter.withHintsHidden { snapshot() }
        }
        XCTAssertFalse(card.superview?.isHidden ?? true)
        XCTAssertNotEqual(visible, hidden)
        presenter.cancelAll()
        XCTAssertEqual(hidden, snapshot())
    }

    @MainActor
    func testThrowingExportRestoresHint() async throws {
        enum Failure: Error { case expected }
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "photo", message: "Text"), near: target, in: host, options: options))
        let card = try XCTUnwrap(find("HintKit.card.photo", in: host.view))
        XCTAssertThrowsError(try presenter.withHintsHidden { throw Failure.expected })
        XCTAssertFalse(card.superview?.isHidden ?? true)
    }

    @MainActor
    func testLongDescriptionStaysInsideScreenAndCanScroll() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let hint = Hint(id: "long", title: "Instructions", message: String(repeating: "Read this instruction. ", count: 80))
        XCTAssertTrue(presenter.show(hint, near: target, in: host, options: options))
        let card = try XCTUnwrap(find("HintKit.card.long", in: host.view))
        XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(card.frame))
        func scrollViews(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
        }
        XCTAssertTrue(scrollViews(card).contains { $0.isScrollEnabled })
    }

    @MainActor
    func testMovingAndRemovingAnchorUpdatesAndDismissesCard() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        var below = options
        below.placement = .below
        XCTAssertTrue(presenter.show(Hint(id: "moving", message: "Text"), near: target, in: host, options: below))
        let card = try XCTUnwrap(find("HintKit.card.moving", in: host.view))
        let previousY = card.frame.minY
        target.frame.origin.y += 20
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(card.frame.minY, previousY + 20, accuracy: 1)
        target.removeFromSuperview()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(presenter.currentHint)
        XCTAssertTrue(host.children.isEmpty)
    }

    @MainActor
    func testKeyboardCancelsQueueWithoutMarkingFeatureCompleted() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        presenter.enqueue(Hint(id: "first", message: "Text"), near: target, in: host, options: options)
        presenter.enqueue(Hint(id: "second", message: "Text"), near: target, in: host, options: options)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        XCTAssertNil(presenter.currentHint)
        XCTAssertEqual(presenter.pendingCount, 0)
        XCTAssertFalse(presenter.store.status(for: "first").isCompleted)
        XCTAssertFalse(presenter.store.status(for: "first").isDismissed)
    }

    @MainActor
    func testPresenterDeallocationRemovesItsViews() async throws {
        let (window, host, target, prototype) = fixture()
        defer { window.isHidden = true }
        var presenter: HintPresenter? = HintPresenter(store: prototype.store)
        let weakPresenter = WeakReference(presenter)
        XCTAssertTrue(presenter!.show(Hint(id: "lifetime", message: "Text"), near: target, in: host, options: options))
        presenter = nil
        XCTAssertNil(weakPresenter.value)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(host.children.isEmpty)
        XCTAssertNil(find("HintKit.card.lifetime", in: host.view))
    }

    @MainActor
    func testQueuedRequestsDoNotRetainTheirAnchors() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "first", message: "Text"), near: target, in: host, options: options))
        weak var weakTarget: UIButton?
        autoreleasepool {
            let temporary = UIButton(frame: CGRect(x: 50, y: 400, width: 150, height: 44))
            host.view.addSubview(temporary)
            weakTarget = temporary
            presenter.enqueue(Hint(id: "gone", message: "Text"), near: temporary, in: host, options: options)
            temporary.removeFromSuperview()
        }
        // UIKit releases removed views after its current render transaction.
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(weakTarget)
        presenter.dismiss(animated: false)
        XCTAssertNil(presenter.currentHint)
        XCTAssertEqual(presenter.pendingCount, 0)
    }

    @MainActor
    func testRTLDoesNotReversePhysicalArrowDirection() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        host.view.semanticContentAttribute = .forceRightToLeft
        target.frame = CGRect(x: 12, y: 260, width: 44, height: 44)
        var below = options
        below.placement = .below
        XCTAssertTrue(presenter.show(Hint(id: "rtl", title: "בחר תמונה", message: "לחץ כאן"),
                                     near: target, in: host, options: below))
        let card = try XCTUnwrap(find("HintKit.card.rtl", in: host.view))
        func images(_ view: UIView) -> [UIImageView] {
            (view as? UIImageView).map { [$0] } ?? view.subviews.flatMap { images($0) }
        }
        let arrow = try XCTUnwrap(images(card).first {
            $0.alpha == 1 && $0.superview?.semanticContentAttribute == .forceLeftToRight
        })
        XCTAssertEqual(arrow.tag, 0)
    }
}

private final class WeakReference<Object: AnyObject> {
    weak var value: Object?
    init(_ value: Object?) { self.value = value }
}
