import SwiftUI

/// Persistent timetable header. Week, last refresh and settings always remain
/// visible; only the decorative app title is removed on compact widths.
public struct TimetableHeaderView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        // While Settings (or the drawing overlay) covers the screen this
        // header isn't visible, so there is no reason to keep re-rendering it
        // every second. That per-second tick was forcing constant relayout of
        // this whole (Liquid-Glass / material heavy) header underneath the
        // sheet, which is exactly what made the UI feel laggy while Settings
        // was open.
        let tickInterval: TimeInterval = (viewModel.isSettingsPresented || viewModel.isDrawingOverlayPresented) ? 300 : 1
        TimelineView(.periodic(from: .now, by: tickInterval)) { timeline in
            ViewThatFits(in: .horizontal) {
                regularHeader(relativeTo: timeline.date)
                compactHeader(relativeTo: timeline.date)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(.ultraThinMaterial)
        .zIndex(50)
    }

    private func regularHeader(relativeTo date: Date) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.blue)
                Text("PlanApp")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if !viewModel.isViewingRelevantCurrentWeek(relativeTo: date) {
                    jumpToCurrentWeekButton
                        .transition(.scale.combined(with: .opacity))
                }
                weekCard
            }
            .layoutPriority(2)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                refreshBadge(
                    text: viewModel.relativeLastSyncString(relativeTo: date)
                )
                settingsButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func compactHeader(relativeTo date: Date) -> some View {
        HStack(spacing: 8) {
            if !viewModel.isViewingRelevantCurrentWeek(relativeTo: date) {
                jumpToCurrentWeekButton
                    .transition(.scale.combined(with: .opacity))
            }

            weekCard
                .layoutPriority(2)

            Spacer(minLength: 4)

            refreshBadge(text: compactRefreshString(relativeTo: date))
                .fixedSize(horizontal: true, vertical: false)

            settingsButton
        }
    }

    /// Appears whenever the displayed week has no day that is "today" (this
    /// already accounts for weekends, where the relevant week is the next
    /// one), letting the user jump back with a single tap.
    private var jumpToCurrentWeekButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                viewModel.goToCurrentWeek()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Heute")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .liquidGlassButton(cornerRadius: 14, tint: .blue, isFilled: true)
        .foregroundColor(.white)
        .fixedSize()
        .accessibilityLabel("Zur aktuellen Woche springen")
    }

    private var weekCard: some View {
        VStack(spacing: 2) {
            Text(viewModel.selectedWeekStart.calendarWeekString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(viewModel.selectedWeekStart.weekRangeString())
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.25)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.selectedWeekStart.calendarWeekString), \(viewModel.selectedWeekStart.weekRangeString())"
        )
    }

    private func refreshBadge(text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0.15, green: 0.75, blue: 0.35))
                .frame(width: 7, height: 7)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.10, green: 0.62, blue: 0.28))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color(red: 0.15, green: 0.75, blue: 0.35).opacity(0.13))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    Color(red: 0.15, green: 0.75, blue: 0.35).opacity(0.28),
                    lineWidth: 1
                )
        )
        .accessibilityLabel("Letzte Aktualisierung: \(viewModel.relativeLastSyncString())")
    }

    private var settingsButton: some View {
        Button {
            viewModel.isSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
        }
        .liquidGlassButton(cornerRadius: 20)
        .accessibilityLabel("Einstellungen")
        .fixedSize()
    }

    private func compactRefreshString(relativeTo now: Date) -> String {
        let lastDate = viewModel.lastSyncDate
            ?? viewModel.untisCredentials.lastSyncDate
            ?? now
        let seconds = max(0, Int(now.timeIntervalSince(lastDate)))

        if seconds < 5 { return "Jetzt" }
        if seconds < 60 { return "\(seconds) s" }
        return "\(seconds / 60) min"
    }
}
