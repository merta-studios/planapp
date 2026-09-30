import SwiftUI

/// Hauptansicht der PlanApp: Stundenplan mit flüssigem 3-Wochen-Karussell und Liquid-Glass Design
public struct TimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var dragOffset: CGFloat = 0
    @State private var isSettlingWeek = false
    // Beim "Heute"-Sprung wird die Nachbarseite vorübergehend durch die
    // Zielwoche ersetzt, damit auch Sprünge über mehrere Wochen hinweg die
    // korrekte Woche hereinrutschen sehen.
    @State private var jumpNeighborWeek: Date? = nil
    @State private var jumpDirection: Int = 0
    @State private var toastMessage: String? = nil
    @State private var toastIsError: Bool = false
    @Namespace private var noteNamespace

    private let headerHeight: CGFloat = 54
    private let periodColumnWidth: CGFloat = 76

    public init() {}

    private var previousWeekStart: Date {
        if jumpDirection == -1, let jumpNeighborWeek {
            return jumpNeighborWeek
        }
        return Calendar.germanCalendar.date(byAdding: .day, value: -7, to: viewModel.selectedWeekStart) ?? viewModel.selectedWeekStart
    }

    private var nextWeekStart: Date {
        if jumpDirection == 1, let jumpNeighborWeek {
            return jumpNeighborWeek
        }
        return Calendar.germanCalendar.date(byAdding: .day, value: 7, to: viewModel.selectedWeekStart) ?? viewModel.selectedWeekStart
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

                    // 2. HAUPTBILDSCHIRM: je nach Ansichts-Modus das
                    // 3-Wochen-Karussell oder die reine Notiz-Übersicht.
                    if viewModel.viewMode == .notesOnly {
                        NotesOverviewListView(noteNamespace: noteNamespace)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else {
                        weekCarousel(availableWidth: availableWidth, calculatedRowHeight: calculatedRowHeight)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }
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
            // "Heute"-Button: Woche rutscht animiert in die richtige Richtung
            // statt überblendet zu werden.
            .onChange(of: viewModel.weekJumpRequest) { _, newValue in
                guard let target = newValue else { return }
                viewModel.weekJumpRequest = nil
                performJump(to: target, pageWidth: availableWidth)
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

    // MARK: - Wochen-Karussell (Standard & Notizen hervorgehoben)

    /// Das vorbereitete 3-Wochen-Karussell (vorherige, aktuelle, nächste Woche).
    private func weekCarousel(availableWidth: CGFloat, calculatedRowHeight: CGFloat) -> some View {
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
            // The current week starts in the middle. dragOffset is
            // updated for every finger movement, so adjacent weeks
            // visibly follow the gesture instead of jumping on lift.
            .offset(x: -availableWidth + dragOffset)
            .frame(width: availableWidth, alignment: .leading)
            .clipped()
            // A UIKit pan recognizer on the enclosing scroll view
            // makes horizontal swiping track the finger even when
            // the swipe starts on top of a (tappable) lesson block.
            .background(
                WeekPanGestureAttachment(
                    onChanged: { translation in
                        handleWeekPanChanged(translation, pageWidth: availableWidth)
                    },
                    onEnded: { translation, velocity in
                        handleWeekPanEnded(translation, velocity: velocity, pageWidth: availableWidth)
                    },
                    isEnabled: !isSettlingWeek && !viewModel.isDrawingOverlayPresented
                )
            )
        }
        .scrollDisabled(isSettlingWeek)
    }

    // MARK: - Wochen-Wischen (kontinuierlich, folgt dem Finger)

    private func handleWeekPanChanged(_ translation: CGFloat, pageWidth: CGFloat) {
        guard !isSettlingWeek else { return }

        if abs(translation) <= pageWidth {
            dragOffset = translation
        } else {
            // Soft resistance when dragging past the prepared page.
            let overflow = abs(translation) - pageWidth
            dragOffset = translation < 0
                ? -(pageWidth + overflow * 0.16)
                : pageWidth + overflow * 0.16
        }
    }

    private func handleWeekPanEnded(_ translation: CGFloat, velocity: CGFloat, pageWidth: CGFloat) {
        guard !isSettlingWeek else { return }

        // Abgebrochene Geste ohne Bewegung: nur zurückfedern.
        guard translation != 0 || velocity != 0 else {
            if dragOffset != 0 {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
            }
            return
        }

        let projectedDistance = translation + velocity * 0.2
        let crossedDistanceThreshold = abs(translation) > max(44, pageWidth * 0.12)
        let hasFlickVelocity = abs(velocity) > 220 && abs(projectedDistance) > max(90, pageWidth * 0.20)

        guard crossedDistanceThreshold || hasFlickVelocity else {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                dragOffset = 0
            }
            return
        }

        let directionValue = abs(translation) > 8 ? translation : projectedDistance
        let movingToNext = directionValue < 0
        settleWeek(movingToNext: movingToNext, pageWidth: pageWidth) {
            if movingToNext {
                viewModel.goToNextWeek()
            } else {
                viewModel.goToPreviousWeek()
            }
        }
    }

    /// Animiert das Karussell eine Seite weiter und tauscht anschließend die
    /// Wochen ohne sichtbaren Sprung aus.
    private func settleWeek(movingToNext: Bool, pageWidth: CGFloat, completion: @escaping () -> Void) {
        isSettlingWeek = true
        let targetOffset: CGFloat = movingToNext ? -pageWidth : pageWidth

        withAnimation(.interactiveSpring(response: 0.27, dampingFraction: 0.90)) {
            dragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
            completion()

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
                jumpNeighborWeek = nil
                jumpDirection = 0
                isSettlingWeek = false
            }
        }
    }

    /// Rutscht animiert zur Zielwoche (z.B. beim "Heute"-Button). Die
    /// Zielwoche wird dafür auf der passenden Nachbarseite vorbereitet.
    private func performJump(to target: Date, pageWidth: CGFloat) {
        guard target != viewModel.selectedWeekStart else { return }
        guard !isSettlingWeek else {
            viewModel.selectWeek(target)
            return
        }

        let movingToNext = target > viewModel.selectedWeekStart
        jumpDirection = movingToNext ? 1 : -1
        jumpNeighborWeek = target

        settleWeek(movingToNext: movingToNext, pageWidth: pageWidth) {
            viewModel.selectWeek(target)
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
        let horizontalPadding: CGFloat = 32
        let totalColumnSpacing: CGFloat = 20
        let dayColumnWidth = max(
            120,
            (availableWidth - horizontalPadding - periodColumnWidth - totalColumnSpacing) / 5
        )

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
