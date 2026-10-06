import SwiftUI

/// Manuelle Ersetzungen für Lehrer-Kürzel/Namen.
///
/// Diese Liste wird bewusst nicht automatisch aus dem Stundenplan befüllt. Der
/// Nutzer legt nur die Kürzel an, die wirklich anders angezeigt werden sollen.
public struct TeacherCustomizationSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var systemAbbreviationInput: String = ""
    @State private var displayNameInput: String = ""
    @State private var showDeleteAllAlert = false
    @State private var editingTeacher: TeacherNameCustomization? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Lehrer-Namen anpassen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Text("Lege manuell fest, wie Lehrer-Kürzel aus dem System angezeigt werden sollen. Es wird nichts automatisch hinzugefügt – du bestimmst die Liste selbst.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            inputCard

            HStack(spacing: 10) {
                Button(action: {
                    Haptics.warning()
                    showDeleteAllAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular, design: .default))
                        Text("Alle leeren")
                            .font(.system(size: 13, weight: .regular, design: .default))
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                }
                .lightButton(cornerRadius: 10, tint: .red)
                .foregroundColor(.red)
                .disabled(viewModel.teacherNameCustomizations.isEmpty)
                .opacity(viewModel.teacherNameCustomizations.isEmpty ? 0.45 : 1.0)

                Spacer()
            }
            .padding(.top, 2)

            Divider()
                .padding(.vertical, 2)

            HStack {
                Text("Eingestellte Lehrer-Namen (\(viewModel.teacherNameCustomizations.count)/\(TimetableViewModel.maximumTeacherNameCustomizations)):")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if viewModel.teacherNameCustomizations.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.teacherNameCustomizations) { item in
                        teacherRow(item)
                    }
                }
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .alert("Alle Lehrer-Namen leeren", isPresented: $showDeleteAllAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Alle leeren", role: .destructive) {
                withAnimation {
                    viewModel.deleteAllTeacherNameCustomizations()
                }
            }
        } message: {
            Text("Möchtest du wirklich alle manuell eingestellten Lehrer-Namen entfernen?")
        }
        .sheet(item: $editingTeacher) { teacher in
            EditTeacherSheet(teacher: teacher) { updated in
                withAnimation {
                    // Rückgabewert (`false` bei erreichtem Limit) wird bewusst
                    // verworfen – das ViewModel setzt stattdessen `errorMessage`.
                    // Ohne das `_ =` liefert die Closure einen `Bool` und
                    // `withAnimation` meldet einen unbenutzten Rückgabewert.
                    _ = viewModel.addOrUpdateTeacherNameCustomization(updated)
                }
                editingTeacher = nil
            } onCancel: {
                editingTeacher = nil
            }
            .presentationDetents([.large])
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neuen Lehrer-Namen anlegen:")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lehrer-Kürzel vom System:")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    KeyboardTextField(
                        "z.B. DÜCK",
                        text: $systemAbbreviationInput,
                        capitalization: .allCharacters,
                        autocorrection: .no
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gewünschter Name:")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                    KeyboardTextField(
                        "z.B. Frau Dückerhoff",
                        text: $displayNameInput,
                        returnKeyType: .done,
                        onSubmit: addTeacherName
                    )
                }
            }

            HStack {
                Spacer()

                Button(action: {
                    Haptics.tap()
                    addTeacherName()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Lehrer hinzufügen")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .lightButton(cornerRadius: 10, tint: .blue, isFilled: true)
                .foregroundColor(.white)
                .disabled(!canAddTeacherName)
            }

            if !viewModel.canAddTeacherNameCustomization {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .regular, design: .default))
                    Text("Maximal \(TimetableViewModel.maximumTeacherNameCustomizations) Lehrkräfte erreicht. Bestehende Kürzel lassen sich weiterhin ändern; für neue Einträge zuerst einen löschen.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(14)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Keine Lehrer-Namen eingestellt.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)
            Text("Füge oben nur die Kürzel hinzu, die du wirklich ersetzen möchtest – zum Beispiel DÜCK → Frau Dückerhoff.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .lightCard(cornerRadius: 12, strokeOpacity: 0.15)
    }

    private func teacherRow(_ item: TeacherNameCustomization) -> some View {
        HStack(spacing: 12) {
            Text(item.systemAbbreviation)
                .font(.system(size: 14, weight: .regular, design: .default))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(UIColor.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            Text(item.displayName.isEmpty ? item.systemAbbreviation : item.displayName)
                .font(.system(size: 14, weight: .regular, design: .default))
                .lineLimit(1)

            Spacer()

            Button(action: {
                Haptics.tap()
                editingTeacher = item
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            .lightButton(cornerRadius: 16, tint: .blue)

            Button(action: {
                Haptics.tap()
                withAnimation {
                    viewModel.deleteTeacherNameCustomization(id: item.id)
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

    private var canAddTeacherName: Bool {
        let abbreviation = systemAbbreviationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !abbreviation.isEmpty,
              !displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if viewModel.canAddTeacherNameCustomization { return true }
        // Am Limit: Nur noch Änderungen an einem bereits vorhandenen Kürzel.
        return viewModel.teacherNameCustomizations.contains {
            $0.systemAbbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(abbreviation) == .orderedSame
        }
    }

    private func addTeacherName() {
        let abbreviation = systemAbbreviationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !abbreviation.isEmpty, !displayName.isEmpty else { return }

        let item = TeacherNameCustomization(
            systemAbbreviation: abbreviation,
            displayName: displayName
        )

        withAnimation {
            // Ergebnis (erfolgreich angelegt?) wird nicht ausgewertet, siehe oben.
            _ = viewModel.addOrUpdateTeacherNameCustomization(item)
        }
        systemAbbreviationInput = ""
        displayNameInput = ""
    }
}

/// Separates Sheet zum Bearbeiten eines bestehenden Lehrer-Namens.
private struct EditTeacherSheet: View {
    let teacher: TeacherNameCustomization
    let onSave: (TeacherNameCustomization) -> Void
    let onCancel: () -> Void

    @State private var systemAbbreviation: String
    @State private var displayName: String

    init(
        teacher: TeacherNameCustomization,
        onSave: @escaping (TeacherNameCustomization) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.teacher = teacher
        self.onSave = onSave
        self.onCancel = onCancel
        self._systemAbbreviation = State(initialValue: teacher.systemAbbreviation)
        self._displayName = State(initialValue: teacher.displayName)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Passe an, welches System-Kürzel durch welchen Lehrer-Namen ersetzt wird.")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lehrer-Kürzel vom System:")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                KeyboardTextField(
                                    "z.B. DÜCK",
                                    text: $systemAbbreviation,
                                    capitalization: .allCharacters,
                                    autocorrection: .no
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gewünschter Name:")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                KeyboardTextField(
                                    "z.B. Frau Dückerhoff",
                                    text: $displayName,
                                    returnKeyType: .done,
                                    onSubmit: saveChanges
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
                            .disabled(!canSave)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.never)
            }
            .navigationTitle("Lehrer bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        Haptics.tap()
                        saveChanges()
                    }
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .disabled(!canSave)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var canSave: Bool {
        !systemAbbreviation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveChanges() {
        let cleanAbbreviation = systemAbbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAbbreviation.isEmpty, !cleanDisplayName.isEmpty else { return }

        onSave(TeacherNameCustomization(
            id: teacher.id,
            systemAbbreviation: cleanAbbreviation,
            displayName: cleanDisplayName
        ))
    }
}
