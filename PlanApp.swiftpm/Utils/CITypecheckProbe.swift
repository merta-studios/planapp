import Foundation

/// **Absichtlicher Typfehler – CI-Sonde, kein App-Code.**
///
/// Diese Datei prüft end-to-end, dass die Repo-Variable
/// `SWIFT_TYPECHECK_BLOCKING=true` echte Typfehler im Job
/// „Typ-Prüfung (Linux-taugliche Dateien)“ wirklich blockiert:
/// `answer` ist ein `Int`, der Aufruf `answer(2)` erzeugt
/// „Cannot call value of non-function type 'Int'“ – ein echter Typfehler,
/// keine unter Linux erwartbare iOS-only-Meldung.
///
/// Die Datei ist bewusst isoliert: Sie wird von keinem anderen Code
/// referenziert und ist nicht Teil von `Tests/run-regressions.sh`.
/// Sie darf niemals nach `main` gelangen und wird direkt nach dem
/// Nachweis wieder aus dem Branch entfernt (Baum und Historie).
enum CITypecheckProbe {
    static let answer: Int = 42

    static func doubleAnswer() -> Int {
        answer(2)
    }
}
