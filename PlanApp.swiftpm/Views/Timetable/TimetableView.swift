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

    /// Ob statt des (leeren) Stundenplans der Einrichtungs-Guide erscheint.
    ///
    /// Im Standard- und Notizen-hervorgehoben-Modus gilt das für die gerade
    /// sichtbare Woche; in „Nur Notizen“ für die App insgesamt (ohne Stunden
    /// gibt es dort auch keine Notizen).
    private var showsUntisSetupGuide: Bool {
        if viewModel.viewMode == .notesOnly {
            return viewModel.shouldShowUntisSetupGuideWithoutData
        }
        return viewModel.shouldShowUntisSetupGuide(for: viewModel.selectedWeekStart)
    }

    /// Filter-Auswahl direkt aus dem blauen Filter-Balken.
    @State private var isFilterEditorPresented = false

    /// Ob der große „Filter zurücksetzen“-Button unter der Kopfzeile steht.
    private var showsNotesFilterReset: Bool {
        viewModel.viewMode == .notesOnly && !viewModel.activeTagFilter.isEmpty
    }

    /// Namen der aktiven Filter-Tags für die Unterzeile des Buttons.
    private var activeFilterSummary: String {
        let names = viewModel.tagSettings.tags
            .filter { viewModel.activeTagFilter.contains($0.id) }
            .map(\.displayName)
        guard !names.isEmpty else {
            return viewModel.activeTagFilter.count == 1 ? "1 Tag aktiv" : "\(viewModel.activeTagFilter.count) Tags aktiv"
        }
        return names.joined(separator: ", ")
    }

    /// Großer Liquid-Glass-Button unterhalb der Kopfzeile: setzt im Modus
    /// „Nur Notizen“ alle Tag-Filter mit einem Tipp zurück.
    @ViewBuilder
    private var notesFilterResetBanner: some View {
        if showsNotesFilterReset {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        viewModel.activeTagFilter.removeAll()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aktive Filter:")
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                            Text(activeFilterSummary)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 6)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter zurücksetzen")
                .accessibilityHint("Entfernt alle Tag-Filter und zeigt wieder alle Notizen")

                // Schnellzugriff: die aktiven Filter direkt bearbeiten.
                Button {
                    Haptics.tap()
                    isFilterEditorPresented = true
                } label: {
                    Label("Filter bearbeiten", systemImage: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.blue.opacity(0.14))
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .padding(.trailing, 12)
                .accessibilityLabel("Filter bearbeiten")
            }
            .liquidGlassButton(cornerRadius: 22, tint: .blue)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .transition(
                .move(edge: .top)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96, anchor: .top))
            )
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height - 75
            let periodCount = max(1, viewModel.periods.count)
            // iPhone (und sehr schmale Fenster): kompakter Stundenplan mit
            // schmaleren Spalten, damit alle fünf Tage auf den Bildschirm passen.
            let isCompact = DeviceLayout.usesCompactTimetable(width: availableWidth)
            let headerHeight = DeviceLayout.timetableHeaderHeight(compact: isCompact)
            let periodColumnWidth = DeviceLayout.periodColumnWidth(compact: isCompact)
            let calculatedRowHeight = max(
                DeviceLayout.minimumRowHeight(compact: isCompact),
                (availableHeight - headerHeight) / CGFloat(periodCount)
            )

            ZStack {
                // Hintergrund
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP HEADER (Navigation & Einstellungen)
                    TimetableHeaderView()

                    // 1b. FILTER ZURÜCKSETZEN: Großer Liquid-Glass-Button
                    // direkt unter der Bar – bewusst nicht in die (engen)
                    // Kopfzeilen gequetscht. Erscheint nur im Modus
                    // „Nur Notizen“, sobald Tag-Filter aktiv sind.
                    notesFilterResetBanner

                    Divider()
                        .padding(.horizontal, 16)

                    // 2. HAUPTBILDSCHIRM: je nach Ansichts-Modus das
                    // 3-Wochen-Karussell oder die reine Notiz-Übersicht.
                    // Ohne (vollständige) API-Daten zeigt die Wochenansicht
                    // stattdessen den Einrichtungs-Guide – sie bleibt also nie
                    // einfach leer.
                    if showsUntisSetupGuide {
                        UntisSetupGuideView()
                    } else if viewModel.viewMode == .notesOnly {
                        // Kein Übergangs-Overlay: Ein animierter Wechsel hielt
                        // bisher das komplette Drei-Wochen-Raster neben der
                        // Vorschauübersicht gleichzeitig am Leben. Das führte
                        // besonders bei vielen handschriftlichen Notizen zu
                        // deutlichen Rucklern beim Umschalten.
                        NotesOverviewListView(noteNamespace: noteNamespace)
                    } else {
                        weekCarousel(
                            availableWidth: availableWidth,
                            calculatedRowHeight: calculatedRowHeight,
                            headerHeight: headerHeight,
                            periodColumnWidth: periodColumnWidth,
                            isCompact: isCompact
                        )
                    }
                }
                // Ein- und Ausblenden des Filter-Buttons folgt der Zustands-
                // änderung (Filter geleert bzw. gesetzt) ruhig und sichtbar.
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsNotesFilterReset)

                // 2b. LADE-ANZEIGE: Wird eine Woche zum ersten Mal von der API
                // geladen, dreht sich in der Mitte des Bildschirms ein
                // Lade-Symbol, bis die Daten (oder ein Fehler) da sind.
                if viewModel.isWeekPendingInitialLoad(viewModel.selectedWeekStart) {
                    WeekLoadingOverlay()
                        .transition(.opacity)
                        .zIndex(60)
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
        // Die Hauptansicht weicht keiner Systemtastatur aus: Die App bringt
        // ihre eigene Tastatur mit, und der Stundenplan bzw. die Notiz darf
        // beim Tippen weder verkleinert noch nach oben geschoben werden.
        // (In den Einstellungen und Sheets gilt weiterhin die eingebettete
        // Tastatur mit eigenem Abstand – sie liegen in einer eigenen Hierarchie.)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Einstellungs-Sheet
        .sheet(isPresented: $isFilterEditorPresented) {
            TagFilterSheet()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsView()
                .environmentObject(viewModel)
                // Der große Detent hält das Einstellungsfenster bündig am
                // unteren Bildschirmrand. Die eingebettete App-Tastatur sitzt
                // dadurch auch beim Bearbeiten in den Einstellungen dort und
                // nicht innerhalb einer kleinen, schwebenden Sheet-Karte.
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    private func weekCarousel(
        availableWidth: CGFloat,
        calculatedRowHeight: CGFloat,
        headerHeight: CGFloat,
        periodColumnWidth: CGFloat,
        isCompact: Bool
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // VORHERIGE WOCHE (immer links vorgerendert bereit)
                SingleWeekGridView(
                    weekStart: previousWeekStart,
                    availableWidth: availableWidth,
                    calculatedRowHeight: calculatedRowHeight,
                    headerHeight: headerHeight,
                    periodColumnWidth: periodColumnWidth,
                    isCompact: isCompact,
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
                    isCompact: isCompact,
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
                    isCompact: isCompact,
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

/// Drehendes Lade-Symbol in der Mitte des Bildschirms.
///
/// Es erscheint, sobald zu einer Woche noch keine Daten von der API geladen
/// wurden, und bleibt sichtbar, bis der Abgleich abgeschlossen ist. Tipps
/// gehen weiter an den Stundenplan durch (der Nutzer darf weiterwischen).
struct WeekLoadingOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)

            Text("Stundenplan wird geladen …")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stundenplan wird geladen")
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
    let isCompact: Bool
    let noteNamespace: Namespace.ID

    var body: some View {
        let schoolDays = weekStart.schoolWeekDays()
        let dayColumnWidth = DeviceLayout.dayColumnWidth(availableWidth: availableWidth, compact: isCompact)

        HStack(alignment: .top, spacing: isCompact ? 2 : 4) {
            // SPALTE 0: Stundennummern und Uhrzeiten
            PeriodColumnView(
                rowHeight: calculatedRowHeight,
                headerHeight: headerHeight,
                width: periodColumnWidth,
                isCompact: isCompact
            )

            // SPALTEN 1 bis 5: Wochentage (Montag - Freitag)
            ForEach(Array(schoolDays.enumerated()), id: \.element) { index, day in
                DayColumnView(
                    day: day,
                    columnIndex: index + 1,
                    rowHeight: calculatedRowHeight,
                    headerHeight: headerHeight,
                    isCompact: isCompact,
                    noteNamespace: noteNamespace
                )
                .frame(width: dayColumnWidth)
            }
        }
        .padding(.horizontal, isCompact ? 4 : 16)
        .padding(.vertical, 8)
    }
}
