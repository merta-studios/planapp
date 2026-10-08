import SwiftUI

/// Einstellungsbereich für Zeichenfläche und Notizen: Standard-Dicken, Größen
/// für Zeichenfläche und Textfelder sowie das Verwalten aller Notizen.
public struct DrawingSettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var showDeleteAllNotesAlert = false
    /// Lokaler Entwurf für Slider-Werte. Während des Ziehens wird dadurch nicht
    /// der komplette Stundenplan über `@Published` neu aufgebaut; gespeichert
    /// wird erst beim Loslassen bzw. beim Schließen der Einstellungen.
    @State private var draftSettings: DrawingSettings = .default
    @State private var didLoadDraft = false

    /// iPhone: ohne Apple Pencil gibt es weder Stift/Textmarker noch
    /// Pencil-Optionen – diese Einstellungen werden dort ausgeblendet.
    private let isPhone = DeviceLayout.isPhone

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
                if !isPhone {
                    thicknessSlider(
                        title: "Standard-Dicke Stift",
                        systemImage: "pencil.tip",
                        value: draftBinding(\.penWidth),
                        range: 1...20
                    )

                    thicknessSlider(
                        title: "Standard-Dicke Textmarker",
                        systemImage: "highlighter",
                        value: draftBinding(\.markerWidth),
                        range: 4...40
                    )
                }

                thicknessSlider(
                    title: "Standard-Dicke Radierer",
                    systemImage: "eraser",
                    value: draftBinding(\.eraserWidth),
                    range: 4...60
                )
            }
            .padding(DeviceLayout.settingsInnerPadding)
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
                    Text("\(Int(draftSettings.defaultCanvasHeight)) pt")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: draftBinding(\.defaultCanvasHeight),
                    in: 280...656,
                    step: 4,
                    onEditingChanged: handleSliderEditingChanged
                )

                Text("Höhe, mit der die Zeichenfläche beim neuen Öffnen einer Notiz startet.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 3. STANDARD-SCHRIFTGRÖSSE NEUER TEXTFELDER
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Standard-Schriftgröße für Textfelder")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer(minLength: 8)
                    Text("\(Int(draftSettings.defaultTextFontSize)) pt")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: draftBinding(\.defaultTextFontSize),
                    in: NoteTextBox.minimumFontSize...NoteTextBox.maximumFontSize,
                    step: 1,
                    onEditingChanged: handleSliderEditingChanged
                )

                Text("Neue Textfelder starten mit dieser Größe. Bereits erstellte Textfelder bleiben unverändert und lassen sich einzeln anpassen.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Beispieltext")
                    .font(draftSettings.textFontStyle.font(size: CGFloat(draftSettings.defaultTextFontSize)))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 3b. SCHRIFTART DER TEXTFELDER
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "textformat")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Schriftart für Textfelder")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer(minLength: 8)
                }

                Picker("Schriftart", selection: Binding(
                    get: { draftSettings.textFontStyle },
                    set: { newValue in
                        draftSettings.textFontStyle = newValue
                        commitDraftSettings()
                    }
                )) {
                    ForEach(NoteTextFontStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    Text(draftSettings.textFontStyle.previewText)
                        .font(draftSettings.textFontStyle.font(size: 19))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(draftSettings.textFontStyle.subtitle)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )

                Text("Gilt für alle Textfelder auf der Zeichenfläche – vorhandene und neue. Handschriftliche Pencil-Striche bleiben unverändert.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 4. STANDARD-HINTERGRUND
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Standard-Hintergrund")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer()
                    Text(draftSettings.defaultBackgroundStyle.title)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }

                Picker("Standard-Hintergrund", selection: Binding(
                    get: { draftSettings.defaultBackgroundStyle },
                    set: { newValue in
                        draftSettings.defaultBackgroundStyle = newValue
                        commitDraftSettings()
                    }
                )) {
                    ForEach(NoteBackgroundStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text("Neue Notizen starten mit diesem Hintergrund. Pro Notiz kannst du ihn im Drei-Punkte-Menü ändern.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Standard-Mustergröße")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer()
                    Text(String(format: "%.0f %%", draftSettings.defaultBackgroundScale * 100))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { NoteBackgroundMetrics.sliderValue(forScale: draftSettings.defaultBackgroundScale) },
                            set: { draftSettings.defaultBackgroundScale = NoteBackgroundMetrics.scale(forSliderValue: $0) }
                        ),
                        in: -1...1,
                        onEditingChanged: handleSliderEditingChanged
                    )
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                DrawingCanvasBackgroundView(
                    style: draftSettings.defaultBackgroundStyle == .blank ? .grid : draftSettings.defaultBackgroundStyle,
                    scale: draftSettings.defaultBackgroundScale
                )
                .frame(height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )

                Text("Größe von Linien, Kästchen und Punkten, mit der neue Notizen starten. Die Mitte ist die normale Größe; pro Notiz lässt sich die Größe im Drei-Punkte-Menü unter „Mustergröße“ anpassen.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 5. EINGABE & RADIERER
            VStack(alignment: .leading, spacing: 12) {
                if !isPhone {
                    Toggle(isOn: Binding(
                        get: { draftSettings.applePencilOnly },
                        set: { newValue in
                            draftSettings.applePencilOnly = newValue
                            commitDraftSettings()
                        }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Pencil")
                                    .font(.system(size: 14, weight: .regular, design: .default))
                                Text("Aus: Zeichnen mit Finger und Apple Pencil. An: Nur mit dem Apple Pencil zeichnen – der Finger fasst dafür Text und Bilder an (auswählen, verschieben, bearbeiten), egal welches Werkzeug gewählt ist. Schaltet sich automatisch ein, sobald ein Apple Pencil erkannt wird.")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Divider()

                    Toggle(isOn: Binding(
                        get: { draftSettings.dynamicPenWidth },
                        set: { newValue in
                            draftSettings.dynamicPenWidth = newValue
                            commitDraftSettings()
                        }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "scribble.variable")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dynamische Stiftdicke")
                                    .font(.system(size: 14, weight: .regular, design: .default))
                                Text("An: Der Stift reagiert wie der PencilKit-Füller auf Druck und Geschwindigkeit. Aus: Kugelschreiber – jeder Strich ist exakt gleich dick.")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                }

                Toggle(isOn: Binding(
                    get: { draftSettings.autoDeselectEraser },
                    set: { newValue in
                        draftSettings.autoDeselectEraser = newValue
                        commitDraftSettings()
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "eraser")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Radierer automatisch abwählen")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Sobald du radiert hast und den Stift loslässt, wechselt das Werkzeug automatisch zum zuletzt benutzten Werkzeug – Fallback: Stift.")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 6. AUTOMATISCHES AUFRÄUMEN & ALLES LÖSCHEN
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { draftSettings.autoDeletePastNotes },
                    set: { newValue in
                        draftSettings.autoDeletePastNotes = newValue
                        commitDraftSettings()
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
                    Haptics.warning()
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
            .padding(DeviceLayout.settingsInnerPadding)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .onAppear(perform: loadDraftIfNeeded)
        .onDisappear(perform: commitDraftSettings)
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

    private func loadDraftIfNeeded() {
        guard !didLoadDraft else { return }
        draftSettings = viewModel.drawingSettings
        didLoadDraft = true
    }

    private func commitDraftSettings() {
        guard didLoadDraft, viewModel.drawingSettings != draftSettings else { return }
        viewModel.drawingSettings = draftSettings
        viewModel.saveDrawingSettings()
    }

    /// Binding auf ein Feld des lokalen Entwurfs. Dadurch bleiben Slider flüssig
    /// und schreiben nicht bei jedem einzelnen Drag-Pixel in `UserDefaults`.
    private func draftBinding<T>(_ keyPath: WritableKeyPath<DrawingSettings, T>) -> Binding<T> {
        Binding(
            get: { draftSettings[keyPath: keyPath] },
            set: { newValue in
                draftSettings[keyPath: keyPath] = newValue
            }
        )
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if !isEditing {
            commitDraftSettings()
        }
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

            Slider(
                value: value,
                in: range,
                step: 0.5,
                onEditingChanged: handleSliderEditingChanged
            )
        }
    }
}
