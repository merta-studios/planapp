import SwiftUI
import UIKit

/// The drawing tool currently selected in the custom PencilKit toolbar.
///
/// This is deliberately kept separate from `PKTool`: the toolbar needs to
/// retain the selected color and width while the canvas wrapper translates it
/// into a PencilKit tool. `.text` switches the canvas into the text-field
/// mode in which tapping creates movable text boxes instead of drawing.
public enum DrawingToolSelection: Equatable {
    case pen(color: UIColor)
    case marker(color: UIColor)
    case eraser
    case lasso
    case text
}

/// Farb-Definition für die Farb-Palette
public struct DrawingPalettePreset: Identifiable, Equatable {
    public let id: String
    public let hex: String
    public let name: String

    public init(hex: String, name: String) {
        self.id = hex
        self.hex = hex
        self.name = name
    }
}

/// Die exakte Farb-Palette mit 3 Zeilen und 8 Spalten
public enum DrawingPaletteGrid {
    /// 1. Reihe (Helle / Leuchtende Töne)
    public static let row1: [DrawingPalettePreset] = [
        DrawingPalettePreset(hex: "#FF4D4D", name: "Hellrot / Koralle"),
        DrawingPalettePreset(hex: "#FF8C24", name: "Helles Orange"),
        DrawingPalettePreset(hex: "#FFD000", name: "Sattes Gelb"),
        DrawingPalettePreset(hex: "#4CD948", name: "Leuchtendes Hellgrün"),
        DrawingPalettePreset(hex: "#4CA6FF", name: "Himmelsblau"),
        DrawingPalettePreset(hex: "#3CBCE1", name: "Türkisblau"),
        DrawingPalettePreset(hex: "#B388FF", name: "Flieder / Hellviolett"),
        DrawingPalettePreset(hex: "#F062B2", name: "Pink / Rosarot")
    ]

    /// 2. Reihe (Dunkle / Gesättigte Töne)
    public static let row2: [DrawingPalettePreset] = [
        DrawingPalettePreset(hex: "#A32020", name: "Weinrot / Dunkelrot"),
        DrawingPalettePreset(hex: "#A3411A", name: "Rostbraun"),
        DrawingPalettePreset(hex: "#996900", name: "Senfgelb / Ockerbraun"),
        DrawingPalettePreset(hex: "#0B7A1C", name: "Waldgrün"),
        DrawingPalettePreset(hex: "#00627C", name: "Teal / Petroleumblau"),
        DrawingPalettePreset(hex: "#2B58BA", name: "Königsblau / Marine"),
        DrawingPalettePreset(hex: "#6531A3", name: "Lila"),
        DrawingPalettePreset(hex: "#8C2763", name: "Bordeaux / Purpur")
    ]

    /// 3. Reihe (Achromatische Töne)
    public static let row3: [DrawingPalettePreset] = [
        DrawingPalettePreset(hex: "#FFFFFF", name: "Reinweiß"),
        DrawingPalettePreset(hex: "#E5E5E5", name: "Sehr helles Grau"),
        DrawingPalettePreset(hex: "#9E9E9E", name: "Neutrales Grau"),
        DrawingPalettePreset(hex: "#545454", name: "Anthrazit / Dunkelgrau"),
        DrawingPalettePreset(hex: "#1E1E1E", name: "Schwarz")
    ]
}

/// Farbpalette in einem hellgrauen, abgerundeten Bedienfeld (3 Zeilen × 8 Spalten)
public struct DrawingColorPalettePopover: View {
    /// Feste Abmessungen der 8×3-Farbpalette einschließlich Innenabstand.
    /// Werkzeug-Hinweise verwenden dieselbe Größe, damit die Popovers einheitlich sind.
    static let popoverSize = CGSize(width: 388, height: 158)

    public let selectedHex: String
    public let onSelectColor: (String) -> Void
    public let onSelectCustomColor: (String) -> Void

    private let buttonDiameter: CGFloat = 32
    private let spacing: CGFloat = 8

    public init(
        selectedHex: String,
        onSelectColor: @escaping (String) -> Void,
        onSelectCustomColor: ((String) -> Void)? = nil
    ) {
        self.selectedHex = selectedHex
        self.onSelectColor = onSelectColor
        self.onSelectCustomColor = onSelectCustomColor ?? onSelectColor
    }

