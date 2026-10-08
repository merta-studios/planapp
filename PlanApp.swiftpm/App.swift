import SwiftUI

@main
struct PlanApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TimetableViewModel()

    var body: some Scene {
        WindowGroup {
            TimetableView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.appearance.colorScheme)
                .coordinateSpace(name: GlobalCoordinateSpace.name)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // Frische Daten respektieren weiterhin „Sync beim Start“;
                    // veraltete Daten dürfen auf keinen Timer warten müssen.
                    guard phase == .active, viewModel.isTimetableStale() else { return }
                    Task(priority: .userInitiated) {
                        await viewModel.refreshTimetableIfNeeded()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Datei-Sync (iCloud Drive): Beim Öffnen fremde Stände
                    // holen, beim Verlassen eigene Änderungen sichern.
                    switch phase {
                    case .active:
                        Task(priority: .utility) {
                            await viewModel.fileSyncService.pullNow()
                        }
                    case .background:
                        Task(priority: .utility) {
                            await viewModel.fileSyncService.pushNow()
                        }
                    default:
                        break
                    }
                }
        }
    }
}
