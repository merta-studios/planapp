import SwiftUI
import UIKit

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

    private var appTitle: some View {
        let neonBlue = Color(red: 0.10, green: 0.75, blue: 1.0)

        return HStack(spacing: 8) {
            appLogo
            Text("Untis Planner")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.primary)
            Text("PLUS")
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(neonBlue)
                .shadow(color: neonBlue.opacity(0.9), radius: 5, x: 0, y: 0)
                .shadow(color: neonBlue.opacity(0.55), radius: 12, x: 0, y: 0)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var appLogo: some View {
        Group {
            if let image = appLogoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "calendar")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("App-Logo")
    }

    /// Das Logo wird genau einmal geladen und danach zwischengespeichert.
    /// Der Header rendert sich durch seine `TimelineView` jede Sekunde neu –
    /// eine Bildsuche pro Render wäre unnötige Arbeit.
    ///
    /// Die Auflösung übernimmt `AppResources`, weil `Bundle.module` in einer
    /// Swift-Playgrounds-App nicht existiert (dort wird der SwiftPM-Accessor
    /// `resource_bundle_accessor.swift` nicht generiert).
    private static let cachedAppLogoImage: UIImage? = AppResources.image(named: "AppLogo")

    private var appLogoImage: UIImage? {
        Self.cachedAppLogoImage
    }

    /// Button direkt neben dem Titel: zeigt den aktuellen Ansichts-Modus und
    /// öffnet die Auswahl (Standard / Notizen hervorgehoben / Nur Notizen)
    /// mit Häkchen beim aktiven Modus.
    private var viewModeMenu: some View {
        Menu {
            ForEach(TimetableViewMode.allCases) { mode in
                Button {
                    Haptics.select()
                    viewModel.setViewMode(mode)
                } label: {
                    if viewModel.viewMode == mode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Label(mode.displayName, systemImage: mode.systemImage)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.viewMode.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(viewModel.viewMode.displayName)
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .liquidGlassButton(cornerRadius: 14, tint: viewModel.viewMode == .standard ? nil : .blue)
        .foregroundColor(.primary)
        .fixedSize()
        .accessibilityLabel("Ansichts-Modus: \(viewModel.viewMode.displayName)")
        .accessibilityHint("Öffnet die Auswahl des Ansichts-Modus")
    }

    /// Stiftname erscheint erst nach echtem Pencil-Input. Das verhindert ein
    /// leeres/irreführendes Feld, wenn kein Pencil verwendet wurde.
    @ViewBuilder
    private var applePencilStatus: some View {
        if let pencilName = viewModel.detectedApplePencilName {
            Text(pencilName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground).opacity(0.78))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel(pencilName)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    /// Kompakte Variante des Modus-Buttons (nur Symbol) für schmale Breiten.
    private var compactViewModeMenu: some View {
        Menu {
            ForEach(TimetableViewMode.allCases) { mode in
                Button {
                    Haptics.select()
                    viewModel.setViewMode(mode)
                } label: {
                    if viewModel.viewMode == mode {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Label(mode.displayName, systemImage: mode.systemImage)
                    }
                }
            }
        } label: {
            Image(systemName: viewModel.viewMode.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 34, height: 34)
        }
        .liquidGlassButton(cornerRadius: 17, tint: viewModel.viewMode == .standard ? nil : .blue)
        .fixedSize()
        .accessibilityLabel("Ansichts-Modus: \(viewModel.viewMode.displayName)")
    }

    private func regularHeader(relativeTo date: Date) -> some View {
        let showsJumpButton = !viewModel.isViewingRelevantCurrentWeek(relativeTo: date)

        return HStack(spacing: 14) {
            appTitle
            viewModeMenu
            applePencilStatus

            Spacer(minLength: 12)

            weekCard
                .layoutPriority(2)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if showsJumpButton {
                    jumpToCurrentWeekButton
                        .transition(
                            .scale(scale: 0.8)
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .trailing))
                        )
                }
                refreshBadge(
                    text: viewModel.relativeLastSyncString(relativeTo: date)
                )
                settingsButton
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showsJumpButton)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func compactHeader(relativeTo date: Date) -> some View {
        let showsJumpButton = !viewModel.isViewingRelevantCurrentWeek(relativeTo: date)

        return HStack(spacing: 8) {
            appLogo
            compactViewModeMenu
            applePencilStatus

            weekCard
                .layoutPriority(2)

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if showsJumpButton {
                    jumpToCurrentWeekButton
                        .transition(
                            .scale(scale: 0.8)
                                .combined(with: .opacity)
                                .combined(with: .move(edge: .trailing))
                        )
                }

                refreshBadge(text: compactRefreshString(relativeTo: date))
                    .fixedSize(horizontal: true, vertical: false)

                settingsButton
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showsJumpButton)
        }
    }

    /// Appears whenever the displayed week has no day that is "today" (this
    /// already accounts for weekends, where the relevant week is the next
    /// one), letting the user jump back with a single tap. Pressing it slides
    /// the carousel towards the current week instead of cross-fading.
    private var jumpToCurrentWeekButton: some View {
        Button {
            Haptics.tap()
            viewModel.requestJumpToCurrentWeek()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                Text("Heute")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .liquidGlassButton(cornerRadius: 16, tint: .blue, isFilled: true)
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
            Haptics.tap()
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
