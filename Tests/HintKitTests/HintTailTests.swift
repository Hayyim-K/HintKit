import UIKit
import XCTest
@testable import HintKit

final class HintTailTests: XCTestCase {
    @MainActor
    private func fixture(style: HintStyle? = nil) -> (UIWindow, UIViewController, UIButton, HintPresenter) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let host = UIViewController()
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.makeKeyAndVisible()
        let target = UIButton(type: .system)
        target.setTitle("Target", for: .normal)
        target.frame = CGRect(x: 100, y: 280, width: 140, height: 44)
        host.view.addSubview(target)
        host.view.layoutIfNeeded()
        let defaults = UserDefaults(suiteName: "HintTailTests." + UUID().uuidString)!
        return (window, host, target, HintPresenter(store: HintStore(userDefaults: defaults), style: style))
    }

    private func options(_ pointer: HintPointerStyle = .tail, placement: HintPlacement = .automatic) -> HintOptions {
        HintOptions(placement: placement, displayPolicy: .always, animates: false,
                    announcesForVoiceOver: false, pointerStyle: pointer)
    }

    @MainActor
    private func card(_ host: UIViewController) throws -> UIView {
        try XCTUnwrap(host.children.first?.view)
    }

    @MainActor
    private func bubble(_ host: UIViewController) throws -> CAShapeLayer {
        let card = try card(host)
        return try XCTUnwrap(card.superview?.layer.sublayers?.first { $0.name == "HintKit.bubble" } as? CAShapeLayer)
    }

    @MainActor
    private func visibleArrows(_ root: UIView) -> [UIImageView] {
        root.subviews.flatMap { child -> [UIImageView] in
            let arrow = child as? UIImageView
            return (arrow.map { (0...5).contains($0.tag) && $0.alpha == 1 && !$0.isHidden
                && $0.superview?.semanticContentAttribute == .forceLeftToRight ? [$0] : [] } ?? []) + visibleArrows(child)
        }
    }

    @MainActor
    func testDefaultStylePreservesLegacyArrowsWithoutTail() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "legacy", message: "Tap here"), near: target, in: host,
                                     options: options(.arrows)))
        XCTAssertEqual(HintOptions().pointerStyle, .arrows)
        XCTAssertTrue(try bubble(host).isHidden)
        XCTAssertEqual(visibleArrows(try card(host)).count, 1)
        XCTAssertNotEqual(try card(host).backgroundColor, UIColor.clear)
    }

    @MainActor
    func testTailConnectsToTargetWithoutBecomingModalOrBlockingTouches() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "tail", title: "Choose a photo", message: "Tap here"),
                                     near: target, in: host, options: options(placement: .below)))
        let card = try card(host)
        let bubble = try bubble(host)
        let path = try XCTUnwrap(bubble.path)
        XCTAssertFalse(bubble.isHidden)
        XCTAssertTrue(visibleArrows(card).isEmpty)
        XCTAssertEqual(card.backgroundColor, UIColor.clear)
        XCTAssertTrue(path.contains(CGPoint(x: card.frame.midX, y: card.frame.midY)))
        XCTAssertEqual(path.boundingBoxOfPath.minY, target.frame.maxY, accuracy: 0.01)
        XCTAssertFalse(card.frame.intersects(target.frame))
        XCTAssertNil(host.presentedViewController)
        XCTAssertTrue(host.view.hitTest(CGPoint(x: target.frame.midX, y: target.frame.midY), with: nil) === target)
        let tailPoint = CGPoint(x: target.frame.midX, y: target.frame.maxY + 3)
        XCTAssertTrue(path.contains(tailPoint))
        XCTAssertFalse(host.view.hitTest(tailPoint, with: nil) === card.superview)
    }

    @MainActor
    func testTailAndExplicitArrowsCanBeCombinedOrBothDisabled() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let hint = Hint(id: "both", message: "Tap here", arrows: [0, 5])
        XCTAssertTrue(presenter.show(hint, near: target, in: host, options: options(.tailAndArrows)))
        XCTAssertFalse(try bubble(host).isHidden)
        XCTAssertEqual(Set(visibleArrows(try card(host)).map(\.tag)), [0, 5])
        presenter.cancelAll()
        XCTAssertTrue(presenter.show(hint, near: target, in: host, options: options(.none)))
        XCTAssertTrue(try bubble(host).isHidden)
        XCTAssertTrue(visibleArrows(try card(host)).isEmpty)
    }

    @MainActor
    func testTailWorksOnAllFourCardEdgesWithinSafeArea() throws {
        for placement in [HintPlacement.above, .below, .left, .right] {
            let (window, host, target, presenter) = fixture(style: HintStyle(maximumWidth: 180))
            defer { presenter.cancelAll(); window.isHidden = true }
            if placement == .left { target.frame = CGRect(x: 280, y: 280, width: 44, height: 44) }
            if placement == .right { target.frame = CGRect(x: 20, y: 280, width: 44, height: 44) }
            XCTAssertTrue(presenter.show(Hint(id: "side", message: "Tap"), near: target, in: host,
                                         options: options(placement: placement)))
            let frame = try card(host).frame
            XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(frame))
            let outline = try XCTUnwrap(bubble(host).path).boundingBoxOfPath
            switch placement {
            case .above: XCTAssertEqual(outline.maxY, target.frame.minY, accuracy: 0.01)
            case .below: XCTAssertEqual(outline.minY, target.frame.maxY, accuracy: 0.01)
            case .left: XCTAssertEqual(outline.maxX, target.frame.minX, accuracy: 0.01)
            case .right: XCTAssertEqual(outline.minX, target.frame.maxX, accuracy: 0.01)
            case .automatic: XCTFail("A physical side was requested")
            }
        }
    }

    @MainActor
    func testExactPointInsideSourceRectRemainsPhysicalInRTL() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        host.view.semanticContentAttribute = .forceRightToLeft
        let rect = CGRect(x: 10, y: 5, width: 70, height: 30)
        let point = CGPoint(x: 22, y: 12)
        XCTAssertTrue(presenter.show(Hint(id: "point", title: "בחר תמונה", message: "לחץ כאן"),
                                     near: target, in: host, sourceRect: rect, sourcePoint: point,
                                     options: options(placement: .below)))
        let tip = target.convert(point, to: host.view)
        let bounds = try XCTUnwrap(bubble(host).path).boundingBoxOfPath
        XCTAssertEqual(bounds.minY, tip.y, accuracy: 0.01)
        XCTAssertTrue(try XCTUnwrap(bubble(host).path).contains(CGPoint(x: tip.x, y: tip.y + 1)))
    }

    @MainActor
    func testMovingSourceAndScrollingTrackTheTipAndClippedPointDismisses() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let scroll = UIScrollView(frame: CGRect(x: 30, y: 160, width: 300, height: 250))
        scroll.contentSize = CGSize(width: 300, height: 600)
        host.view.addSubview(scroll)
        target.removeFromSuperview()
        target.frame = CGRect(x: 50, y: 100, width: 140, height: 100)
        scroll.addSubview(target)
        let point = CGPoint(x: 20, y: 30)
        XCTAssertTrue(presenter.show(Hint(id: "scroll", message: "Tap here"), near: target, in: host,
                                     sourcePoint: point, options: options(placement: .below)))
        let previousY = try XCTUnwrap(bubble(host).path).boundingBoxOfPath.minY
        scroll.contentOffset.y = 20
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(try XCTUnwrap(bubble(host).path).boundingBoxOfPath.minY, previousY - 20, accuracy: 0.01)
        scroll.contentOffset.y = 140
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(presenter.currentHint)
        XCTAssertTrue(host.children.isEmpty)
    }

    @MainActor
    func testInvalidSourcePointOrTailDimensionsDoNotConsumeHistory() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        let hint = Hint(id: "invalid", message: "Tap here")
        for point in [CGPoint(x: CGFloat.nan, y: 10), CGPoint(x: -1, y: 10)] {
            XCTAssertFalse(presenter.show(hint, near: target, in: host, sourcePoint: point, options: options()))
        }
        XCTAssertEqual(presenter.store.status(for: hint.id).presentationCount, 0)
        let invalidStyle = HintStyle(tailLength: -1)
        let invalid = HintPresenter(store: presenter.store, style: invalidStyle)
        XCTAssertFalse(invalid.show(hint, near: target, in: host, options: options()))
        XCTAssertEqual(presenter.store.status(for: hint.id).presentationCount, 0)
    }

    @MainActor
    func testExportExcludesEntireBubbleAndRestoresIt() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "export", message: "Tap here"), near: target, in: host, options: options()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        func snapshot() -> Data? {
            host.view.layoutIfNeeded()
            return UIGraphicsImageRenderer(size: host.view.bounds.size, format: format).image {
                host.view.layer.render(in: $0.cgContext)
            }.pngData()
        }
        let visible = snapshot()
        let hidden = presenter.withHintsHidden { snapshot() }
        XCTAssertNotEqual(visible, hidden)
        XCTAssertEqual(snapshot(), visible)
        presenter.cancelAll()
        XCTAssertEqual(snapshot(), hidden)
    }

    @MainActor
    func testRoundedCornersDoNotDetachTailWhenAnchorIsNearScreenEdge() throws {
        let (window, host, target, presenter) = fixture(style: HintStyle(cornerRadius: 500))
        defer { presenter.cancelAll(); window.isHidden = true }
        target.frame = CGRect(x: 1, y: 280, width: 24, height: 24)
        XCTAssertTrue(presenter.show(Hint(id: "corner", message: "Tap here"), near: target, in: host,
                                     options: options(placement: .below)))
        let path = try XCTUnwrap(bubble(host).path)
        XCTAssertEqual(path.boundingBoxOfPath.minY, target.frame.maxY, accuracy: 0.01)
        XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(try card(host).frame))
    }
    @MainActor
    func testAutomaticPlacementUsesSideWhenNeitherVerticalSideFits() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        target.frame = CGRect(x: 170, y: 20, width: 44, height: 600)
        XCTAssertTrue(presenter.show(Hint(id: "horizontal", message: "Tap here"), near: target,
                                     in: host, options: options()))
        let frame = try card(host).frame
        XCTAssertLessThan(frame.maxX, target.frame.minX)
        XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(frame))
        XCTAssertEqual(try XCTUnwrap(bubble(host).path).boundingBoxOfPath.maxX, target.frame.minX, accuracy: 0.01)
    }

    @MainActor
    func testBubbleUpdatesDynamicColorWhenAppearanceChanges() async throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        host.overrideUserInterfaceStyle = .light
        XCTAssertTrue(presenter.show(Hint(id: "theme", message: "Tap here"), near: target, in: host, options: options()))
        let shape = try bubble(host)
        let light = shape.fillColor
        host.overrideUserInterfaceStyle = .dark
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNotEqual(shape.fillColor, light)
        XCTAssertEqual(shape.fillColor, presenter.style.backgroundColor.resolvedColor(with: host.traitCollection).cgColor)
    }

}
