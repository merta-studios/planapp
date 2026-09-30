import SwiftUI

/// Kopfzeile des Stundenplans mit Wochen-Navigation, Untis-Status und Einstellungs-Button
public struct TimetableHeaderView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public init() {}

    public var body: some View {
        HStack(spacing: 16) {
            // App-Titel & Icon
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)

                Text("PlanApp")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
            }
            .hoverEffect(.lift)

            Spacer()

            // WOCHEN-NAVIGATION
            HStack(spacing: 8) {
                // Vorherige Woche Button
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color(UIColor.secondarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)

                // Aktuelle Kalenderwoche & Datumsbereich
                VStack(spacing: 2) {
                    Text(viewModel.selectedWeekStart.calendarWeekString)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(viewModel.selectedWeekStart.weekRangeString())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)

                // Nächste Woche Button
                Button(action: { viewModel.goToNextWeek() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(Color(UIColor.secondarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)

                // "Heute" Sprung-Button
                Button(action: { viewModel.goToCurrentWeek() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("Heute")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.75))
            )

            Spacer()

            // RECHTE LEISTE (Sync & Einstellungen)
            HStack(spacing: 10) {
                // Untis Sync Button
                if viewModel.untisCredentials.isConfigured {
                    Button(action: {
                        Task { await viewModel.syncWithUntis() }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(Color(UIColor.secondarySystemFill))
                        .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                    .disabled(viewModel.isLoading)
                }

                // Einstellungs-Button (oben rechts)
                Button(action: { viewModel.isSettingsPresented = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color(UIColor.secondarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
