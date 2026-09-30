import SwiftUI

/// Hauptansicht der PlanApp: 6-spaltiger Stundenplan ohne Tabellenlinien mit Zebra-Schattierung
public struct TimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var dragOffset: CGFloat = 0
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false

    private let headerHeight: CGFloat = 58
    private let periodColumnWidth: CGFloat = 78

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height - 80 // Abzüglich Header
            let periodCount = max(1, viewModel.periods.count)
            // Dynamische Zeilenhöhe: passt sich automatisch an den Bildschirm an
            let calculatedRowHeight = max(82, (availableHeight - headerHeight) / CGFloat(periodCount))

            ZStack {
                // Hintergrund
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP HEADER (Navigation & Einstellungen)
                    TimetableHeaderView()

                    Divider()
                        .padding(.horizontal, 16)

                    // 2. HAUPTBILDSCHIRM: STUNDENPLAN-TABELLE (6 Spalten)
                    ScrollView([.vertical, .horizontal], showsIndicators: false) {
                        let schoolDays = viewModel.selectedWeekStart.schoolWeekDays()
                        let dayColumnWidth = max(160, (availableWidth - periodColumnWidth - 36) / 5)

                        HStack(alignment: .top, spacing: 4) {
                            // SPALTE 0: Stundennummern und Uhrzeiten
                            PeriodColumnView(
                                rowHeight: calculatedRowHeight,
                                headerHeight: headerHeight
                            )

                            // SPALTEN 1 bis 5: Wochentage (Montag - Freitag)
                            ForEach(Array(schoolDays.enumerated()), id: \.element) { index, day in
                                DayColumnView(
                                    day: day,
                                    columnIndex: index + 1,
                                    rowHeight: calculatedRowHeight,
                                    headerHeight: headerHeight
                                )
                                .frame(width: dayColumnWidth)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .offset(x: dragOffset)
                    }
                    // Wischgeste (Swipe Links / Rechts) zum Wechseln der Wochen
                    .gesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                            .onChanged { value in
                                // Nur horizontale Wischgesten berücksichtigen
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    dragOffset = value.translation.width * 0.4
                                }
                            }
                            .onEnded { value in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if value.translation.width < -70 {
                                        // Nach links wischen -> Nächste Woche
                                        viewModel.goToNextWeek()
                                    } else if value.translation.width > 70 {
                                        // Nach rechts wischen -> Vorherige Woche
                                        viewModel.goToPreviousWeek()
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                }

                // 3. TOAST-BENACHRICHTIGUNGEN
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            Text(msg)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(toastIsError ? Color.red : Color.blue)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // 4. ZEICHNEN- & NOTIZ-OVERLAY (PENCILKIT)
                if viewModel.isDrawingOverlayPresented, let activeLesson = viewModel.activeNoteLesson {
                    LessonDrawingOverlayView(lesson: activeLesson)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(100)
                }
            }
        }
        // Einstellungs-Sheet
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsView()
                .environmentObject(viewModel)
        }
        // Fehlermeldungen beobachten
        .onChange(of: viewModel.errorMessage) { _, newError in
            if let err = newError {
                showToast(err, isError: true)
                viewModel.errorMessage = nil
            }
        }
        // Erfolgsmeldungen beobachten
        .onChange(of: viewModel.successMessage) { _, newSuccess in
            if let succ = newSuccess {
                showToast(succ, isError: false)
                viewModel.successMessage = nil
            }
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.toastMessage = message
            self.toastIsError = isError
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }
}
