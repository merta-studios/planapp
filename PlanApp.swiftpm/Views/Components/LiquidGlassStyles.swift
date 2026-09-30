import SwiftUI

/// Liquid Glass (Flüssigglas / Frosted Glass) ViewModifier für Karten, Abschnitte und Container
public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var strokeOpacity: Double = 0.25

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

/// Liquid Glass ButtonModifier mit optionaler Akzenttönung und Schwebereflexion
public struct LiquidGlassButtonModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var tintColor: Color? = nil
    public var isFilled: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    if let tint = tintColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(isFilled ? 0.85 : 0.15))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (tintColor ?? Color.white).opacity(isFilled ? 0.6 : 0.35),
                                (tintColor ?? Color.white).opacity(isFilled ? 0.2 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: (tintColor ?? Color.black).opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

extension View {
    /// Versieht die Ansicht mit einer edlen Liquid-Glass-Oberfläche
    public func liquidGlassCard(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.25) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    /// Macht aus dem Element einen Liquid-Glass-Button
    public func liquidGlassButton(cornerRadius: CGFloat = 12, tint: Color? = nil, isFilled: Bool = false) -> some View {
        self.modifier(LiquidGlassButtonModifier(cornerRadius: cornerRadius, tintColor: tint, isFilled: isFilled))
    }

    /// Lightweight card background without a live `.ultraThinMaterial` blur.
    /// Real-time material blur is comparatively expensive to composite, and
    /// stacking dozens of them (e.g. one per row in a scrolling settings
    /// list) is what made the Settings screen feel laggy. This keeps the same
    /// rounded, softly-outlined look using a plain, cheap color fill instead.
    public func lightCard(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.12) -> some View {
        self.modifier(LightCardModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    /// Lightweight button background, the non-material counterpart to
    /// `liquidGlassButton`, used throughout Settings for the same performance
    /// reason as `lightCard`.
    public func lightButton(cornerRadius: CGFloat = 12, tint: Color? = nil, isFilled: Bool = false) -> some View {
        self.modifier(LightButtonModifier(cornerRadius: cornerRadius, tintColor: tint, isFilled: isFilled))
    }
}

/// Cheap, opaque replacement for `LiquidGlassCardModifier` (no real-time blur).
public struct LightCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var strokeOpacity: Double = 0.12

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

/// Cheap, opaque replacement for `LiquidGlassButtonModifier` (no real-time blur).
public struct LightButtonModifier: ViewModifier {
    public var cornerRadius: CGFloat = 12
    public var tintColor: Color? = nil
    public var isFilled: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isFilled
                            ? (tintColor ?? .blue)
                            : (tintColor?.opacity(0.14) ?? Color(UIColor.tertiarySystemFill))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        (tintColor ?? Color.primary).opacity(isFilled ? 0 : 0.18),
                        lineWidth: 1
                    )
            )
    }
}

/// Reusable Liquid Glass Button Komponente
public struct LiquidGlassButtonView<Content: View>: View {
    public let action: () -> Void
    public var tint: Color? = nil
    public var isFilled: Bool = false
    public var cornerRadius: CGFloat = 12
    public let content: () -> Content

    public init(
        tint: Color? = nil,
        isFilled: Bool = false,
        cornerRadius: CGFloat = 12,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.isFilled = isFilled
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            content()
                .liquidGlassButton(cornerRadius: cornerRadius, tint: tint, isFilled: isFilled)
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(.lift)
    }
}
