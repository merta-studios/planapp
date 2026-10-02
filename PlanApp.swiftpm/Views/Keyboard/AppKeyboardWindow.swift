import SwiftUI
import UIKit
import Combine

/// Eine Tastaturebene pro App-Fenster, oberhalb aller darin präsentierten
/// Sheets. Das Fenster wird NIE zum Key-Window: Das eigentliche Textfeld
/// behält seinen Fokus und erhält die Eingaben weiterhin über TextInputHub.
@MainActor
final class AppKeyboardWindowPresenter {
    private weak var sourceWindow: UIWindow?
    private var keyboardWindow: AppKeyboardOverlayWindow?
    private var hostingController: UIHostingController<AppKeyboardWindowContent>?
    private var observation: AnyCancellable?
    private var isPresented = false

    private let hub = TextInputHub.shared

    init(sourceWindow: UIWindow) {
        self.sourceWindow = sourceWindow
        observation = hub.$isAppKeyboardVisible
            .combineLatest(hub.$activationCounter, hub.$systemKeyboardFrame)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.update()
            }
    }

    /// Wird auch bei Fenstergrößen- und Farbschema-Änderungen aufgerufen.
    func update() {
        guard let sourceWindow, let scene = sourceWindow.windowScene else { return }
        guard hub.isAppKeyboardVisible,
              hub.keyboardPresentationWindow?.windowScene === scene else {
            hide()
            return
        }

        let keyboardFrame = AppKeyboardLayout.frame(
            in: sourceWindow.bounds,
            systemKeyboardFrame: sourceWindow.convert(hub.systemKeyboardFrame, from: nil)
        )
        guard !keyboardFrame.isEmpty else {
            hide()
            return
        }
        var insets = sourceWindow.safeAreaInsets
        if keyboardFrame.maxY < sourceWindow.bounds.maxY - 1 {
            insets.bottom = 0 // Der Home-Indikator liegt unter der Systemtastatur.
        }

        if keyboardWindow == nil {
            let window = AppKeyboardOverlayWindow(windowScene: scene)
            let controller = UIHostingController(
                rootView: AppKeyboardWindowContent(keyboardFrame: keyboardFrame, safeAreaInsets: insets)
            )
            controller.view.backgroundColor = .clear
            controller.view.isOpaque = false
            // Die Ebene liegt am physischen Fensterrand und darf nicht durch
            // die Safe Area eines Sheets oder die Systemtastatur hochrutschen.
            controller.safeAreaRegions = []
            window.backgroundColor = .clear
            window.isOpaque = false
            window.rootViewController = controller
            keyboardWindow = window
            hostingController = controller
        }

        guard let window = keyboardWindow, let controller = hostingController else { return }
        if window.frame != sourceWindow.frame {
            window.frame = sourceWindow.frame
        }
        window.windowLevel = UIWindow.Level(rawValue: sourceWindow.windowLevel.rawValue + 1)
        window.overrideUserInterfaceStyle = sourceWindow.traitCollection.userInterfaceStyle
        window.tintColor = sourceWindow.tintColor
        window.keyboardFrame = keyboardFrame
        controller.rootView = AppKeyboardWindowContent(keyboardFrame: keyboardFrame, safeAreaInsets: insets)
        hub.updateAppKeyboardFrame(keyboardFrame, in: sourceWindow)

        guard !isPresented else { return }
        isPresented = true
        controller.view.transform = CGAffineTransform(translationX: 0, y: keyboardFrame.height)
        // Anders als makeKeyAndVisible() verändert dies den Eingabefokus nicht.
        window.isHidden = false
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            controller.view.transform = .identity
        }
    }

    private func hide() {
        if let sourceWindow {
            hub.updateAppKeyboardFrame(.zero, in: sourceWindow)
        }
        guard isPresented, let window = keyboardWindow, let controller = hostingController else { return }
        isPresented = false
        let height = window.keyboardFrame.height
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            controller.view.transform = CGAffineTransform(translationX: 0, y: height)
        } completion: { [weak self, weak window] _ in
            guard self?.isPresented == false else { return }
            window?.isHidden = true
        }
    }

    func tearDown() {
        observation?.cancel()
        observation = nil
        if let sourceWindow {
            hub.updateAppKeyboardFrame(.zero, in: sourceWindow)
        }
        keyboardWindow?.isHidden = true
        keyboardWindow?.rootViewController = nil
        hostingController = nil
        keyboardWindow = nil
        isPresented = false
    }
}

/// Nur der Tastaturbereich nimmt Berührungen entgegen. Oberhalb davon bleiben
/// die Einstellungen, die Notiz und deren Gesten ganz normal bedienbar.
private final class AppKeyboardOverlayWindow: UIWindow {
    var keyboardFrame: CGRect = .zero
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard keyboardFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct AppKeyboardWindowContent: View {
    let keyboardFrame: CGRect
    let safeAreaInsets: UIEdgeInsets

    var body: some View {
        GeometryReader { _ in
            AppKeyboardView(safeAreaInsets: safeAreaInsets)
                .frame(width: keyboardFrame.width, height: keyboardFrame.height)
                .position(x: keyboardFrame.midX, y: keyboardFrame.midY)
        }
        .ignoresSafeArea()
    }
}
