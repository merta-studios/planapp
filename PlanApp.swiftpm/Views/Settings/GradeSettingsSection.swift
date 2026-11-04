import SwiftUI

/// Einstellungen → „Noten & Punkte“.
///
/// Das Modul ist standardmäßig **aus**. Solange der Hauptschalter aus ist,
/// zeigt der Abschnitt ausschließlich diesen Schalter – alle weiteren
/// Einstellungen erscheinen erst mit aktivem Modul.
struct GradeSettingsSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    /// Arbeitskopie: Änderungen werden sofort geschrieben (die Werte sind
    /// klein und ohne Folgeschritte), aber die Ansicht liest aus einem
    /// stabilen Zustand – so springt kein Regler.
    @State private var draft: GradeSettings = .default
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerCard

            if draft.isEnabled {
                systemCard
                if draft.system == .points {
                    pointsCard
                }
                if draft.system.supportsGradeConversion {
                    conversionCard
                }
                defaultsCard
                hintCard
            }
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Hauptschalter

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.mint)
                Text("Noten & Punkte")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Toggle(isOn: Binding(
                get: { draft.isEnabled },
                set: { newValue in
                    Haptics.select()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        update { $0.isEnabled = newValue }
                    }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modul aktiv")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Zeigt im Stundenplan den Ansichts-Modus „Noten & Punkte“ zwischen „Nur Notizen“ und der Filterleiste. Dort sammelst du Noten, Punkte oder Prozentwerte für jedes Fach aus „Fächer & Farben“.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !draft.isEnabled {
                Text("Ist das Modul aus, werden keine Noten erfasst oder angezeigt. Alle weiteren Einstellungen erscheinen, sobald du das Modul aktivierst.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - System

    private var systemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.mint)
                Text("Eingabe-System")
                    .font(.system(size: 14, weight: .regular, design: .default))
            }

            ForEach(GradeSystem.allCases) { system in
                Button {
                    Haptics.select()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        update { $0.system = system }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: system.systemImage)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(draft.system == system ? .mint : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(system.title)
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.primary)
                            Text(system.subtitle)
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: draft.system == system ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundColor(draft.system == system ? .mint : .secondary)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if system != GradeSystem.allCases.last {
                    Divider()
                }
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Punkte

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "number.circle")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.mint)
                Text("Punkte")
                    .font(.system(size: 14, weight: .regular, design: .default))
                Spacer()
                Text("0 – \(draft.maximumPoints)")
                    .font(.system(size: 13, weight: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Text("Höchstpunktzahl")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                Stepper(value: Binding(
                    get: { draft.maximumPoints },
                    set: { newValue in update { $0.maximumPoints = newValue } }
                ), in: GradeSettings.minimumPointsLimit...GradeSettings.maximumPointsLimit) {
                    Text("\(draft.maximumPoints)")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .labelsHidden()
                .fixedSize()
            }

            Slider(
                value: Binding(
                    get: { Double(draft.maximumPoints) },
                    set: { update { $0.maximumPoints = Int($0.maximumPoints.rounded()) } }
                ),
                in: Double(GradeSettings.minimumPointsLimit)...Double(GradeSettings.maximumPointsLimit),
                step: 1
            )
            .tint(.mint)

            Divider()

            Toggle(isOn: Binding(
                get: { draft.higherPointsAreBetter },
                set: { newValue in update { $0.higherPointsAreBetter = newValue } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.higherPointsAreBetter
                         ? "Mehr Punkte sind besser"
                         : "Weniger Punkte sind besser")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text(draft.higherPointsAreBetter
                         ? "Die volle Punktzahl entspricht der 1 – 0 Punkte der 6."
                         : "0 Punkte entsprechen der 1 – die volle Punktzahl der 6.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Umrechnung

    private var conversionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { draft.convertsToGrade },
                set: { newValue in update { $0.convertsToGrade = newValue } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eingabe automatisch in Zensur umrechnen")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text("Durchschnitt, Farbe und Kachel zeigen zusätzlich die Note. Die Eingabe bleibt trotzdem \(draft.system == .percent ? "Prozent" : "Punkte").")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Standardwerte

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.mint)
                Text("Standards")
                    .font(.system(size: 14, weight: .regular, design: .default))
            }

            defaultPicker(
                title: "Fächer sortieren nach",
                subtitle: "Start-Sortierung im Modus „Noten & Punkte“.",
                selection: Binding(
                    get: { draft.defaultSubjectSort },
                    set: { newValue in update { $0.defaultSubjectSort = newValue } }
                ),
                values: GradeSubjectSort.allCases,
                label: { $0.title }
            )

            Divider()

            defaultPicker(
                title: "Einträge sortieren nach",
                subtitle: "Reihenfolge der Kacheln in einem Fach.",
                selection: Binding(
                    get: { draft.defaultEntrySort },
                    set: { newValue in update { $0.defaultEntrySort = newValue } }
                ),
                values: GradeEntrySort.allCases,
                label: { $0.title }
            )

            if draft.system != .grades {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Startwert des Reglers")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Spacer()
                        Text(gradeSliderPreview)
                            .font(.system(size: 13, weight: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { draft.defaultSliderFraction },
                            set: { newValue in update { $0.defaultSliderFraction = newValue } }
                        ),
                        in: 0...1,
                        step: 0.01
                    )
                    .tint(.mint)
                    Text("Wo der Regler beim Hinzufügen eines Eintrags startet. Standard ist die Mitte.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    private var gradeSliderPreview: String {
        let value = GradeMath.value(
            forSliderFraction: draft.defaultSliderFraction,
            unit: draft.system,
            maximumPoints: draft.maximumPoints
        )
        return GradeMath.valueText(value, unit: draft.system, maximumPoints: draft.maximumPoints)
    }

    /// Ein Auswahl-Menü für eine Liste von Werten mit Beschriftung.
    private func defaultPicker<Value: Hashable & Identifiable>(
        title: String,
        subtitle: String,
        selection: Binding<Value>,
        values: [Value],
        label: @escaping (Value) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .default))
                Spacer()
                Picker(title, selection: selection) {
                    ForEach(values) { value in
                        Text(label(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Hinweis

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                Text("So funktioniert's")
                    .font(.system(size: 14, weight: .regular, design: .default))
            }
            Text("Im Modus „Noten & Punkte“ tippst du auf ein Fach, um dessen Einträge zu sehen. Die gestrichelte Kachel mit dem Plus legt einen neuen Eintrag an, ein Tipp auf eine Kachel ändert ihn, langes Drücken bietet nur „Löschen“. Kacheln sind grün bei guten und rot bei schlechten Leistungen.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .lightCard(cornerRadius: 14, strokeOpacity: 0.18)
    }

    // MARK: - Zustand

    private func loadIfNeeded() {
        guard !didLoad else { return }
        draft = viewModel.gradeSettings
        didLoad = true
    }

    private func update(_ transform: (inout GradeSettings) -> Void) {
        var updated = draft
        transform(&updated)
        // Grenzen erneut anwenden (Höchstpunktzahl, Regler-Anteil).
        updated.maximumPoints = GradeSettings.clampedMaximumPoints(updated.maximumPoints)
        updated.defaultSliderFraction = GradeSettings.clampedFraction(updated.defaultSliderFraction)
        draft = updated
        viewModel.gradeSettings = updated
        viewModel.saveGradeSettings()
    }
}
