import SwiftUI

/// Detailansicht eines Fachs im Modul „Noten & Punkte“.
///
/// Ein Raster aus Kacheln:
/// * erste Kachel: grau gestrichelt mit grauem Plus → neuen Eintrag anlegen
/// * danach je Eintrag eine farbige Kachel: Datum oben, großer Wert in der
///   Mitte, Anmerkung klein darunter
///
/// Ein Tipp auf eine Kachel ändert den Eintrag, langes Drücken bietet **nur**
/// „Löschen“.
struct GradeSubjectDetailView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    let subject: SubjectCustomization

    @State private var editorState: GradeEntryEditorState? = nil
    @State private var entryPendingDeletion: GradeEntry? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    tileGrid
                }
                .padding(.horizontal, DeviceLayout.isPhone ? 12 : 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        Haptics.tap()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(GradeEntrySort.allCases) { sort in
                            Button {
                                Haptics.select()
                                viewModel.gradeEntrySort = sort
                            } label: {
                                if viewModel.gradeEntrySort == sort {
                                    Label(sort.title, systemImage: "checkmark")
                                } else {
                                    Text(sort.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Einträge sortieren")
                }
            }
        }
        .presentationDetents(DeviceLayout.isPhone ? [.large] : [.medium, .large])
        .sheet(item: $editorState) { state in
            GradeEntryEditorSheet(
                subject: subject,
                existing: state.entry,
                viewModel: viewModel
            )
        }
        .confirmationDialog(
            "Eintrag löschen?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: entryPendingDeletion
        ) { entry in
            Button("Löschen", role: .destructive) {
                Haptics.warning()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.deleteGradeEntry(id: entry.id, for: subject)
                }
                entryPendingDeletion = nil
            }
            Button("Abbrechen", role: .cancel) { entryPendingDeletion = nil }
        } message: { _ in
            Text("Der Eintrag wird dauerhaft entfernt.")
        }
    }

    private var displayName: String {
        let display = viewModel.resolveSubjectDisplay(for: subject)
        return display.name
    }

    // MARK: - Kopf

    private var summaryCard: some View {
        let display = viewModel.resolveSubjectDisplay(for: subject)
        let entries = viewModel.gradeEntries(for: subject)
        let average = viewModel.gradeAverageText(for: subject)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(display.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black.opacity(0.86))
                Text(entries.isEmpty
                     ? "Noch keine Einträge"
                     : (entries.count == 1 ? "1 Eintrag" : "\(entries.count) Einträge"))
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.55))
                Text(systemSummary)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.55))
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(average)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(entries.isEmpty ? 0.3 : 0.82))
                Text("Ø")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(0.45))
            }
            .frame(width: 66, height: 66)
            .background(Circle().fill(Color.white.opacity(0.92)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subjectBackground(display))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
    }

    /// Kurze Beschreibung des Eingabe-Systems, z. B. „Punkte 0 – 15“.
    private var systemSummary: String {
        let settings = viewModel.gradeSettings
        switch settings.system {
        case .grades:
            return "Normale Noten 1 – 6"
        case .points:
            let direction = settings.higherPointsAreBetter ? "mehr ist besser" : "weniger ist besser"
            let conversion = settings.convertsToGrade ? " · wird in Noten umgerechnet" : ""
            return "Punkte 0 – \(settings.maximumPoints) (\(direction))\(conversion)"
        case .percent:
            let conversion = settings.convertsToGrade ? " · wird in Noten umgerechnet" : ""
            return "Prozent 0 – 100\(conversion)"
        }
    }

    @ViewBuilder
    private func subjectBackground(_ display: SubjectDisplay) -> some View {
        if let end = display.gradientEndColor {
            LinearGradient(colors: [display.color, end], startPoint: .top, endPoint: .bottom)
        } else {
            display.color
        }
    }

    // MARK: - Kacheln

    private var tileGrid: some View {
        let entries = viewModel.gradeEntriesSorted(for: subject)
        return LazyVGrid(columns: columns, spacing: 12) {
            addTile

            ForEach(entries) { entry in
                Button {
                    Haptics.tap()
                    editorState = GradeEntryEditorState(entry: entry)
                } label: {
                    entryTile(entry)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    // Langes Drücken bietet **nur** Löschen.
                    Button(role: .destructive) {
                        Haptics.warning()
                        entryPendingDeletion = entry
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        let count: Int
        if DeviceLayout.isPhone {
            count = 2
        } else {
            count = 3
        }
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    /// Gray dashed tile with a gray plus – legt einen neuen Eintrag an.
    private var addTile: some View {
        Button {
            Haptics.tap()
            editorState = GradeEntryEditorState(entry: nil)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(Color(UIColor.systemGray))
                Text("Hinzufügen")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(UIColor.systemGray))
            }
            .frame(maxWidth: .infinity)
            .frame(height: tileHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Color(UIColor.systemGray3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Eintrag hinzufügen")
    }

    private var tileHeight: CGFloat {
        DeviceLayout.isPhone ? 108 : 124
    }

    private func entryTile(_ entry: GradeEntry) -> some View {
        VStack(spacing: 2) {
            Text(entry.shortDateText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.black.opacity(0.42))
                .lineLimit(1)

            Spacer(minLength: 2)

            Text(entry.valueText)
                .font(.system(size: DeviceLayout.isPhone ? 26 : 30, weight: .bold, design: .rounded))
                .foregroundColor(tileTextColor(for: entry))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Spacer(minLength: 2)

            // Bei Punkten/Prozent mit Umrechnung: die Note klein darunter.
            if viewModel.gradeSettings.showsGradesForEntries, entry.unit != .grades {
                Text("Note \(entry.gradeText)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black.opacity(0.45))
                    .lineLimit(1)
            }

            if !entry.trimmedNote.isEmpty {
                Text(entry.trimmedNote)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.black.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: tileHeight)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: entry.colorHex))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: entry))
    }

    private func tileTextColor(for entry: GradeEntry) -> Color {
        // Sehr schlechte Einträge sind kräftig rot – dort weiße Schrift,
        // sonst dunkle Schrift auf den pastelligen Tönen.
        entry.fraction < 0.28 ? Color.white.opacity(0.95) : Color.black.opacity(0.82)
    }

    private func accessibilityText(for entry: GradeEntry) -> String {
        var parts = [entry.shortDateText, entry.valueText]
        if viewModel.gradeSettings.showsGradesForEntries, entry.unit != .grades {
            parts.append("Note \(entry.gradeText)")
        }
        if !entry.trimmedNote.isEmpty {
            parts.append(entry.trimmedNote)
        }
        return parts.joined(separator: ", ")
    }
}

/// Zustand des Eintrag-Editors (neu oder bestehend). `Identifiable`, damit
/// `.sheet(item:)` zuverlässig genau einmal öffnet.
struct GradeEntryEditorState: Identifiable {
    let id = UUID()
    let entry: GradeEntry?
}
