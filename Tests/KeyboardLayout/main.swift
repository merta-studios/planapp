import Foundation

// Ohne UIKit/SwiftUI ausführbare Regressionstests der tatsächlich von der
// App verwendeten Fenster-/Tastenmaße. Auf einem Mac mit Swift starten:
// swiftc PlanApp.swiftpm/Views/Keyboard/AppKeyboardLayout.swift \
//     Tests/KeyboardLayout/main.swift -o /tmp/planapp-keyboard-layout-tests
// /tmp/planapp-keyboard-layout-tests

private var checks = 0

private func expect(_ actual: CGFloat, _ expected: CGFloat, _ name: String) {
    precondition(abs(actual - expected) < 0.001, "\(name): \(actual) != \(expected)")
    checks += 1
}

private func expect(_ actual: CGRect, _ expected: CGRect, _ name: String) {
    precondition(actual == expected, "\(name): \(actual) != \(expected)")
    checks += 1
}

let portrait = CGRect(x: 0, y: 0, width: 1024, height: 1366)
let portraitKeyboard = AppKeyboardLayout.frame(in: portrait)
expect(portraitKeyboard, CGRect(x: 0, y: 683, width: 1024, height: 683), "iPad Hochformat")

let landscape = CGRect(x: 0, y: 0, width: 1366, height: 1024)
let landscapeKeyboard = AppKeyboardLayout.frame(in: landscape)
expect(landscapeKeyboard, CGRect(x: 0, y: 512, width: 1366, height: 512), "iPad Querformat")

let splitView = CGRect(x: 0, y: 0, width: 507, height: 1024)
expect(AppKeyboardLayout.frame(in: splitView), CGRect(x: 0, y: 512, width: 507, height: 512), "Split View: App-Fenster statt UIScreen")
expect(AppKeyboardLayout.frame(in: CGRect(x: 10, y: 20, width: 800, height: 600)), CGRect(x: 10, y: 320, width: 800, height: 300), "Bounds mit Ursprung")
expect(AppKeyboardLayout.frame(in: .zero), .zero, "Noch kein Fensterlayout")
expect(AppKeyboardLayout.frame(in: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 600)), .zero, "Ungültige Maße")

expect(
    AppKeyboardLayout.frame(in: landscape, systemKeyboardFrame: CGRect(x: 0, y: 700, width: 1366, height: 324)),
    CGRect(x: 0, y: 350, width: 1366, height: 350),
    "Immer anzeigen: zusätzlich oberhalb der Systemtastatur"
)
expect(
    AppKeyboardLayout.frame(in: landscape, systemKeyboardFrame: CGRect(x: 0, y: 980, width: 1366, height: 44)),
    CGRect(x: 0, y: 490, width: 1366, height: 490),
    "Hardware-Kurzbefehlsstreifen verdeckt keine Tasten"
)
expect(
    AppKeyboardLayout.frame(in: landscape, systemKeyboardFrame: CGRect(x: 400, y: 784, width: 320, height: 240)),
    landscapeKeyboard,
    "Schwebende iPad-Systemtastatur verkleinert die App-Tastatur nicht"
)
expect(
    AppKeyboardLayout.frame(in: landscape, systemKeyboardFrame: CGRect(x: 0, y: 1024, width: 1366, height: 324)),
    landscapeKeyboard,
    "Systemtastatur außerhalb des Fensters"
)

func overlap(_ viewport: CGRect) -> CGFloat {
    AppKeyboardLayout.bottomOverlap(keyboardFrame: landscapeKeyboard, viewport: viewport)
}

expect(overlap(landscape), 512, "Vollbild-Überlappung")
expect(overlap(CGRect(x: 0, y: 24, width: 1366, height: 980)), 492, "Home-Indikator nicht doppelt freihalten")
expect(overlap(CGRect(x: 363, y: 180, width: 640, height: 664)), 332, "Kleines Einstellungen-Sheet")
expect(overlap(CGRect(x: 363, y: 100, width: 640, height: 400)), 0, "Sheet komplett oberhalb der Tastatur")
expect(overlap(CGRect(x: 363, y: 512, width: 640, height: 200)), 200, "Ansicht vollständig verdeckt")
expect(overlap(CGRect(x: 1400, y: 600, width: 400, height: 200)), 0, "Keine horizontale Überlappung")
expect(overlap(.zero), 0, "Noch kein Ansichts-Layout")
expect(AppKeyboardLayout.bottomOverlap(keyboardFrame: .zero, viewport: landscape), 0, "Tastatur ausgeblendet")

for (height, homeInset) in [(CGFloat(683), CGFloat(20)), (512, 20), (384, 20), (422, 34), (300, 0)] {
    let keyHeight = AppKeyboardLayout.keyHeight(totalHeight: height, bottomInset: homeInset, rowCount: 4)
    let occupiedHeight = keyHeight * 4 + AppKeyboardLayout.topBarHeight
        + AppKeyboardLayout.topPadding + AppKeyboardLayout.bottomPadding
        + AppKeyboardLayout.rowSpacing * 4 + homeInset
    expect(occupiedHeight, height, "Tasten füllen Tastaturhöhe \(height)")
}
expect(AppKeyboardLayout.keyHeight(totalHeight: 384, bottomInset: 20, rowCount: 4), 73.5, "Keine festen 50-pt-Tasten")
expect(AppKeyboardLayout.keyHeight(totalHeight: 512, bottomInset: 20, rowCount: 0), 0, "Keine Tastenreihen")
expect(AppKeyboardLayout.keyHeight(totalHeight: 40, bottomInset: 20, rowCount: 4), 0, "Keine negativen Tastenhöhen")

print("\(checks) Tastatur-Layout-Checks erfolgreich.")
