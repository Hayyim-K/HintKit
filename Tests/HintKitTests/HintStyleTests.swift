import UIKit
import XCTest
@testable import HintKit

final class HintStyleTests: XCTestCase {
    @MainActor
    private func fixture(style: HintStyle) -> (UIWindow, UIViewController, UIButton, HintPresenter) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let host = UIViewController()
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.makeKeyAndVisible()
        let target = UIButton(frame: CGRect(x: 100, y: 280, width: 140, height: 44))
        host.view.addSubview(target)
        host.view.layoutIfNeeded()
        let defaults = UserDefaults(suiteName: "HintStyleTests." + UUID().uuidString)!
        return (window, host, target, HintPresenter(store: HintStore(userDefaults: defaults), style: style))
    }

    private func options(_ pointer: HintPointerStyle = .tail) -> HintOptions {
        HintOptions(displayPolicy: .always, animates: false, announcesForVoiceOver: false, pointerStyle: pointer)
    }

    @MainActor
    private func card(_ host: UIViewController) throws -> HintViewController {
        try XCTUnwrap(host.children.first as? HintViewController)
    }

    @MainActor
    private func shape(_ name: String, in host: UIViewController) throws -> CAShapeLayer {
        let card = try card(host)
        return try XCTUnwrap(card.view.superview?.layer.sublayers?.first { $0.name == name } as? CAShapeLayer)
    }

    @MainActor
    func testCustomFontsSurviveMeasurementAndTraitChangesWithoutScalingWhenDisabled() async throws {
        let title = UIFont.italicSystemFont(ofSize: 22)
        let message = UIFont.monospacedSystemFont(ofSize: 19, weight: .medium)
        let style = HintStyle(titleFont: title, messageFont: message, scalesFontsForContentSizeCategory: false)
        let (window, host, target, presenter) = fixture(style: style)
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "fonts", title: "Custom title", message: "Custom message"),
                                     near: target, in: host, options: options()))
        let card = try card(host)
        XCTAssertEqual(card.titleLabel.font.fontName, title.fontName)
        XCTAssertEqual(card.messageLabel.font.fontName, message.fontName)
        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge), forChild: card)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(card.titleLabel.font.pointSize, 22)
        XCTAssertEqual(card.messageLabel.font.pointSize, 19)
        XCTAssertFalse(card.messageLabel.adjustsFontForContentSizeCategory)
    }

    @MainActor
    func testCustomFontScalesFromItsBaseSizeWithDynamicType() {
        let base = UIFont.systemFont(ofSize: 18, weight: .medium)
        let style = HintStyle(messageFont: base)
        let normal = style.font(for: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let large = style.font(for: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge))
        XCTAssertEqual(normal.pointSize, 18)
        XCTAssertGreaterThan(large.pointSize, normal.pointSize)
        XCTAssertEqual(large.pointSize, UIFontMetrics(forTextStyle: .body).scaledFont(for: base,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)).pointSize)
    }

    @MainActor
    func testCustomBackgroundBorderAndShadowApplyToEveryPointerMode() throws {
        let style = HintStyle(backgroundColor: .systemYellow, foregroundColor: .brown, tintColor: .systemRed,
                              border: HintBorder(color: .systemPurple, width: 2),
                              shadow: .custom(color: .brown, opacity: 0.3, radius: 12, offset: CGSize(width: 2, height: 5)))
        for pointer in [HintPointerStyle.arrows, .tail, .tailAndArrows, .none] {
            let (window, host, target, presenter) = fixture(style: style)
            defer { presenter.cancelAll(); window.isHidden = true }
            XCTAssertTrue(presenter.show(Hint(id: "appearance", title: "Title", message: "Text"),
                                         near: target, in: host, options: options(pointer)))
            let fill = try shape("HintKit.bubble", in: host)
            let border = try shape("HintKit.border", in: host)
            XCTAssertEqual(fill.fillColor, style.backgroundColor.resolvedColor(with: host.traitCollection).cgColor)
            XCTAssertEqual(fill.shadowColor, UIColor.brown.resolvedColor(with: host.traitCollection).cgColor)
            XCTAssertEqual(fill.shadowOpacity, 0.3)
            XCTAssertEqual(fill.shadowRadius, 12)
            XCTAssertEqual(fill.shadowOffset, CGSize(width: 2, height: 5))
            XCTAssertFalse(border.isHidden)
            XCTAssertEqual(border.strokeColor, UIColor.systemPurple.resolvedColor(with: host.traitCollection).cgColor)
            XCTAssertEqual(border.lineWidth, 4)
            XCTAssertEqual(border.path, fill.path)
            XCTAssertEqual((border.mask as? CAShapeLayer)?.path, fill.path)
            XCTAssertEqual(try card(host).titleLabel.textColor, .brown)
            XCTAssertTrue(host.view.hitTest(CGPoint(x: target.frame.midX, y: target.frame.midY), with: nil) === target)
        }
    }

    @MainActor
    func testDefaultShadowPreservesLegacyAppearanceAndCanBeDisabledForTails() throws {
        for pointer in [HintPointerStyle.arrows, .tail] {
            let (window, host, target, presenter) = fixture(style: HintStyle())
            defer { presenter.cancelAll(); window.isHidden = true }
            XCTAssertTrue(presenter.show(Hint(id: "automatic", message: "Text"), near: target,
                                         in: host, options: options(pointer)))
            XCTAssertEqual(try shape("HintKit.bubble", in: host).shadowOpacity, pointer == .arrows ? 0 : 0.14)
            XCTAssertTrue(try shape("HintKit.border", in: host).isHidden)
        }
        let (window, host, target, presenter) = fixture(style: HintStyle(shadow: .none))
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "no-shadow", message: "Text"), near: target,
                                     in: host, options: options()))
        XCTAssertEqual(try shape("HintKit.bubble", in: host).shadowOpacity, 0)
    }

    @MainActor
    func testInvalidAppearanceDoesNotPresentOrConsumeHistory() {
        for style in [HintStyle(border: HintBorder(width: -1)), HintStyle(border: HintBorder(width: .nan)),
                      HintStyle(shadow: .custom(opacity: 2)), HintStyle(shadow: .custom(radius: -1)),
                      HintStyle(shadow: .custom(offset: CGSize(width: CGFloat.infinity, height: 0)))] {
            let (window, host, target, presenter) = fixture(style: style)
            defer { presenter.cancelAll(); window.isHidden = true }
            XCTAssertFalse(presenter.show(Hint(id: "invalid", message: "Text"), near: target, in: host, options: options()))
            XCTAssertEqual(presenter.store.status(for: "invalid").presentationCount, 0)
        }
    }

    func testScaleTransformKeepsTheAnchorFixedOnAllFourSides() {
        let bounds = CGRect(x: 0, y: 0, width: 375, height: 667)
        for origin in [CGPoint(x: 10, y: 100), CGPoint(x: 365, y: 100),
                       CGPoint(x: 180, y: 20), CGPoint(x: 180, y: 640)] {
            let relative = CGPoint(x: origin.x - bounds.midX, y: origin.y - bounds.midY)
            let transformed = relative.applying(HintAppearanceGeometry.initialTransform(origin: origin, bounds: bounds))
            XCTAssertEqual(transformed.x, relative.x, accuracy: 0.00001)
            XCTAssertEqual(transformed.y, relative.y, accuracy: 0.00001)
        }
    }

    @MainActor
    func testReducedMotionAndDisabledAnimationLeaveNoTransformOrAnimator() {
        let overlay = HintOverlayView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        var options = HintOptions()
        overlay.animateAppearance(from: CGPoint(x: 20, y: 300), options: options, reduceMotion: true)
        XCTAssertNil(overlay.appearanceAnimator)
        XCTAssertEqual(overlay.content.transform, .identity)
        XCTAssertEqual(overlay.content.alpha, 1)
        options.animates = false
        overlay.animateAppearance(from: .zero, options: options, reduceMotion: false)
        XCTAssertNil(overlay.appearanceAnimator)
        options.animates = true
        options.appearanceAnimation = .none
        overlay.animateAppearance(from: .zero, options: options, reduceMotion: false)
        XCTAssertNil(overlay.appearanceAnimator)
        options.appearanceAnimation = .fromAnchor
        options.animationDuration = 0
        overlay.animateAppearance(from: .zero, options: options, reduceMotion: false)
        XCTAssertNil(overlay.appearanceAnimator)
    }

    @MainActor
    func testAppearanceCanFinishNaturallyOrBeInterruptedWithoutResidualTransform() async throws {
        let overlay = HintOverlayView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let window = UIWindow(frame: overlay.frame)
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.addSubview(overlay)
        defer { overlay.finishAppearance(); window.isHidden = true }
        var options = HintOptions(animationDuration: 0.1)
        overlay.animateAppearance(from: CGPoint(x: 20, y: 300), options: options, reduceMotion: false)
        XCTAssertNotNil(overlay.appearanceAnimator)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(overlay.appearanceAnimator)
        XCTAssertEqual(overlay.content.transform, .identity)
        options.appearanceAnimation = .fade
        overlay.animateAppearance(from: .zero, options: options, reduceMotion: false)
        XCTAssertNotNil(overlay.appearanceAnimator)
        overlay.finishAppearance()
        XCTAssertNil(overlay.appearanceAnimator)
        XCTAssertEqual(overlay.content.transform, .identity)
        XCTAssertEqual(overlay.content.alpha, 1)
    }

    @MainActor
    func testStyledCardStillExportsWithoutAnyDecorationAndRestoresVisibility() throws {
        let (window, host, target, presenter) = fixture(style: HintStyle(backgroundColor: .systemOrange,
            border: HintBorder(color: .black, width: 3), shadow: .custom(opacity: 0.4)))
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "export-style", message: "Text"), near: target, in: host, options: options()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        func snapshot() -> Data? {
            UIGraphicsImageRenderer(size: host.view.bounds.size, format: format).image {
                host.view.layer.render(in: $0.cgContext)
            }.pngData()
        }
        let shown = snapshot()
        let hidden = presenter.withHintsHidden { snapshot() }
        XCTAssertNotEqual(shown, hidden)
        XCTAssertEqual(snapshot(), shown)
        presenter.cancelAll()
        XCTAssertEqual(snapshot(), hidden)
    }
}