    public var body: some View {
        VStack(spacing: spacing) {
            // 1. Reihe
            HStack(spacing: spacing) {
                ForEach(DrawingPaletteGrid.row1) { item in
                    colorButton(item)
                }
            }

            // 2. Reihe
            HStack(spacing: spacing) {
                ForEach(DrawingPaletteGrid.row2) { item in
                    colorButton(item)
                }
            }

            // 3. Reihe (5 achromatische Farben + Plus/Regenbogen + 2 Platzhalter für 8 Spalten)
            HStack(spacing: spacing) {
                ForEach(DrawingPaletteGrid.row3) { item in
                    colorButton(item)
                }

                plusRainbowButton

                // 2 leere Platzhalter für exakte 8-Spalten-Ausrichtung
                Color.clear
                    .frame(width: buttonDiameter, height: buttonDiameter)
                Color.clear
                    .frame(width: buttonDiameter, height: buttonDiameter)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        .fixedSize()
    }

    private func colorButton(_ item: DrawingPalettePreset) -> some View {
        let isSelected = selectedHex.caseInsensitiveCompare(item.hex) == .orderedSame
        let color = Color(hex: item.hex)
        let isWhite = item.hex.caseInsensitiveCompare("#FFFFFF") == .orderedSame

        return Button {
            Haptics.select()
            onSelectColor(item.hex)
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: buttonDiameter, height: buttonDiameter)

                if isWhite {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.35), lineWidth: 1)
                        .frame(width: buttonDiameter, height: buttonDiameter)
                        .shadow(color: Color.black.opacity(0.08), radius: 1.5, x: 0, y: 1)
                }

                if isSelected {
                    // Häkchen-Icon als Auswahlanzeige
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color.contrastingTextColor)
                        .shadow(
                            color: color.contrastingTextColor == .white ? Color.black.opacity(0.5) : Color.clear,
                            radius: 1,
                            x: 0,
                            y: 0.5
                        )

                    Circle()
                        .strokeBorder(Color.blue, lineWidth: 2.5)
                        .frame(width: buttonDiameter + 6, height: buttonDiameter + 6)
                }
            }
            .frame(width: buttonDiameter + 6, height: buttonDiameter + 6)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }

    private var plusRainbowButton: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.2, blue: 0.2),
                            Color(red: 1.0, green: 0.6, blue: 0.1),
                            Color(red: 1.0, green: 0.9, blue: 0.0),
                            Color(red: 0.2, green: 0.85, blue: 0.3),
                            Color(red: 0.2, green: 0.65, blue: 1.0),
                            Color(red: 0.6, green: 0.35, blue: 1.0),
                            Color(red: 0.95, green: 0.3, blue: 0.7),
                            Color(red: 1.0, green: 0.2, blue: 0.2)
                        ]),
                        center: .center
                    )
                )
                .frame(width: buttonDiameter, height: buttonDiameter)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.55), radius: 1.5, x: 0, y: 1)
                )
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )

            // Apples Standard-Farbwähler als echter UIKit-Launcher. Dadurch
            // funktioniert der Custom Picker zuverlässig auch innerhalb des Popovers
            // und schließt die Palette nicht bei jeder Live-Farbänderung.
            SystemColorPickerButton(
                selectedHex: selectedHex,
                onColorChange: { newHex in
                    onSelectCustomColor(newHex)
                }
            )
            .frame(width: buttonDiameter + 6, height: buttonDiameter + 6)
        }
        .frame(width: buttonDiameter + 6, height: buttonDiameter + 6)
        .hoverEffect(.lift)
        .accessibilityLabel("Eigene Farbe wählen")
    }
}

private struct SystemColorPickerButton: UIViewRepresentable {
    let selectedHex: String
    let onColorChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.accessibilityLabel = "Eigene Farbe wählen"
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.openColorPicker(_:)),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var parent: SystemColorPickerButton
        weak var picker: UIColorPickerViewController?

        init(_ parent: SystemColorPickerButton) {
            self.parent = parent
        }

        @objc func openColorPicker(_ sender: UIButton) {
            guard picker == nil else { return }
            guard var presenter = sender.closestViewController else { return }
            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            Haptics.tap()
            let picker = UIColorPickerViewController()
            picker.delegate = self
            picker.supportsAlpha = false
            picker.selectedColor = UIColor(hex: parent.selectedHex)
            picker.presentationController?.delegate = self
            self.picker = picker
            presenter.present(picker, animated: true)
        }

        func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
            parent.onColorChange(viewController.selectedColor.toHex())
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            parent.onColorChange(viewController.selectedColor.toHex())
            picker = nil
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            picker = nil
        }
    }
}

private extension UIView {
    var closestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
