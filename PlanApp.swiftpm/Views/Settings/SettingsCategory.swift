import SwiftUI

/// Die Kategorien der Einstellungen.
///
/// Die Startseite zeigt nur diese Liste; alle Details einer Kategorie liegen
/// auf einer eigenen Seite – so wie man es aus System-Apps kennt.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case timetable
    case subjects
    case teachers
    case drawing
    case untis
    case appearance
    case tags
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timetable: return "Stundenplan & Zeiten"
        case .subjects: return "Fächer & Farben"
        case .teachers: return "Lehrkräfte"
        case .drawing: return DeviceLayout.isPhone ? "Notizen & Zeichenfläche" : "Zeichnen & Apple Pencil"
        case .untis: return "WebUntis & Sync"
        case .appearance: return "Darstellung"
        case .tags: return "Tag-System"
        case .data: return "Daten & Zurücksetzen"
        }
    }

    var subtitle: String {
        switch self {
        case .timetable: return "Stundenraster, Uhrzeiten und Block-Inhalte"
        case .subjects: return "Namen ersetzen und Farben festlegen"
        case .teachers: return "Kürzel durch Klarnamen ersetzen"
        case .drawing: return DeviceLayout.isPhone ? "Notizgröße, Hintergrund und Aufräumen" : "Stiftdicken, Notizgröße und Pencil-Gesten"
        case .untis: return "Zugangsdaten und Synchronisation"
        case .appearance: return "Erscheinungsbild (hell, dunkel, automatisch)"
        case .tags: return "Notizen mit farbigen Tags markieren und filtern"
        case .data: return "Export, Import, Stundenplan und gespeicherte Daten"
        }
    }

    var icon: String {
        switch self {
        case .timetable: return "calendar"
        case .subjects: return "paintpalette"
        case .teachers: return "person.text.rectangle"
        case .drawing: return "pencil.and.outline"
        case .untis: return "network"
        case .appearance: return "circle.lefthalf.filled"
        case .tags: return "tag"
        case .data: return "trash"
        }
    }

    var tint: Color {
        switch self {
        case .timetable: return .blue
        case .subjects: return .purple
        case .teachers: return .teal
        case .drawing: return .orange
        case .untis: return .green
        case .appearance: return .cyan
        case .tags: return .indigo
        case .data: return .red
        }
    }
}

/// Detailseite einer Kategorie mit allen zugehörigen Einstellungen.
struct SettingsCategoryDetailView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    let category: SettingsCategory

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: DeviceLayout.isPhone ? 14 : 20) {
                switch category {
                case .timetable:
                    PeriodConfigSection()
                    BlockDisplaySettingsSection()

                case .subjects:
                    SubjectCustomizationSection()

                case .teachers:
                    TeacherCustomizationSection()

                case .drawing:
                    DrawingSettingsSection()
                    if !DeviceLayout.isPhone {
                        PencilGesturesSection()
                    }

                case .untis:
                    UntisConfigSection()

                case .appearance:
                    AppearanceSettingsSection()

                case .tags:
                    TagSystemSettingsSection()

                case .data:
                    DataTransferSection()
                    clearTimetableCard
                }
            }
            .padding(.horizontal, DeviceLayout.isPhone ? 12 : 20)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .scrollDismissesKeyboard(.never)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        // „Fertig“ schließt die komplette Einstellungen-Seite – auch von einer
        // Unterseite aus, ohne erst zurücknavigieren zu müssen.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Haptics.tap()
                    viewModel.isSettingsPresented = false
                }) {
                    Text("Fertig")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .liquidGlassButton(cornerRadius: 10, tint: .blue, isFilled: true)
                .foregroundColor(.white)
            }
        }
    }

    private var clearTimetableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.red)
                Text("Stundenplan zurücksetzen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Text("Entfernt den geladenen Stundenplan aus der App. Zugangsdaten, Fächer-Anpassungen und Notizen bleiben erhalten.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                Haptics.warning()
                viewModel.clearTimetable()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text("Stundenplan leeren")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .liquidGlassButton(cornerRadius: 14, tint: .red)
            .foregroundColor(.red)
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .liquidGlassCard(cornerRadius: 16, strokeOpacity: 0.25)
    }
}
