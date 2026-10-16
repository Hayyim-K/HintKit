//
//  HintViewController.swift
//  HintKit
//
//  Created by Hayyim on 25/11/2024.
//

import UIKit

@MainActor
@objc(HintKitHintViewController)
final class HintViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var backgroundView: UIView!

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var messageLabel: UILabel!

    @IBOutlet weak var infoImageView: UIImageView!

    @IBOutlet var arrows: [UIImageView]!

    var hint: Hint?

    var position: CGPoint?

    var onDismiss: (() -> Void)?
    var onHostDisappear: (() -> Void)?
    var onLayoutChange: (() -> Void)?
    private var showsArrows = true
    private var style = HintStyle()
    private let closeButton = UIButton(type: .system)
    private let messageScroll = UIScrollView()
    private var messageHeight: NSLayoutConstraint!
    private var iconWidth: NSLayoutConstraint!

    static func make(hint: Hint, style: HintStyle, showsArrows: Bool = true) -> HintViewController? {
        let bundle = HintResources.bundle
        guard bundle.url(forResource: "Main", withExtension: "storyboardc") != nil
        else { return nil }
        let storyboard = UIStoryboard(name: "Main", bundle: bundle)
        guard let controller = storyboard.instantiateViewController(
            withIdentifier: "HintViewController") as? HintViewController
        else { return nil }
        controller.hint = hint
        controller.style = style
        controller.showsArrows = showsArrows
        controller.loadViewIfNeeded()
        return controller
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()

        let tap = UITapGestureRecognizer(target: self, action: #selector(hidTipsVC))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)

    }

    private func setupView() {

//        backgroundView.frame.origin = position
        guard let hint else { return }
        titleLabel.text = hint.title
        messageLabel.text = hint.message
        infoImageView.image = UIImage(systemName: hint.imageName)
        //        for arrow in arrows { arrow.alpha = hint.arrows.contains()}
        arrows.forEach { $0.alpha = hint.arrows.contains ($0.tag) ? 1 : 0 }

        view.accessibilityIdentifier = "HintKit.card.\(hint.id)"
        view.backgroundColor = style.backgroundColor
        view.layer.cornerRadius = max(0, style.cornerRadius)
        view.clipsToBounds = true
        view.tintColor = style.tintColor
        titleLabel.textAlignment = .natural
        messageLabel.textAlignment = .natural
        titleLabel.numberOfLines = 0
        messageLabel.numberOfLines = 0
        titleLabel.textColor = style.foregroundColor
        messageLabel.textColor = style.foregroundColor
        titleLabel.adjustsFontForContentSizeCategory = true
        messageLabel.adjustsFontForContentSizeCategory = true
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.isHidden = hint.title.isEmpty

        guard let textStack = titleLabel.superview as? UIStackView,
              let contentStack = textStack.superview as? UIStackView,
              let rootStack = contentStack.superview as? UIStackView else { return }
        rootStack.distribution = .fill
        rootStack.spacing = 8
        contentStack.isUserInteractionEnabled = true
        contentStack.distribution = .fill
        contentStack.alignment = .top
        contentStack.spacing = 8
        textStack.distribution = .fill
        textStack.spacing = 6

        // Keep the existing labels while adding an accessible close control.
        textStack.removeArrangedSubview(titleLabel)
        titleLabel.removeFromSuperview()
        let header = UIStackView(arrangedSubviews: [titleLabel, closeButton])
        header.alignment = .top
        header.spacing = 8
        textStack.insertArrangedSubview(header, at: 0)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.accessibilityLabel = style.closeAccessibilityLabel
        closeButton.accessibilityIdentifier = "HintKit.close"
        closeButton.addTarget(self, action: #selector(hidTipsVC), for: .touchUpInside)
        closeButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // Long descriptions scroll instead of being truncated at five lines.
        textStack.removeArrangedSubview(messageLabel)
        messageLabel.removeFromSuperview()
        messageScroll.translatesAutoresizingMaskIntoConstraints = false
        messageScroll.alwaysBounceVertical = false
        messageScroll.showsVerticalScrollIndicator = true
        messageScroll.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(messageScroll)
        messageHeight = messageScroll.heightAnchor.constraint(equalToConstant: 44)
        NSLayoutConstraint.activate([
            messageHeight,
            messageLabel.leadingAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.trailingAnchor),
            messageLabel.topAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.topAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: messageScroll.contentLayoutGuide.bottomAnchor),
            messageLabel.widthAnchor.constraint(equalTo: messageScroll.frameLayoutGuide.widthAnchor)
        ])

        // Replace the storyboard's proportional icon width with a bounded size.
        for constraint in view.constraints where constraint.firstItem as? UIView === infoImageView {
            if constraint.firstAttribute == .width { constraint.isActive = false }
        }
        iconWidth = infoImageView.widthAnchor.constraint(equalToConstant: 40)
        infoImageView.isHidden = infoImageView.image == nil
        iconWidth.isActive = !infoImageView.isHidden
        for arrow in arrows { arrow.semanticContentAttribute = .forceLeftToRight }
        setArrows(hint.arrows)
        view.accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: style.closeAccessibilityLabel, target: self, selector: #selector(accessibilityDismiss))]
    }

    func setAutomaticArrow(_ tag: Int) {
        let explicit = hint?.arrows.filter { (0...5).contains($0) } ?? []
        setArrows(explicit.isEmpty ? [tag] : explicit)
    }

    private func setArrows(_ tags: [Int]) {
        arrows.forEach { $0.alpha = showsArrows && tags.contains($0.tag) ? 1 : 0 }
        let rows = Set(arrows.compactMap { $0.superview as? UIStackView })
        for row in rows {
            row.semanticContentAttribute = .forceLeftToRight
            row.isHidden = !row.arrangedSubviews.contains { ($0 as? UIImageView)?.alpha == 1 }
            if !row.constraints.contains(where: { $0.identifier == "HintKit.arrowHeight" }) {
                let height = row.heightAnchor.constraint(equalToConstant: 24)
                height.identifier = "HintKit.arrowHeight"
                height.isActive = true
            }
        }
    }

    func fittingSize(width: CGFloat, maximumHeight: CGFloat) -> CGSize? {
        guard width >= 96, maximumHeight > 0 else { return nil }
        titleLabel.font = .preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        messageLabel.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let iconSpace: CGFloat = infoImageView.isHidden ? 0 : 48
        let textWidth = max(1, width - 24 - iconSpace)
        titleLabel.preferredMaxLayoutWidth = max(1, textWidth - 52)
        messageLabel.preferredMaxLayoutWidth = textWidth
        let fullMessageHeight = ceil(messageLabel.sizeThatFits(
            CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height)
        messageHeight.constant = max(1, fullMessageHeight)
        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        func measured() -> CGSize {
            let result = view.systemLayoutSizeFitting(target,
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            return CGSize(width: width, height: ceil(result.height))
        }
        var size = measured()
        if size.height > maximumHeight {
            messageHeight.constant = max(min(44, fullMessageHeight),
                                         messageHeight.constant - (size.height - maximumHeight))
            size = measured()
        }
        messageScroll.isScrollEnabled = messageHeight.constant < fullMessageHeight
        return size.height <= maximumHeight ? size : nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onHostDisappear?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        onLayoutChange?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touched = touch.view
        while let candidate = touched, candidate !== view {
            if candidate is UIControl { return false }
            touched = candidate.superview
        }
        return true
    }

    @objc private func accessibilityDismiss() -> Bool {
        hidTipsVC()
        return true
    }

    @objc private func hidTipsVC() {

        onDismiss?()

    }



}

enum HintResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: HintViewController.self)
        #endif
    }
}
