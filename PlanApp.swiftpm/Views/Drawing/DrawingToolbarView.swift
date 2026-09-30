import SwiftUI
import PencilKit

/// Always-visible, horizontally scrollable drawing controls. The toolbar is
/// deliberately independent from the editor card so moving or scaling the note
/// never moves the tools off-screen.
public struct DrawingToolbarView: View {
    @Binding public var toolSelection: DrawingToolSelection
    @Binding public var penWidth: CGFloat

    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onClear: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showThicknessSlider = false

    public let penColors: [(name: String, color: UIColor, lightColor: Color, darkColor: Color)] = [
        ("Schwarz", .black, .black, .white),
        ("Rot", UIColor(red: 0.88, green: 0.15, blue: 0.15, alpha: 1), .red, .red),
        ("Blau", UIColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 1), .blue, .blue),
        ("Grün", UIColor(red: 0.12, green: 0.65, blue: 0.25, alpha: 1), .green, .green)
    ]

    public let markerColors: [(name: String, color: UIColor, swiftColor: Color)] = [
        ("Gelb", UIColor(red: 1, green: 0.90, blue: 0.20, alpha: 0.60), Color(red: 1, green: 0.90, blue: 0.20)),
        ("Orange", UIColor(red: 1, green: 0.58, blue: 0.15, alpha: 0.60), .orange),
        ("Grün", UIColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.60), Color(red: 0.25, green: 0.85, blue: 0.35)),
        ("Blau", UIColor(red: 0.20, green: 0.65, blue: 1, alpha: 0.60), Color(red: 0.20, green: 0.65, blue: 1)),
        ("Lila", UIColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.60), .purple)
    ]

    public init(
        toolSelection: Binding<DrawingToolSelection>,
        penWidth: Binding<CGFloat>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        _toolSelection = toolSelection
        _penWidth = penWidth
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClear = onClear
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                penControls

                if showThicknessSlider {
                    thicknessControls
                        .transition(.scale.combined(with: .opacity))
                }

                toolbarDivider
                markerControls
                toolbarDivider
                eraserButton
                toolbarDivider
                historyControls
                toolbarDivider
                clearButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(Capsule().fill(.ultraThinMaterial))
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
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeichenwerkzeuge")
    }

    private var penControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.tip")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .accessibilityHidden(true)

            ForEach(penColors, id: \.name) { item in
                let isSelected: Bool = {
                    if case .pen(let selectedColor) = toolSelection {
                        return selectedColor == item.color
                    }
                    return false
                }()
                let swatch = colorScheme == .dark ? item.darkColor : item.lightColor

                Button {
                    toolSelection = .pen(color: item.color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(swatch)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            )

                        if isSelected {
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: 2)
                                .frame(width: 27, height: 27)
                        }
                    }
                    .frame(width: 29, height: 29)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Stift \(item.name)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                    showThicknessSlider.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(Color.primary)
                        .frame(
                            width: max(2, min(14, penWidth * 1.5)),
                            height: max(2, min(14, penWidth * 1.5))
                        )
                }
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("Strichstärke")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
        .clipShape(Capsule())
    }

    private var thicknessControls: some View {
        HStack(spacing: 7) {
            Text("Dicke")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Slider(value: $penWidth, in: 1...14, step: 0.5)
                .frame(width: 100)

            Text(String(format: "%.1f", penWidth))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.88))
        .clipShape(Capsule())
    }

    private var markerControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "highlighter")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .accessibilityHidden(true)

            ForEach(markerColors, id: \.name) { item in
                let isSelected: Bool = {
                    if case .marker(let selectedColor) = toolSelection {
                        return selectedColor == item.color
                    }
                    return false
                }()

                Button {
                    toolSelection = .marker(color: item.color)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.swiftColor)
                            .frame(width: 21, height: 21)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary, lineWidth: 2)
                                .frame(width: 27, height: 27)
                        }
                    }
                    .frame(width: 29, height: 29)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Textmarker \(item.name)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
        .clipShape(Capsule())
    }

    private var eraserButton: some View {
        let isSelected: Bool = {
            if case .eraser = toolSelection { return true }
            return false
        }()

        return Button {
            toolSelection = .eraser
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "eraser")
                    .font(.system(size: 13))
                Text("Radierer")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemBackground).opacity(0.72))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    private var historyControls: some View {
        HStack(spacing: 5) {
            roundButton(
                systemName: "arrow.uturn.backward",
                accessibilityLabel: "Rückgängig",
                action: onUndo
            )
            roundButton(
                systemName: "arrow.uturn.forward",
                accessibilityLabel: "Wiederholen",
                action: onRedo
            )
        }
    }

    private var clearButton: some View {
        Button(action: onClear) {
            Image(systemName: "trash")
                .font(.system(size: 13))
                .foregroundColor(.red)
                .frame(width: 31, height: 31)
                .background(Color.red.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel("Zeichnung leeren")
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 20)
    }

    private func roundButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .frame(width: 31, height: 31)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }
}
