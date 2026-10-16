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
    public var displayPolicy: HintDisplayPolicy
    public var highlightsTarget: Bool
    public var animates: Bool
    public var announcesForVoiceOver: Bool

    public init(placement: HintPlacement = .automatic,
                displayPolicy: HintDisplayPolicy = .untilDismissed,
                highlightsTarget: Bool = true, animates: Bool = true,
                announcesForVoiceOver: Bool = true, pointerStyle: HintPointerStyle = .arrows) {
        self.placement = placement
        self.pointerStyle = pointerStyle
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

    public init(maximumWidth: CGFloat = 320, screenMargin: CGFloat = 12,
                anchorSpacing: CGFloat = 8, cornerRadius: CGFloat = 20,
                backgroundColor: UIColor = .secondarySystemBackground,
                foregroundColor: UIColor = .label, tintColor: UIColor = .systemBlue,
                closeAccessibilityLabel: String? = nil,
                tailLength: CGFloat = 14, tailWidth: CGFloat = 26) {
        self.maximumWidth = maximumWidth
        self.screenMargin = screenMargin
        self.anchorSpacing = anchorSpacing
        self.cornerRadius = cornerRadius
        self.tailLength = tailLength
        self.tailWidth = tailWidth
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.tintColor = tintColor
        self.closeAccessibilityLabel = closeAccessibilityLabel ?? NSLocalizedString(
            "hintkit.dismiss", bundle: HintResources.bundle,
            comment: "Accessibility label for the hint close button")
    }
}
