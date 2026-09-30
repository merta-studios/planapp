import SwiftUI

private enum WeekSwipeAxis: Equatable {
    case horizontal
    case vertical
}

/// Hauptansicht der PlanApp: Stundenplan mit flüssigem 3-Wochen-Karussell und Liquid-Glass Design
public struct TimetableView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var dragOffset: CGFloat = 0
    @State private var weekSwipeAxis: WeekSwipeAxis?
    @State private var isSettlingWeek = false
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
                        // The current week starts in the middle. dragOffset is
                        // updated for every finger movement, so adjacent weeks
                        // visibly follow the gesture instead of jumping on lift.
                        .offset(x: -availableWidth + dragOffset)
                        .frame(width: availableWidth, alignment: .leading)
                        .clipped()
                    }
                    .scrollDisabled(weekSwipeAxis == .horizontal || isSettlingWeek)
                    .contentShape(Rectangle())
                    // A high-priority recognizer prevents the vertical scroll
                    // view from swallowing diagonal week swipes. Direction is
                    // locked with generous tolerance after a few points.
                    .highPriorityGesture(weekSwipeGesture(pageWidth: availableWidth))
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

    private func weekSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                guard !isSettlingWeek else { return }

                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                if weekSwipeAxis == nil, max(horizontal, vertical) > 7 {
                    // Horizontal intent remains valid even with a pronounced
                    // diagonal component (roughly up to 60 degrees).
                    if horizontal >= vertical * 0.55 {
                        weekSwipeAxis = .horizontal
                    } else if vertical >= horizontal * 1.45 {
                        weekSwipeAxis = .vertical
                    }
                }

                guard weekSwipeAxis == .horizontal else { return }

                let rawOffset = value.translation.width
                if abs(rawOffset) <= pageWidth {
                    dragOffset = rawOffset
                } else {
                    // Soft resistance when dragging past the prepared page.
                    let overflow = abs(rawOffset) - pageWidth
                    dragOffset = rawOffset < 0
                        ? -(pageWidth + overflow * 0.16)
                        : pageWidth + overflow * 0.16
                }
            }
            .onEnded { value in
                defer { weekSwipeAxis = nil }
                guard weekSwipeAxis == .horizontal, !isSettlingWeek else {
                    if dragOffset != 0 {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            dragOffset = 0
                        }
                    }
                    return
                }

                let distance = value.translation.width
                let projectedDistance = value.predictedEndTranslation.width
                let crossedDistanceThreshold = abs(distance) > max(44, pageWidth * 0.12)
                let hasFlickVelocity = abs(projectedDistance) > max(90, pageWidth * 0.28)

                guard crossedDistanceThreshold || hasFlickVelocity else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                    return
                }

                isSettlingWeek = true
                let directionValue = abs(distance) > 8 ? distance : projectedDistance
                let movingToNext = directionValue < 0
                let targetOffset: CGFloat = movingToNext ? -pageWidth : pageWidth

                withAnimation(.interactiveSpring(response: 0.27, dampingFraction: 0.90)) {
                    dragOffset = targetOffset
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                    if movingToNext {
                        viewModel.goToNextWeek()
                    } else {
                        viewModel.goToPreviousWeek()
                    }

                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        dragOffset = 0
                        isSettlingWeek = false
                    }
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
