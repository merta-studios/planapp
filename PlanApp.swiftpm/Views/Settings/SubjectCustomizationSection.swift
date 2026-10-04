import SwiftUI

/// Einstellungsbereich für Fächer-Farben und Namen-Ersetzungen
public struct SubjectCustomizationSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    // Formular-Felder für NEUES Fach (bleibt beim Bearbeiten völlig unberührt)
    @State private var originalSubjectInput: String = ""
    @State private var customNameInput: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var useGradientInput: Bool = false
    @State private var gradientEndHexInput: String = "#06B6D4"

    // Dialog & Sheet Zustände
    @State private var showImportAlert: Bool = false
    @State private var showDeleteAllAlert: Bool = false
    @State private var editingSubject: SubjectCustomization? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Abschnittsüberschrift
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Fächer, Farben & Namen anpassen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Text("Lege fest, welche Hintergrundfarbe ein Fach im Stundenplan hat und wie der Name ersetzt werden soll (z.B. Untis-Kürzel 'M' zu 'Mathematik').")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            // 1. NEUES FACH ANLEGEN (Separater Bereich – wird beim Bearbeiten NICHT überschrieben)
            VStack(alignment: .leading, spacing: 12) {
                Text("Neues Fach anlegen:")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.primary)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name von Untis:")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        KeyboardTextField(
                            "z.B. M, D, ENG",
                            text: $originalSubjectInput,
                            capitalization: .allCharacters,
                            autocorrection: .no
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neuer Name:")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        KeyboardTextField(
                            "z.B. Mathematik",
                            text: $customNameInput,
                            returnKeyType: .done,
                            onSubmit: addNewCustomization
                        )
                    }
                }

                ColorPickerPresets(
                    selectedHex: $selectedColorHex,
                    title: useGradientInput ? "Obere Anfangs-Farbe wählen:" : "Fach-Farbe wählen:"
                )

                Toggle(isOn: $useGradientInput.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.bottomhalf.filled")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.blue)
                        Text("Farbverlauf (obere → untere Farbe)")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }

                if useGradientInput {
                    ColorPickerPresets(
                        selectedHex: $gradientEndHexInput,
                        title: "Untere End-Farbe wählen:"
                    )

                    // Live-Vorschau des Verlaufs
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: selectedColorHex).pastel,
                                    Color(hex: gradientEndHexInput).pastel
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }

                HStack {
                    Spacer()

                    Button(action: {
                        Haptics.tap()
                        addNewCustomization()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Fach hinzufügen")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .lightButton(cornerRadius: 10, tint: .blue, isFilled: true)
                    .foregroundColor(.white)
                    .disabled(originalSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.2)

            // 2. IMPORT & ALLE LÖSCHEN BUTTONS MIT BESTÄTIGUNG
            HStack(spacing: 10) {
                // Importieren Button
                Button(action: {
                    Haptics.tap()
                    showImportAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 13, weight: .regular, design: .default))
                        Text("Aus aktuellem Stundenplan importieren")
                            .font(.system(size: 13, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 10)
                }
                .lightButton(cornerRadius: 10, tint: .blue)
                .foregroundColor(.blue)

                // Alle löschen Button
                Button(action: {
                    Haptics.warning()
                    showDeleteAllAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular, design: .default))
                        Text("Alle löschen")
                            .font(.system(size: 13, weight: .regular, design: .default))
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                }
                .lightButton(cornerRadius: 10, tint: .red)
                .foregroundColor(.red)
                .disabled(viewModel.subjectCustomizations.isEmpty)
                .opacity(viewModel.subjectCustomizations.isEmpty ? 0.45 : 1.0)
            }
            .padding(.top, 2)

            Divider()
                .padding(.vertical, 2)

            // 3. LISTE DER KONFIGURIERTEN FÄCHER
            HStack {
                Text("Eingestellte Fächer (\(viewModel.subjectCustomizations.count)):")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if viewModel.subjectCustomizations.isEmpty {
                VStack(spacing: 6) {
                    Text("Keine benutzerdefinierten Fächer vorhanden.")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    Text("Füge oben ein Fach hinzu oder importiere Fächer aus deinem aktuellen Stundenplan.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .lightCard(cornerRadius: 12, strokeOpacity: 0.15)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.subjectCustomizations) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: item.colorHex),
                                            Color(hex: item.gradientEndHex ?? item.colorHex)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 22, height: 22)

                            Text(item.originalSubject)
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(.secondary)

                            Text(item.customName.isEmpty ? item.originalSubject : item.customName)
                                .font(.system(size: 14, weight: .regular, design: .default))

                            Spacer()

                            // Bearbeiten Button (Öffnet separates manuelles Bearbeitungsfenster)
                            Button(action: {
                                Haptics.tap()
                                editingSubject = item
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                            }
                            .lightButton(cornerRadius: 16, tint: .blue)

                            // Löschen Button
                            Button(action: {
                                Haptics.tap()
                                withAnimation {
                                    viewModel.deleteCustomization(id: item.id)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundColor(.red)
                                    .frame(width: 32, height: 32)
                            }
                            .lightButton(cornerRadius: 16, tint: .red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .lightCard(cornerRadius: 12, strokeOpacity: 0.18)
                    }
                }
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        // Bestätigung für Import
        .alert("Stundenplan-Fächer importieren", isPresented: $showImportAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Importieren") {
                viewModel.importDiscoveredSubjects()
            }
        } message: {
            Text("Möchtest du alle Fächer aus dem aktuellen Stundenplan zur Liste hinzufügen?")
        }
        // Bestätigung für Alle Löschen
        .alert("Alle Fächer löschen", isPresented: $showDeleteAllAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Alle löschen", role: .destructive) {
                withAnimation {
                    viewModel.deleteAllCustomizations()
                }
            }
        } message: {
            Text("Möchtest du wirklich alle eingestellten Fächer unwiderruflich aus der Liste entfernen?")
        }
        // Manuelles Bearbeitungs-Fenster (Sheet)
        .sheet(item: $editingSubject) { subject in
            EditSubjectSheet(subject: subject) { updated in
                withAnimation {
                    viewModel.addOrUpdateCustomization(updated)
                }
                editingSubject = nil
            } onCancel: {
                editingSubject = nil
            }
            .presentationDetents([.large])
        }
    }

    private func addNewCustomization() {
        let original = originalSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = customNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }

        let item = SubjectCustomization(
            originalSubject: original,
            customName: custom.isEmpty ? original : custom,
            colorHex: selectedColorHex,
            gradientEndHex: useGradientInput ? gradientEndHexInput : nil
        )

        withAnimation {
            viewModel.addOrUpdateCustomization(item)
        }
        originalSubjectInput = ""
        customNameInput = ""
        selectedColorHex = "#3B82F6"
        useGradientInput = false
        gradientEndHexInput = "#06B6D4"
    }
}

/// Separates Sheet-Fenster zum manuellen Bearbeiten eines bestehenden Fachs
struct EditSubjectSheet: View {
    let subject: SubjectCustomization
    let onSave: (SubjectCustomization) -> Void
    let onCancel: () -> Void

    @State private var originalSubject: String = ""
    @State private var customName: String = ""
    @State private var colorHex: String = "#3B82F6"
    @State private var useGradient: Bool = false
    @State private var gradientEndHex: String = "#06B6D4"

    init(
        subject: SubjectCustomization,
        onSave: @escaping (SubjectCustomization) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.subject = subject
        self.onSave = onSave
        self.onCancel = onCancel
        self._originalSubject = State(initialValue: subject.originalSubject)
        self._customName = State(initialValue: subject.customName)
        self._colorHex = State(initialValue: subject.colorHex)
        self._useGradient = State(initialValue: subject.gradientEndHex != nil)
        self._gradientEndHex = State(initialValue: subject.gradientEndHex ?? "#06B6D4")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Passe die Einstellungen für dieses Schulfach an.")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name von Untis:")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                KeyboardTextField(
                                    "z.B. M",
                                    text: $originalSubject,
                                    capitalization: .allCharacters,
                                    autocorrection: .no
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Neuer Name im Stundenplan:")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                KeyboardTextField(
                                    "z.B. Mathematik",
                                    text: $customName,
                                    returnKeyType: .done,
                                    onSubmit: saveChanges
                                )
                            }

                            ColorPickerPresets(
                                selectedHex: $colorHex,
                                title: useGradient ? "Obere Anfangs-Farbe wählen:" : "Fach-Farbe wählen:"
                            )

                            Toggle(isOn: $useGradient.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.bottomhalf.filled")
                                        .font(.system(size: 14, weight: .regular, design: .default))
                                        .foregroundColor(.blue)
                                    Text("Farbverlauf (obere → untere Farbe)")
                                        .font(.system(size: 14, weight: .regular, design: .default))
                                }
                            }

                            if useGradient {
                                ColorPickerPresets(
                                    selectedHex: $gradientEndHex,
                                    title: "Untere End-Farbe wählen:"
                                )

                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: colorHex).pastel,
                                                Color(hex: gradientEndHex).pastel
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(16)
                        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)

                        HStack(spacing: 12) {
                            Button(action: {
                                Haptics.tap()
                                onCancel()
                            }) {
                                Text("Abbrechen")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .lightButton(cornerRadius: 12)
                            .foregroundColor(.secondary)

                            Button(action: {
                                Haptics.tap()
                                saveChanges()
                            }) {
                                Text("Speichern")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .lightButton(cornerRadius: 12, tint: .blue, isFilled: true)
                            .foregroundColor(.white)
                            .disabled(originalSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.never)
            }
            .navigationTitle("Fach bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        Haptics.tap()
                        saveChanges()
                    }
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .disabled(originalSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // Auch verschachtelte Sheets bekommen ihre eigene Tastatur unten im
        // Sheet; sichtbar ist immer nur die des obersten Hosts.
        .appKeyboardHost()
    }

    private func saveChanges() {
        let cleanOriginal = originalSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCustom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanOriginal.isEmpty else { return }

        let updated = SubjectCustomization(
            id: subject.id,
            originalSubject: cleanOriginal,
            customName: cleanCustom.isEmpty ? cleanOriginal : cleanCustom,
            colorHex: colorHex,
            gradientEndHex: useGradient ? gradientEndHex : nil
        )
        onSave(updated)
    }
}
