import SwiftUI

/// Einstellungsbereich für die Zeichenfläche: Standard-Dicken, Standard-Größe,
/// Standard-Werkzeug samt Farbe sowie das Verwalten aller Notizen.
public struct DrawingSettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var showDeleteAllNotesAlert = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Abschnittsüberschrift
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Zeichenfläche & Notizen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            // 1. STANDARD-DICKEN
            VStack(alignment: .leading, spacing: 14) {
                thicknessSlider(
                    title: "Standard-Dicke Stift",
                    systemImage: "pencil.tip",
                    value: binding(\.penWidth),
                    range: 1...20
                )

                thicknessSlider(
                    title: "Standard-Dicke Textmarker",
                    systemImage: "highlighter",
                    value: binding(\.markerWidth),
                    range: 4...40
                )

                thicknessSlider(
                    title: "Standard-Dicke Radierer",
                    systemImage: "eraser",
                    value: binding(\.eraserWidth),
                    range: 4...60
                )
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 2. STANDARD-GRÖSSE DER ZEICHENFLÄCHE
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.expand.vertical")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Standard-Größe der Zeichenfläche")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer()
                    Text("\(Int(viewModel.drawingSettings.defaultCanvasHeight)) pt")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Slider(value: binding(\.defaultCanvasHeight), in: 280...656, step: 4)

                Text("Höhe, mit der die Zeichenfläche beim neuen Öffnen einer Notiz startet.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 3. STANDARD-WERKZEUG & FARBE
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Standard-Werkzeug beim Öffnen")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }

                Picker("Standard-Werkzeug", selection: binding(\.defaultTool)) {
                    ForEach(DefaultDrawingTool.allCases) { tool in
                        Label(tool.displayName, systemImage: tool.systemImage)
                            .tag(tool)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.drawingSettings.defaultTool == .pen {
                    defaultColorRow(
                        title: "Standard-Farbe Stift:",
                        palette: DrawingPalette.penColors,
                        selectedHex: binding(\.defaultPenColorHex)
                    )
                } else if viewModel.drawingSettings.defaultTool == .marker {
                    defaultColorRow(
                        title: "Standard-Farbe Textmarker:",
                        palette: DrawingPalette.markerColors,
                        selectedHex: binding(\.defaultMarkerColorHex)
                    )
                }
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 4. AUTOMATISCHES AUFRÄUMEN & ALLES LÖSCHEN
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { viewModel.drawingSettings.autoDeletePastNotes },
                    set: { newValue in
                        viewModel.drawingSettings.autoDeletePastNotes = newValue
                        viewModel.saveDrawingSettings()
                        if newValue {
                            viewModel.cleanupPastNotesIfEnabled()
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alte Notizen automatisch löschen")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Notizen zu Stunden, die in der Vergangenheit liegen, werden automatisch entfernt.")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                Button(action: {
                    showDeleteAllNotesAlert = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Alle Notizen zu Stunden-Blöcken löschen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .lightButton(cornerRadius: 12, tint: .red)
                .foregroundColor(.red)
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .alert("Alle Notizen löschen", isPresented: $showDeleteAllNotesAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Alle löschen", role: .destructive) {
                Haptics.warning()
                withAnimation {
                    viewModel.deleteAllNotes()
                }
            }
        } message: {
            Text("Möchtest du wirklich alle handschriftlichen Notizen und Textfelder zu sämtlichen Stunden unwiderruflich löschen?")
        }
    }

    // MARK: - Hilfselemente

    /// Binding auf ein Feld der DrawingSettings, das Änderungen sofort speichert.
    private func binding<T>(_ keyPath: WritableKeyPath<DrawingSettings, T>) -> Binding<T> {
        Binding(
            get: { viewModel.drawingSettings[keyPath: keyPath] },
            set: { newValue in
                viewModel.drawingSettings[keyPath: keyPath] = newValue
                viewModel.saveDrawingSettings()
            }
        )
    }

    private func thicknessSlider(
        title: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .default))
                Spacer()
                Text(String(format: "%.1f pt", value.wrappedValue))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Slider(value: value, in: range, step: 0.5)
        }
    }

    private func defaultColorRow(
        title: String,
        palette: [DrawingPalette.PaletteColor],
        selectedHex: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(palette, id: \.hex) { item in
                    let isSelected = selectedHex.wrappedValue.caseInsensitiveCompare(item.hex) == .orderedSame

                    Button {
                        Haptics.select()
                        selectedHex.wrappedValue = item.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: item.uiColor.withAlphaComponent(1)))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )

                            if isSelected {
                                Circle()
                                    .strokeBorder(Color.blue, lineWidth: 2.5)
                                    .frame(width: 38, height: 38)
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                    .accessibilityLabel(item.name)
                    .accessibilityValue(isSelected ? "Ausgewählt" : "")
                }

                Spacer()
            }
        }
    }
}
