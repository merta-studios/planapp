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
        }
    }
}
