import SwiftUI
import UIKit

/// Ein teilbares Bild als `Identifiable`-Hülle, damit es über
/// `.sheet(item:)` präsentiert werden kann.
public struct ShareImageItem: Identifiable {
    public let id = UUID()
    public let image: UIImage

    public init(image: UIImage) {
        self.image = image
    }
}

/// Dünner Wrapper um `UIActivityViewController` (System-Teilen-Dialog).
public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // Auf dem iPad braucht der Dialog eine Ankerfläche, sonst bricht
        // UIKit die Präsentation ab. Innerhalb eines Sheets genügt die
        // eigene View als Anker.
        controller.popoverPresentationController?.permittedArrowDirections = []
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        if let popover = uiViewController.popoverPresentationController,
           popover.sourceView == nil,
           let view = uiViewController.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 0,
                height: 0
            )
        }
    }
}
