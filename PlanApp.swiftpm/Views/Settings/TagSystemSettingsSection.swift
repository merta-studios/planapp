import SwiftUI

/// Einstellungen → „Tag-System“: Schalter zum Aktivieren sowie die Liste
/// aller Tags (Name + Farbe, maximal 20). Die Reihenfolge der Liste ist die
/// Reihenfolge in der Tag-Auswahl der Notiz und in der Filterleiste.
struct TagSystemSettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    /// Tag, dessen Name/Farbe gerade bearbeitet wird (Sheet).
    @State private var editingTag: NoteTag? = nil
    @State private var tagPendingDeletion: NoteTag? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.indigo)
                Text("Tag-System")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            // 1. AKTIVIEREN
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(
                    get: { viewModel.tagSettings.isEnabled },
                    set: { newValue in
                        Haptics.select()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.setTagSystemEnabled(newValue)
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tag System aktivieren")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Zeigt in jeder Notiz neben dem Fachnamen „+ Tag hinzufügen“. Der gewählte Tag erscheint unten rechts in der Vorschau im Stundenplan; im Modus „Nur Notizen“ kannst du nach Tags filtern.")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // 2. TAG-LISTE
            if viewModel.tagSettings.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.indigo)
                        Text("Tags")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Spacer()
                        Text("\(viewModel.tagSettings.tags.count)/\(NoteTagSettings.maximumTagCount)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if viewModel.tagSettings.tags.isEmpty {
                        Text("Noch keine Tags. Lege z. B. „Hausaufgabe“, „Test“ oder „Wichtig“ an.")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        List {
                            ForEach(viewModel.tagSettings.tags) { tag in
                                tagRow(tag)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.visible)
                            }
                            .onMove { source, destination in
                                Haptics.select()
                                viewModel.moveTags(fromOffsets: source, toOffset: destination)
                            }
                            .deleteDisabled(true)
                        }
                        .listStyle(.plain)
                        .environment(\.editMode, .constant(.active))
                        .scrollDisabled(true)
                        .frame(height: CGFloat(max(viewModel.tagSettings.tags.count, 1)) * 56)
                    }

                    Button(action: addTag) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text(viewModel.tagSettings.canAddTag
                                 ? "Tag hinzufügen"
                                 : "Maximal \(NoteTagSettings.maximumTagCount) Tags erreicht")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .lightButton(cornerRadius: 12, tint: .indigo)
                    .foregroundColor(.indigo)
                    .disabled(!viewModel.tagSettings.canAddTag)
                    .opacity(viewModel.tagSettings.canAddTag ? 1 : 0.55)

                    Text("Zum Umbenennen oder Umfärben das Stift-Symbol antippen. Die drei Striche rechts halten und ziehen, um die Reihenfolge zu ändern. Wird ein Tag gelöscht, verlieren die betroffenen Notizen nur ihren Tag – der Inhalt bleibt.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .sheet(item: $editingTag) { tag in
            TagEditorSheet(tag: tag) { updated in
                viewModel.updateTag(updated)
            }
        }
        .alert(
            "Tag löschen?",
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { if !$0 { tagPendingDeletion = nil } }
            ),
            presenting: tagPendingDeletion
        ) { tag in
            Button("Löschen", role: .destructive) {
                Haptics.warning()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.deleteTag(id: tag.id)
                }
                tagPendingDeletion = nil
            }
            Button("Abbrechen", role: .cancel) {
                tagPendingDeletion = nil
            }
        } message: { tag in
            Text("„\(tag.displayName)“ wird aus allen Notizen entfernt. Die Notizen selbst bleiben erhalten.")
        }
    }

    // MARK: - Zeile

    private func tagRow(_ tag: NoteTag) -> some View {
        HStack(spacing: 10) {
            NoteTagPill(tag: tag, size: .regular)
            Text(tag.displayName)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                editingTag = tag
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag bearbeiten")

            Button(role: .destructive) {
                tagPendingDeletion = tag
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tag löschen")
        }
        .padding(.vertical, 2)
    }

    private func addTag() {
        guard viewModel.tagSettings.canAddTag else { return }
        Haptics.tap()
        let colorHex = viewModel.tagSettings.nextSuggestedColorHex
        let name = "Tag \(viewModel.tagSettings.tags.count + 1)"
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.addTag(name: name, colorHex: colorHex)
        }
        // Neuen Tag direkt zum Bearbeiten öffnen.
        if let created = viewModel.tagSettings.tags.last {
            editingTag = created
        }
    }
}

/// Kleines Sheet zum Bearbeiten von Name und Farbe eines Tags.
private struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colorHex: String
    private let original: NoteTag
    private let onSave: (NoteTag) -> Void

    init(tag: NoteTag, onSave: @escaping (NoteTag) -> Void) {
        self.original = tag
        self.onSave = onSave
        _name = State(initialValue: tag.name)
        _colorHex = State(initialValue: tag.colorHex)
    }

    private var preview: NoteTag {
        NoteTag(id: original.id, name: name, colorHex: colorHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        NoteTagPill(tag: preview, size: .regular)
                        Spacer()
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        TextField("z. B. Hausaufgabe", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 24 {
                                    name = String(newValue.prefix(24))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Farbe")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 10), count: 7), spacing: 10) {
                            ForEach(NoteTag.suggestedColors, id: \.self) { hex in
                                Button {
                                    Haptics.select()
                                    colorHex = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 34, height: 34)
                                        if colorHex.caseInsensitiveCompare(hex) == .orderedSame {
                                            Circle()
                                                .strokeBorder(Color.primary.opacity(0.7), lineWidth: 2.5)
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ColorPicker(
                            "Eigene Farbe",
                            selection: Binding(
                                get: { Color(hex: colorHex) },
                                set: { colorHex = UIColor($0).toHex() }
                            ),
                            supportsOpacity: false
                        )
                        .font(.system(size: 14, weight: .regular, design: .default))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Tag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        Haptics.success()
                        onSave(preview)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
