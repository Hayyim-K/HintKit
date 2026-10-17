import UIKit
import XCTest
@testable import HintKit

final class HintCardLayoutTests: XCTestCase {
    @MainActor
    private func fixture(style: HintStyle? = nil, height: CGFloat = 800)
        -> (UIWindow, UIViewController, UIButton, HintPresenter) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: height))
        let host = UIViewController()
        host.view.backgroundColor = .white
        window.rootViewController = host
        window.makeKeyAndVisible()
        let target = UIButton(frame: CGRect(x: 110, y: height - 100, width: 140, height: 44))
        host.view.addSubview(target)
        host.view.layoutIfNeeded()
        let defaults = UserDefaults(suiteName: "HintCardLayoutTests." + UUID().uuidString)!
        return (window, host, target, HintPresenter(store: HintStore(userDefaults: defaults), style: style))
    }

    private var options: HintOptions {
        HintOptions(displayPolicy: .always, animates: false, announcesForVoiceOver: false, pointerStyle: .tail)
    }

    @MainActor
    private func frame(_ view: UIView, in card: HintViewController) -> CGRect {
        view.convert(view.bounds, to: card.view)
    }

    @MainActor
    func testLargeIconStaysCenteredBesideAlignedTextForDifferentSymbolsAndLengths() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        for (symbol, message) in [("flame.fill", "Tap here."),
                                  ("photo", "Choose a favourite photo, then adjust it before continuing."),
                                  ("paintpalette.fill", String(repeating: "Draw something personal. ", count: 6))] {
            XCTAssertTrue(presenter.show(Hint(id: symbol, title: "Choose a photo", message: message, imageName: symbol),
                                         near: target, in: host, options: options))
            let card = try XCTUnwrap(host.children.first as? HintViewController)
            card.view.layoutIfNeeded()
            let icon = frame(card.infoImageView, in: card)
            let scroll = try XCTUnwrap(card.messageLabel.superview as? UIScrollView)
            let text = try XCTUnwrap(scroll.superview as? UIStackView)
            XCTAssertEqual(icon.width, 60, accuracy: 0.5)
            XCTAssertEqual(icon.height, icon.width, accuracy: 0.5)
            XCTAssertEqual(icon.midY, frame(text, in: card).midY, accuracy: 0.5)
            XCTAssertLessThan(icon.maxX, frame(scroll, in: card).minX)
            XCTAssertEqual(frame(card.titleLabel, in: card).midX, frame(scroll, in: card).midX, accuracy: 0.5)
            XCTAssertEqual(card.titleLabel.textAlignment, .center)
            XCTAssertEqual(card.messageLabel.textAlignment, .center)
            presenter.cancelAll()
        }
    }

    @MainActor
    func testLongRTLTextAndLargeFontsFitTheCardAndScroll() throws {
        let style = HintStyle(titleFont: .boldSystemFont(ofSize: 28), messageFont: .systemFont(ofSize: 26))
        let (window, host, target, presenter) = fixture(style: style)
        defer { presenter.cancelAll(); window.isHidden = true }
        host.view.semanticContentAttribute = .forceRightToLeft
        XCTAssertTrue(presenter.show(Hint(id: "rtl", title: "בחר תמונה", message: String(repeating: "לחץ כאן כדי לבחור תמונה. ", count: 100), imageName: "photo"),
                                     near: target, in: host, options: options))
        let card = try XCTUnwrap(host.children.first as? HintViewController)
        card.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(card.messageLabel.superview as? UIScrollView)
        let text = try XCTUnwrap(scroll.superview as? UIStackView)
        XCTAssertTrue(scroll.isScrollEnabled)
        XCTAssertGreaterThan(card.messageLabel.bounds.height, scroll.bounds.height)
        XCTAssertTrue(card.view.bounds.contains(frame(scroll, in: card)))
        XCTAssertEqual(frame(card.infoImageView, in: card).midY, frame(text, in: card).midY, accuracy: 0.5)
        XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(card.view.frame))
    }

    @MainActor
    func testMissingTitleOrIconLeavesUsableTextAndCloseControlInAllPointerModes() throws {
        let (window, host, target, presenter) = fixture()
        defer { presenter.cancelAll(); window.isHidden = true }
        for pointer in [HintPointerStyle.arrows, .tail, .tailAndArrows, .none] {
            var options = options
            options.pointerStyle = pointer
            XCTAssertTrue(presenter.show(Hint(id: "plain", message: "Choose a photo and continue.", imageName: ""),
                                         near: target, in: host, options: options))
            let card = try XCTUnwrap(host.children.first as? HintViewController)
            card.view.layoutIfNeeded()
            let scroll = try XCTUnwrap(card.messageLabel.superview as? UIScrollView)
            let close = try XCTUnwrap(card.view.subviews.first { $0.accessibilityIdentifier == "HintKit.close" } as? UIButton)
            XCTAssertTrue(card.infoImageView.isHidden)
            XCTAssertEqual(scroll.bounds.width, card.view.bounds.width - 24, accuracy: 0.5)
            XCTAssertEqual(close.bounds.size, CGSize(width: 44, height: 44))
            XCTAssertFalse(frame(scroll, in: card).intersects(frame(close, in: card)))
            let center = close.convert(CGPoint(x: 22, y: 22), to: host.view)
            XCTAssertTrue(host.view.hitTest(center, with: nil) === close)
            presenter.cancelAll()
        }
    }

    @MainActor
    func testNarrowCardAdaptsTheIconWithoutChangingFontDefaults() throws {
        let (window, host, target, presenter) = fixture(style: HintStyle(maximumWidth: 220))
        defer { presenter.cancelAll(); window.isHidden = true }
        XCTAssertTrue(presenter.show(Hint(id: "compact", title: "Photo", message: "Tap here.", imageName: "photo"),
                                     near: target, in: host, options: options))
        let card = try XCTUnwrap(host.children.first as? HintViewController)
        card.view.layoutIfNeeded()
        XCTAssertEqual(card.infoImageView.bounds.width, 44, accuracy: 0.5)
        XCTAssertEqual(card.titleLabel.font, UIFont.preferredFont(forTextStyle: .headline, compatibleWith: card.traitCollection))
        XCTAssertEqual(card.messageLabel.font, UIFont.preferredFont(forTextStyle: .body, compatibleWith: card.traitCollection))
        XCTAssertTrue(host.view.safeAreaLayoutGuide.layoutFrame.contains(card.view.frame))
    }
}
