import SwiftUI

/// Hauptansicht der PlanApp: Stundenplan mit flüssigem 3-Wochen-Karussell und Liquid-Glass Design
public struct TimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var dragOffset: CGFloat = 0
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false
    @Namespace private var noteNamespace

    private let headerHeight: CGFloat = 54
    private let periodColumnWidth: CGFloat = 76

    public init() {}

    private var previousWeekStart: Date {
        Calendar.germanCalendar.date(byAdding: .day, value: -7, to: viewModel.selectedWeekStart) ?? viewModel.selectedWeekStart
    }

    private var nextWeekStart: Date {
        Calendar.germanCalendar.date(byAdding: .day, value: 7, to: viewModel.selectedWeekStart) ?? viewModel.selectedWeekStart
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height - 75
            let periodCount = max(1, viewModel.periods.count)
            let calculatedRowHeight = max(80, (availableHeight - headerHeight) / CGFloat(periodCount))

            ZStack {
                // Hintergrund
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP HEADER (Navigation & Einstellungen)
                    TimetableHeaderView()

                    Divider()
                        .padding(.horizontal, 16)

                    // 2. HAUPTBILDSCHIRM: VORBEREITETES 3-WOCHEN-KARUSSELL (Vorherige, Aktuelle, Nächste Woche)
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            // VORHERIGE WOCHE (immer links vorgerendert bereit)
                            SingleWeekGridView(
                                weekStart: previousWeekStart,
                                availableWidth: availableWidth,
                                calculatedRowHeight: calculatedRowHeight,
                                headerHeight: headerHeight,
                                periodColumnWidth: periodColumnWidth,
                                noteNamespace: noteNamespace
                            )
                            .frame(width: availableWidth)

                            // AKTUELLE WOCHE
                            SingleWeekGridView(
                                weekStart: viewModel.selectedWeekStart,
                                availableWidth: availableWidth,
                                calculatedRowHeight: calculatedRowHeight,
                                headerHeight: headerHeight,
                                periodColumnWidth: periodColumnWidth,
                                noteNamespace: noteNamespace
                            )
                            .frame(width: availableWidth)

                            // NÄCHSTE WOCHE (immer rechts vorgerendert bereit)
                            SingleWeekGridView(
                                weekStart: nextWeekStart,
                                availableWidth: availableWidth,
                                calculatedRowHeight: calculatedRowHeight,
                                headerHeight: headerHeight,
                                periodColumnWidth: periodColumnWidth,
                                noteNamespace: noteNamespace
                            )
                            .frame(width: availableWidth)
                        }
                        // Die aktuelle Woche ist in der Mitte platziert (-availableWidth)
                        .offset(x: -availableWidth + dragOffset)
                    }
                    // Realistische 1:1 Echtzeit-Wischgeste (Interactive Swiping)
                    .gesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .local)
                            .onChanged { value in
                                // Nur horizontale Bewegung tracken
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                let horizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                                let threshold: CGFloat = max(60, availableWidth * 0.15)

                                guard horizontalSwipe, abs(value.translation.width) > threshold else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        dragOffset = 0
                                    }
                                    return
                                }

                                let movingToNext = value.translation.width < 0
                                let targetOffset: CGFloat = movingToNext ? -availableWidth : availableWidth

                                withAnimation(.easeOut(duration: 0.22)) {
                                    dragOffset = targetOffset
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    if movingToNext {
                                        viewModel.goToNextWeek()
                                    } else {
                                        viewModel.goToPreviousWeek()
                                    }

                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }

                // 3. TOAST-BENACHRICHTIGUNGEN
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: toastIsError ? "exclamationmark.triangle" : "checkmark.circle")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text(msg)
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(toastIsError ? Color.red.opacity(0.9) : Color.blue.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // 4. ZEICHNEN- & NOTIZ-OVERLAY (PENCILKIT)
                if viewModel.isDrawingOverlayPresented, let activeLesson = viewModel.activeNoteLesson {
                    LessonDrawingOverlayView(lesson: activeLesson, noteNamespace: noteNamespace)
                        .transition(.identity)
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

/// Einzelne Wochen-Tabelle zur nahtlosen Vorbereitung im Wochen-Karussell
struct SingleWeekGridView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    let weekStart: Date
    let availableWidth: CGFloat
    let calculatedRowHeight: CGFloat
    let headerHeight: CGFloat
    let periodColumnWidth: CGFloat
    let noteNamespace: Namespace.ID

    var body: some View {
        let schoolDays = weekStart.schoolWeekDays()
        let dayColumnWidth = max(120, (availableWidth - periodColumnWidth - 36) / 5)

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
                    headerHeight: headerHeight,
                    noteNamespace: noteNamespace
                )
                .frame(width: dayColumnWidth)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
