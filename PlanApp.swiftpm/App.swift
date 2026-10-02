import SwiftUI

@main
struct PlanApp: App {
    @StateObject private var viewModel = TimetableViewModel()

    var body: some Scene {
        WindowGroup {
            TimetableView()
                .environmentObject(viewModel)
                .appKeyboardHost(monitorsTaps: !viewModel.isDrawingOverlayPresented)
        }
    }
}
