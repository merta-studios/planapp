import SwiftUI

/// Farbauswahl-Leiste mit vordefinierten Schulfach-Farben und Custom-Farbwähler
public struct ColorPickerPresets: View {
    @Binding public var selectedHex: String

    public let presetColors: [(name: String, hex: String)] = [
        ("Klassisch Blau", "#3B82F6"),
        ("Smaragd Grün", "#10B981"),
        ("Feuer Rot", "#EF4444"),
        ("Sonnen Gelb", "#F59E0B"),
        ("Königs Lila", "#8B5CF6"),
        ("Magenta Pink", "#EC4899"),
        ("Ozean Cyan", "#06B6D4"),
        ("Indigo", "#6366F1"),
        ("Teal / Mint", "#14B8A6"),
        ("Waldgrün", "#059669"),
        ("Kupfer Braun", "#B45309"),
        ("Schiefer Grau", "#64748B"),
        ("Koralle Orange", "#F97316")
    ]

    public init(selectedHex: Binding<String>) {
        self._selectedHex = selectedHex
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fach-Farbe wählen:")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetColors, id: \.hex) { preset in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedHex = preset.hex
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 34, height: 34)

                                if selectedHex.uppercased() == preset.hex.uppercased() {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2.5)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .regular, design: .default))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .hoverEffect(.lift)
                    }

                    // System ColorPicker Ergänzung
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: selectedHex) },
                        set: { newColor in selectedHex = newColor.toHex() }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 34, height: 34)
                    .hoverEffect(.lift)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }
}
