import UIKit

public enum HintPlacement: Equatable, Sendable {
    case automatic, above, below, left, right
}

/// Decorations that connect a card to its target. The target outline is independent.
public enum HintPointerStyle: Equatable, Sendable {
    case arrows, tail, tailAndArrows, none

    var hasTail: Bool { self == .tail || self == .tailAndArrows }
    var hasArrows: Bool { self == .arrows || self == .tailAndArrows }
}

/// Motion used when a hint first appears. `animates` remains the master switch.
public enum HintAppearanceAnimation: Equatable, Sendable {
    case fromAnchor, fade, none
}

/// A border follows the whole card silhouette, including an attached tail.
@MainActor
public struct HintBorder {
    public var color: UIColor
    public var width: CGFloat

    public init(color: UIColor = .separator, width: CGFloat = 1) {
        self.color = color
        self.width = width
    }
}

/// Automatic preserves the subtle tail shadow and the unshadowed legacy card.
@MainActor
public enum HintShadow {
    case automatic
    case none
    case custom(color: UIColor = .black, opacity: Float = 0.14,
                radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: 3))
}

public enum HintDisplayPolicy: Equatable, Sendable {
    case always, once, untilDismissed, untilCompleted
}

public enum HintDismissalReason: Equatable, Sendable {
    case userDismissed, actionPerformed, programmatic, anchorUnavailable
}

/// Options for one presentation, independent of the device's iOS version.
public struct HintOptions: Sendable {
    public var placement: HintPlacement
    public var pointerStyle: HintPointerStyle
    public var appearanceAnimation: HintAppearanceAnimation
    public var animationDuration: TimeInterval
    public var displayPolicy: HintDisplayPolicy
    public var highlightsTarget: Bool
    public var animates: Bool
    public var announcesForVoiceOver: Bool

    public init(placement: HintPlacement = .automatic,
                displayPolicy: HintDisplayPolicy = .untilDismissed,
                highlightsTarget: Bool = true, animates: Bool = true,
                announcesForVoiceOver: Bool = true, pointerStyle: HintPointerStyle = .arrows,
                appearanceAnimation: HintAppearanceAnimation = .fade,
                animationDuration: TimeInterval = 0.15) {
        self.placement = placement
        self.pointerStyle = pointerStyle
        self.appearanceAnimation = appearanceAnimation
        self.animationDuration = animationDuration
        self.displayPolicy = displayPolicy
        self.highlightsTarget = highlightsTarget
        self.animates = animates
        self.announcesForVoiceOver = announcesForVoiceOver
    }
}

/// Shared appearance. Supply a localized close label from your app if needed.
@MainActor
public struct HintStyle {
    public var maximumWidth: CGFloat
    public var screenMargin: CGFloat
    public var anchorSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var tailLength: CGFloat
    public var tailWidth: CGFloat
    public var backgroundColor: UIColor
    public var foregroundColor: UIColor
    public var tintColor: UIColor
    public var closeAccessibilityLabel: String
    /// Custom fonts use base sizes for the standard Dynamic Type category.
    public var titleFont: UIFont?
    public var messageFont: UIFont?
    public var scalesFontsForContentSizeCategory: Bool
    public var border: HintBorder?
    public var shadow: HintShadow

    public init(maximumWidth: CGFloat = 320, screenMargin: CGFloat = 12,
                anchorSpacing: CGFloat = 8, cornerRadius: CGFloat = 20,
                backgroundColor: UIColor = .secondarySystemBackground,
                foregroundColor: UIColor = .label, tintColor: UIColor = .systemBlue,
                closeAccessibilityLabel: String? = nil,
                tailLength: CGFloat = 14, tailWidth: CGFloat = 26,
                titleFont: UIFont? = nil, messageFont: UIFont? = nil,
                scalesFontsForContentSizeCategory: Bool = true,
                border: HintBorder? = nil, shadow: HintShadow = .automatic) {
        self.maximumWidth = maximumWidth
        self.screenMargin = screenMargin
        self.anchorSpacing = anchorSpacing
        self.cornerRadius = cornerRadius
        self.tailLength = tailLength
        self.tailWidth = tailWidth
        self.titleFont = titleFont
        self.messageFont = messageFont
        self.scalesFontsForContentSizeCategory = scalesFontsForContentSizeCategory
        self.border = border
        self.shadow = shadow
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.tintColor = tintColor
        self.closeAccessibilityLabel = closeAccessibilityLabel ?? NSLocalizedString(
            "hintkit.dismiss", bundle: HintResources.bundle,
            comment: "Accessibility label for the hint close button")
    }
    func font(for textStyle: UIFont.TextStyle, compatibleWith traits: UITraitCollection) -> UIFont {
        let supplied = textStyle == .headline ? titleFont : messageFont
        if let supplied {
            return scalesFontsForContentSizeCategory
                ? UIFontMetrics(forTextStyle: textStyle).scaledFont(for: supplied, compatibleWith: traits)
                : supplied
        }
        let category = scalesFontsForContentSizeCategory ? traits : UITraitCollection(preferredContentSizeCategory: .large)
        return .preferredFont(forTextStyle: textStyle, compatibleWith: category)
    }

    var isValid: Bool {
        guard [maximumWidth, screenMargin, anchorSpacing, cornerRadius, tailLength, tailWidth].allSatisfy(\.isFinite),
              maximumWidth > 0, screenMargin >= 0, anchorSpacing >= 0, cornerRadius >= 0,
              tailLength > 0, tailWidth > 0,
              [titleFont, messageFont].compactMap({ $0 }).allSatisfy({ $0.pointSize.isFinite && $0.pointSize > 0 })
        else { return false }
        if let border, !border.width.isFinite || border.width < 0 { return false }
        if case let .custom(_, opacity, radius, offset) = shadow {
            return opacity.isFinite && (0...1).contains(opacity) && radius.isFinite && radius >= 0
                && offset.width.isFinite && offset.height.isFinite
        }
        return true
    }

}
