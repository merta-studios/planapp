import SwiftUI

/// Sheet zum Anlegen bzw. Ändern eines Eintrags im Modul „Noten & Punkte“.
///
/// * Normale Noten: sechs Knöpfe 1 – 6 (sofort ausgewählt)
/// * Punkte / Prozent: Regler von Minimum bis Maximum, Start beim in den
///   Einstellungen hinterlegten Wert
/// * Alle Systeme: optionales Notizfeld (z. B. „Deutsch Test“)
/// * Bei aktivierter Umrechnung: Vorschau der Note
struct GradeEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let subject: SubjectCustomization
    let existing: GradeEntry?
    let viewModel: TimetableViewModel

    @State private var value: Double = 1
    @State private var noteText: String = ""
    @State private var date: Date = Date()
    @FocusState private var isNoteFocused: Bool

    private var settings: GradeSettings { viewModel.gradeSettings }

    init(subject: SubjectCustomization, existing: GradeEntry?, viewModel: TimetableViewModel) {
        self.subject = subject
        self.existing = existing
        self.viewModel = viewModel

        // Startwert: bestehender Eintrag, sonst der in den Einstellungen
        // hinterlegte Standard (Mitte des Reglers bzw. Note 1 … 6).
        if let existing {
            _value = State(initialValue: existing.value)
            _noteText = State(initialValue: existing.note)
            _date = State(initialValue: existing.date)
        } else {
            _value = State(initialValue: viewModel.defaultGradeEntryValue)
            _noteText = State(initialValue: "")
            _date = State(initialValue: Date())
        }
    }

    private var displayName: String {
        viewModel.resolveSubjectDisplay(for: subject).name
    }

    private var unit: GradeSystem { settings.system }

    private var previewGrade: Double {
        GradeMath.grade(
            forFraction: GradeMath.fraction(
                for: value,
                unit: unit,
                maximumPoints: settings.maximumPoints,
                higherPointsAreBetter: settings.higherPointsAreBetter
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    valueSection
                    if settings.showsGradesForEntries {
                        conversionPreview
                    }
                    noteSection
                    dateSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle(existing == nil ? "Eintrag hinzufügen" : "Eintrag ändern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        Haptics.tap()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Wert

    @ViewBuilder
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: unit.systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.mint)
                Text(displayName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                Spacer()
                Text(systemTitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }

            switch unit {
            case .grades:
                gradeButtons
            case .points, .percent:
                sliderInput
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    private var systemTitle: String {
        switch unit {
        case .grades: return "Note"
        case .points: return "0 – \(settings.maximumPoints) Punkte"
        case .percent: return "0 – 100 %"
        }
    }

    /// Sechs Knöpfe für die Noten 1 … 6.
    private var gradeButtons: some View {
        HStack(spacing: 8) {
            ForEach(1...6, id: \.self) { grade in
                let isSelected = Int(value.rounded()) == grade
                Button {
                    Haptics.select()
                    value = Double(grade)
                } label: {
                    Text("\(grade)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected
                                      ? Color(hex: GradeMath.colorHex(forFraction: GradeMath.fraction(
                                            for: Double(grade),
                                            unit: .grades,
                                            maximumPoints: settings.maximumPoints,
                                            higherPointsAreBetter: true
                                        )))
                                      : Color(UIColor.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.black.opacity(0.18) : Color.black.opacity(0.05),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Note \(grade)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    /// Regler für Punkte und Prozent.
    private var sliderInput: some View {
        let range = GradeMath.sliderRange(unit: unit, maximumPoints: settings.maximumPoints)
        return VStack(spacing: 10) {
            Text(GradeMath.valueText(value, unit: unit, maximumPoints: settings.maximumPoints))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .animation(.none, value: value)

            Slider(
                value: Binding(
                    get: { GradeMath.sliderFraction(for: value, unit: unit, maximumPoints: settings.maximumPoints) },
                    set: { fraction in
                        value = GradeMath.value(
                            forSliderFraction: fraction,
                            unit: unit,
                            maximumPoints: settings.maximumPoints
                        )
                    }
                ),
                in: 0...1
            )
            .tint(sliderTint)
            .onChange(of: value) { _, _ in
                Haptics.select()
            }

            HStack {
                Text(GradeMath.valueText(range.lowerBound, unit: unit, maximumPoints: settings.maximumPoints))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                Spacer()
                Text(GradeMath.valueText(range.upperBound, unit: unit, maximumPoints: settings.maximumPoints))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sliderTint: Color {
        Color(hex: GradeMath.colorHex(
            forFraction: GradeMath.fraction(
                for: value,
                unit: unit,
                maximumPoints: settings.maximumPoints,
                higherPointsAreBetter: settings.higherPointsAreBetter
            )
        ))
    }

    // MARK: - Umrechnung

    private var conversionPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Entspricht der Note")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text(GradeMath.gradeText(previewGrade))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: GradeMath.colorHex(forFraction: 1 - (previewGrade - 1) / 5)))
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Notiz & Datum

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.mint)
                Text("Notiz (optional)")
                    .font(.system(size: 14, weight: .regular))
            }

            TextField("z. B. Deutsch Test", text: $noteText, axis: .vertical)
                .font(.system(size: 15, weight: .regular))
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .focused($isNoteFocused)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .onChange(of: noteText) { _, newValue in
                    if newValue.count > 80 {
                        noteText = String(newValue.prefix(80))
                    }
                }

            Text("Erscheint klein unter dem Wert auf der Kachel.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.mint)
                Text("Datum")
                    .font(.system(size: 14, weight: .regular))
            }

            DatePicker(
                "Datum",
                selection: $date,
                in: Date.distantPast...Date.distantFuture,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Speichern

    private func save() {
        let entry = GradeEntry(
            id: existing?.id ?? UUID(),
            value: value,
            unit: unit,
            maximumPoints: settings.maximumPoints,
            higherPointsAreBetter: settings.higherPointsAreBetter,
            note: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            updatedAt: Date()
        )
        Haptics.success()
        viewModel.saveGradeEntry(entry, for: subject)
        dismiss()
    }
}
