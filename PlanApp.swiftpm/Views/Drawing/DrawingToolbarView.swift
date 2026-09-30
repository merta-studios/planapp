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
            HStack(spacing: 8) {
                penControls
                toolbarDivider
                markerControls
                toolbarDivider
                thicknessButton
                toolbarDivider
                eraserButton
                toolbarDivider
                historyControls
                toolbarDivider
                clearButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeichenwerkzeuge")
    }

    private var penControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.tip")
                .font(.system(size: 13))
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
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            )

                        if isSelected {
                            Circle()
                                .strokeBorder(Color.blue, lineWidth: 2)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .frame(width: 27, height: 27)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Stift \(item.name)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
        .clipShape(Capsule())
    }

    /// General stroke-thickness control. It applies to every tool (pen and
    /// marker), which is why it lives on its own, right before the eraser,
    /// instead of being nested inside the pen's color group.
    private var thicknessButton: some View {
        Button {
            showThicknessSlider = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 27, height: 27)
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
        .popover(isPresented: $showThicknessSlider, arrowEdge: .bottom) {
            VerticalThicknessSlider(penWidth: $penWidth, previewColor: currentToolPreviewColor)
                .frame(width: 110, height: 260)
                .presentationCompactAdaptation(.popover)
        }
    }

    /// The color used for the live thickness preview, matching whichever tool
    /// is currently selected.
    private var currentToolPreviewColor: Color {
        switch toolSelection {
        case .pen(let color):
            return colorScheme == .dark && color == .black ? .white : Color(uiColor: color)
        case .marker(let color):
            return Color(uiColor: color)
        case .eraser:
            return Color(UIColor.systemGray2)
        }
    }

    private var markerControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "highlighter")
                .font(.system(size: 13))
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
                            .frame(width: 19, height: 19)

                        if isSelected {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.primary, lineWidth: 2)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .frame(width: 27, height: 27)
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel("Textmarker \(item.name)")
                .accessibilityValue(isSelected ? "Ausgewählt" : "")
            }
        }
        .padding(.horizontal, 7)
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
            .padding(.horizontal, 9)
            .frame(height: 29)
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
                .frame(width: 29, height: 29)
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
                .frame(width: 29, height: 29)
                .background(Color(UIColor.tertiarySystemBackground).opacity(0.72))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Vertical (up/down) thickness slider shown in a popover above the toolbar's
/// thickness button. A live-updating circle previews exactly how thick the
/// current tool's stroke would be at the selected width.
private struct VerticalThicknessSlider: View {
    @Binding var penWidth: CGFloat
    let previewColor: Color

    private var previewDiameter: CGFloat {
        max(6, min(52, penWidth * 3.4))
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Dicke")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 56, height: 56)
                Circle()
                    .fill(previewColor)
                    .frame(width: previewDiameter, height: previewDiameter)
            }
            .frame(height: 60)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: penWidth)

            Slider(value: $penWidth, in: 1...20, step: 0.5)
                .frame(width: 150)
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: 150)

            Text(String(format: "%.1f pt", penWidth))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 18)
        .frame(maxHeight: .infinity)
    }
}
