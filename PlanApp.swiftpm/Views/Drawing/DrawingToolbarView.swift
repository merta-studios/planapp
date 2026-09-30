import SwiftUI
import PencilKit

/// Vorgegebene Werkzeugleiste für den Notizzettel (Stift, Textmarker, Standard-Radierer, Dicke-Slider, Undo/Redo)
public struct DrawingToolbarView: View {
    @Binding public var toolSelection: DrawingToolSelection
    @Binding public var penWidth: CGFloat

    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onClear: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showThicknessSlider: Bool = false

    // Vordefinierte Farben für Stift (Schwarz wird im Dark Mode dynamisch weiß)
    public let penColors: [(name: String, color: UIColor, lightColor: Color, darkColor: Color)] = [
        ("Schwarz", .black, .black, .white),
        ("Rot", UIColor(red: 0.88, green: 0.15, blue: 0.15, alpha: 1.0), .red, .red),
        ("Blau", UIColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 1.0), .blue, .blue),
        ("Grün", UIColor(red: 0.12, green: 0.65, blue: 0.25, alpha: 1.0), .green, .green)
    ]

    // Vordefinierte Farben für Textmarker
    public let markerColors: [(name: String, color: UIColor, swiftColor: Color)] = [
        ("Gelb", UIColor(red: 1.0, green: 0.90, blue: 0.20, alpha: 0.60), Color(red: 1.0, green: 0.90, blue: 0.20)),
        ("Orange", UIColor(red: 1.0, green: 0.58, blue: 0.15, alpha: 0.60), .orange),
        ("Grün", UIColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.60), Color(red: 0.25, green: 0.85, blue: 0.35)),
        ("Blau", UIColor(red: 0.20, green: 0.65, blue: 1.0, alpha: 0.60), Color(red: 0.20, green: 0.65, blue: 1.0)),
        ("Lila", UIColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.60), .purple)
    ]

    public init(
        toolSelection: Binding<DrawingToolSelection>,
        penWidth: Binding<CGFloat>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self._toolSelection = toolSelection
        self._penWidth = penWidth
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 1. STIFT (Apple Standard-Stift mit Druckerkennung)
            HStack(spacing: 6) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.primary)

                ForEach(penColors, id: \.name) { item in
                    let isSelected: Bool = {
                        if case .pen(let c) = toolSelection {
                            return c == item.color
                        }
                        return false
                    }()
                    let swatchColor = (colorScheme == .dark ? item.darkColor : item.lightColor)

                    Button(action: {
                        toolSelection = .pen(color: item.color)
                    }) {
                        ZStack {
                            Circle()
                                .fill(swatchColor)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                )

                            if isSelected {
                                Circle()
                                    .strokeBorder(Color.blue, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                }

                // Strichstärke-Anzeige / Slider-Umschalter
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        showThicknessSlider.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 24, height: 24)

                        Circle()
                            .fill(Color.primary)
                            .frame(width: max(2, min(14, penWidth * 1.5)), height: max(2, min(14, penWidth * 1.5)))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground).opacity(0.7))
            .clipShape(Capsule())

            // Ausklappbarer Dicke-Slider
            if showThicknessSlider {
                HStack(spacing: 6) {
                    Text("Dicke:")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)

                    Slider(value: $penWidth, in: 1.0...14.0, step: 0.5)
                        .frame(width: 90)

                    Text(String(format: "%.1f", penWidth))
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.85))
                .clipShape(Capsule())
                .transition(.scale.combined(with: .opacity))
            }

            Divider()
                .frame(height: 18)

            // 2. TEXTMARKER mit Farben
            HStack(spacing: 6) {
                Image(systemName: "highlighter")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.primary)

                ForEach(markerColors, id: \.name) { item in
                    let isSelected: Bool = {
                        if case .marker(let c) = toolSelection {
                            return c == item.color
                        }
                        return false
                    }()

                    Button(action: {
                        toolSelection = .marker(color: item.color)
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.swiftColor)
                                .frame(width: 20, height: 20)

                            if isSelected {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.primary, lineWidth: 1.5)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground).opacity(0.7))
            .clipShape(Capsule())

            Divider()
                .frame(height: 18)

            // 3. STANDARD-RADIERER (Bitmap / Pixel-Radierer)
            let isEraserSelected: Bool = {
                if case .eraser = toolSelection { return true }
                return false
            }()

            Button(action: {
                toolSelection = .eraser
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "eraser")
                        .font(.system(size: 13, weight: .regular, design: .default))
                    Text("Radierer")
                        .font(.system(size: 12, weight: .regular, design: .default))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isEraserSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.7))
                .foregroundColor(isEraserSelected ? .white : .primary)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .hoverEffect(.lift)

            Divider()
                .frame(height: 18)

            // 4. RÜCKGÄNGIG & VORWÄRTS
            HStack(spacing: 4) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .frame(width: 28, height: 28)
                        .background(Color(UIColor.tertiarySystemBackground).opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .frame(width: 28, height: 28)
                        .background(Color(UIColor.tertiarySystemBackground).opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }

            Divider()
                .frame(height: 18)

            // 5. ZETTEL LEEREN
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .hoverEffect(.lift)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
