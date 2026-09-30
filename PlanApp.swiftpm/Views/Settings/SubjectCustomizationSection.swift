import SwiftUI

/// Einstellungsbereich für Fächer-Farben und Namen-Ersetzungen
public struct SubjectCustomizationSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var originalSubjectInput: String = ""
    @State private var customNameInput: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var editingId: UUID? = nil

    public init() {}

    public var body: some View {
        Section(header: Text("Fächer, Farben & Namen anpassen").font(.system(size: 14, weight: .bold))) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Lege fest, welche Hintergrundfarbe ein Fach im Stundenplan hat und wie der Name ersetzt werden soll (z.B. Untis-Kürzel 'M' zu 'Mathematik').")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // NEUES FACH HINZUFÜGEN / BEARBEITEN
                VStack(alignment: .leading, spacing: 10) {
                    Text(editingId == nil ? "Neues Fach anlegen:" : "Fach bearbeiten:")
                        .font(.system(size: 14, weight: .semibold))

                    HStack(spacing: 10) {
                        // Fachkürzel aus Untis
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Name von Untis:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            KeyboardTextField(
                                "z.B. M, D, ENG",
                                text: $originalSubjectInput,
                                capitalization: .allCharacters,
                                autocorrection: .no
                            )
                            .frame(minHeight: 36)
                        }

                        // Neuer schöner Name
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Neuer Name:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            KeyboardTextField(
                                "z.B. Mathematik",
                                text: $customNameInput,
                                returnKeyType: .done,
                                onSubmit: saveCustomization
                            )
                            .frame(minHeight: 36)
                        }
                    }

                    // Farbwähler
                    ColorPickerPresets(selectedHex: $selectedColorHex)

                    // Hinzufügen / Aktualisieren Button
                    HStack {
                        if editingId != nil {
                            Button("Abbrechen") {
                                resetForm()
                            }
                            .foregroundColor(.secondary)
                            .hoverEffect(.lift)
                        }

                        Spacer()

                        Button(action: saveCustomization) {
                            HStack(spacing: 6) {
                                Image(systemName: editingId == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                                Text(editingId == nil ? "Fach hinzufügen" : "Speichern")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .hoverEffect(.lift)
                        .disabled(originalSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Schneller Import aus aktuellem Stundenplan
                Button(action: {
                    viewModel.importDiscoveredSubjects()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Aus aktuellem Stundenplan importieren")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                }
                .hoverEffect(.lift)
                .padding(.top, 2)

                Divider()

                // LISTE DER KONFIGURIERTEN FÄCHER
                Text("Eingestellte Fächer (\(viewModel.subjectCustomizations.count)):")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach(viewModel.subjectCustomizations) { item in
                    HStack(spacing: 12) {
                        // Farbmuster
                        Circle()
                            .fill(Color(hex: item.colorHex))
                            .frame(width: 24, height: 24)
                            .shadow(color: Color(hex: item.colorHex).opacity(0.3), radius: 2)

                        // Untis-Kürzel
                        Text(item.originalSubject)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(UIColor.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        // Ersetzter Name
                        Text(item.customName.isEmpty ? item.originalSubject : item.customName)
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        // Bearbeiten
                        Button(action: {
                            editItem(item)
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 30, height: 30)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .hoverEffect(.lift)

                        // Löschen
                        Button(action: {
                            withAnimation {
                                viewModel.deleteCustomization(id: item.id)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 30, height: 30)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .hoverEffect(.lift)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func saveCustomization() {
        let original = originalSubjectInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = customNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }

        let item = SubjectCustomization(
            id: editingId ?? UUID(),
            originalSubject: original,
            customName: custom.isEmpty ? original : custom,
            colorHex: selectedColorHex
        )

        withAnimation {
            viewModel.addOrUpdateCustomization(item)
        }
        resetForm()
    }

    private func editItem(_ item: SubjectCustomization) {
        self.editingId = item.id
        self.originalSubjectInput = item.originalSubject
        self.customNameInput = item.customName
        self.selectedColorHex = item.colorHex
    }

    private func resetForm() {
        self.editingId = nil
        self.originalSubjectInput = ""
        self.customNameInput = ""
        self.selectedColorHex = "#3B82F6"
    }
}
