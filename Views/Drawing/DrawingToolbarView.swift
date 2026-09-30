import SwiftUI
import PencilKit

/// Vorgegebene Werkzeugleiste für den Notizzettel (Stift, Textmarker, Radierer, Undo/Redo)
public struct DrawingToolbarView: View {
    @Binding public var toolSelection: DrawingToolSelection
    public let onUndo: () -> Void
    public let onRedo: () -> Void
    public let onClear: () -> Void

    // Vordefinierte Farben für Stift (nur Schwarz, Rot, Blau, Grün)
    public let penColors: [(name: String, color: UIColor, swiftColor: Color)] = [
        ("Schwarz", .black, .black),
        ("Rot", UIColor(red: 0.88, green: 0.15, blue: 0.15, alpha: 1.0), .red),
        ("Blau", UIColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 1.0), .blue),
        ("Grün", UIColor(red: 0.12, green: 0.65, blue: 0.25, alpha: 1.0), .green)
    ]

    // Vordefinierte Farben für Textmarker (nur Gelb, Orange, Grün, Blau, Lila)
    public let markerColors: [(name: String, color: UIColor, swiftColor: Color)] = [
        ("Gelb", UIColor(red: 1.0, green: 0.90, blue: 0.20, alpha: 0.60), Color(red: 1.0, green: 0.90, blue: 0.20)),
        ("Orange", UIColor(red: 1.0, green: 0.58, blue: 0.15, alpha: 0.60), .orange),
        ("Grün", UIColor(red: 0.25, green: 0.85, blue: 0.35, alpha: 0.60), Color(red: 0.25, green: 0.85, blue: 0.35)),
        ("Blau", UIColor(red: 0.20, green: 0.65, blue: 1.0, alpha: 0.60), Color(red: 0.20, green: 0.65, blue: 1.0)),
        ("Lila", UIColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.60), .purple)
    ]

    public init(
        toolSelection: Binding<DrawingToolSelection>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self._toolSelection = toolSelection
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: 16) {
            // 1. STIFT (Buntstift) mit Farben
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                ForEach(penColors, id: \.name) { item in
                    let isSelected: Bool = {
                        if case .pen(let c) = toolSelection {
                            return c == item.color
                        }
                        return false
                    }()

                    Button(action: {
                        toolSelection = .pen(color: item.color)
                    }) {
                        ZStack {
                            Circle()
                                .fill(item.swiftColor)
                                .frame(width: 28, height: 28)
                                .shadow(color: item.swiftColor.opacity(0.3), radius: 2, x: 0, y: 1)

                            if isSelected {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2.5)
                                    .frame(width: 28, height: 28)
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(Capsule())

            Divider()
                .frame(height: 24)

            // 2. TEXTMARKER mit Farben
            HStack(spacing: 8) {
                Image(systemName: "highlighter")
                    .font(.system(size: 15, weight: .bold))
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
                            RoundedRectangle(cornerRadius: 6)
                                .fill(item.swiftColor)
                                .frame(width: 26, height: 26)

                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.primary, lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(Capsule())

            Divider()
                .frame(height: 24)

            // 3. RADIERER
            let isEraserSelected: Bool = {
                if case .eraser = toolSelection { return true }
                return false
            }()

            Button(action: {
                toolSelection = .eraser
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Radierer")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isEraserSelected ? Color.blue : Color(UIColor.tertiarySystemBackground))
                .foregroundColor(isEraserSelected ? .white : .primary)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .hoverEffect(.lift)

            Divider()
                .frame(height: 24)

            // 4. RÜCKGÄNGIG & VORWÄRTS
            HStack(spacing: 6) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
                .accessibilityLabel("Rückgängig")

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
                .accessibilityLabel("Wiederholen")
            }

            Divider()
                .frame(height: 24)

            // 5. ZETTEL LEEREN
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: 34, height: 34)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .hoverEffect(.lift)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
        )
    }
}
