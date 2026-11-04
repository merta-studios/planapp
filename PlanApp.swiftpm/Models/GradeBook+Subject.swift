import Foundation

/// Verknüpfung zwischen den Fächern aus „Fächer & Farben“ und dem Notenbuch.
///
/// Bewusst in einer eigenen Datei: `GradeEntry.swift` bleibt frei von
/// App-Modellen, die SwiftUI/UIKit importieren, damit die reinen Rechenregeln
/// in den Regressions-Tests (Linux/`swiftc`) mitlaufen.
extension GradeBook {
    /// Schlüssel eines Fachs im Notenbuch: der normalisierte Name aus
    /// „Fächer & Farben“. So bleiben die Einträge auch dann zugeordnet, wenn
    /// der Anzeigename später geändert wird.
    public static func subjectKey(for subject: SubjectCustomization) -> String {
        GradeBook.normalizedKey(subject.originalSubject)
    }

    /// Alle Einträge eines Fachs.
    public func entries(for subject: SubjectCustomization) -> [GradeEntry] {
        entries(forSubjectKey: GradeBook.subjectKey(for: subject))
    }
}
