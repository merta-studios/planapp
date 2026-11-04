import SwiftUI

/// Ansichts-Modus „Noten & Punkte“ (Einstellungen → „Noten & Punkte“).
///
/// Zeigt **alle eigenen Fächer** aus „Fächer & Farben“ als farbige Karten in
/// der Hintergrundfarbe des Fachs (einfarbig oder Verlauf – je nach
/// Einstellung in „Fächer & Farben“) mit dem Durchschnitt in einem Kreis.
/// Ein Tipp öffnet die Kachel-Übersicht eines Fachs.
///
/// Die Sortierung übernimmt die Kopfzeile („Sortieren nach“) – hier wird nur
/// angezeigt.
struct GradesOverviewView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    /// Fach, dessen Einträge gerade offen sind.
    @State private var openedSubject: SubjectCustomization? = nil

    var body: some View {
        Group {
            if viewModel.gradeSubjects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: columns,
                        spacing: DeviceLayout.isPhone ? 10 : 14
                    ) {
                        ForEach(viewModel.gradeSubjects) { subject in
                            Button {
                                Haptics.tap()
                                openedSubject = subject
                            } label: {
                                subjectRow(subject)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DeviceLayout.isPhone ? 12 : 20)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .sheet(item: $openedSubject) { subject in
            GradeSubjectDetailView(subject: subject)
                .environmentObject(viewModel)
        }
    }

    private var columns: [GridItem] {
        if DeviceLayout.isPhone {
            return [GridItem(.flexible(), spacing: 10)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)
    }

    // MARK: - Zeile eines Fachs

    private func subjectRow(_ subject: SubjectCustomization) -> some View {
        let display = viewModel.resolveSubjectDisplay(for: subject)
        let average = viewModel.gradeAverageText(for: subject)
        let entryCount = viewModel.gradeEntries(for: subject).count

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(display.name)
                    .font(.system(size: DeviceLayout.isPhone ? 15 : 17, weight: .semibold, design: .default))
                    .foregroundColor(.black.opacity(0.86))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(entryCount == 0
                     ? "Noch keine Einträge"
                     : (entryCount == 1 ? "1 Eintrag" : "\(entryCount) Einträge"))
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.black.opacity(0.55))
            }

            Spacer(minLength: 6)

            // Durchschnitt im Kreis.
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.92))
                Circle()
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                Text(average)
                    .font(.system(size: DeviceLayout.isPhone ? 18 : 21, weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(entryCount == 0 ? 0.3 : 0.82))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .frame(width: DeviceLayout.isPhone ? 52 : 60, height: DeviceLayout.isPhone ? 52 : 60)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subjectBackground(display))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(display.name), Durchschnitt \(average)")
    }

    @ViewBuilder
    private func subjectBackground(_ display: SubjectDisplay) -> some View {
        if let end = display.gradientEndColor {
            LinearGradient(colors: [display.color, end], startPoint: .top, endPoint: .bottom)
        } else {
            display.color
        }
    }

    // MARK: - Leerer Zustand

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "paintpalette")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text("Noch keine Fächer angelegt")
                .font(.system(size: 16, weight: .medium, design: .default))
            Text("Lege in den Einstellungen unter „Fächer & Farben“ deine Fächer an – sie erscheinen dann hier mit ihren Noten.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Button {
                Haptics.tap()
                viewModel.isSettingsPresented = true
            } label: {
                Text("Einstellungen öffnen")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .lightButton(cornerRadius: 12, tint: .mint, isFilled: true)
            .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
