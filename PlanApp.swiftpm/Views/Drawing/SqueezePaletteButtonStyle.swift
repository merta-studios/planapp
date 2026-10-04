import SwiftUI

/// Runde Bedienelemente mit dem nativen Liquid-Glass-Material der iPadOS-26-
/// Navigationsbuttons (wie „Zurück“). Ältere Playgrounds-/SDK-Versionen behalten
/// einen Material-Fallback mit Lichtkante, Reflexion und Druck-Feedback.
struct SqueezePaletteButtonStyle: ButtonStyle {
    var isSelected = false
    var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(SqueezeButtonGlassSurface(isSelected: isSelected, isHovered: isHovered))
            .contentShape(Circle())
            .brightness(configuration.isPressed ? -0.12 : (isHovered ? 0.035 : 0))
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.06 : 1))
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct SqueezeButtonGlassSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool
    let isHovered: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        // Neue SDK-Symbole nicht typechecken lassen, wenn das
        // Package noch mit Swift Playgrounds und einem älteren SDK gebaut wird.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(
                        isSelected
                            ? Color.blue.opacity(0.22)
                            : (isHovered ? Color.blue.opacity(0.12) : Color.clear)
                    ).interactive(),
                    in: Circle()
                )
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    if isSelected {
                        Circle().fill(Color.blue.opacity(0.20))
                    } else if isHovered {
                        Circle().fill(Color.blue.opacity(0.12))
                    }
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.25 : 0.58),
                                Color.white.opacity(0.05),
                                Color.black.opacity(0.04),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.85), .white.opacity(0.12), .white.opacity(0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
    }
}
