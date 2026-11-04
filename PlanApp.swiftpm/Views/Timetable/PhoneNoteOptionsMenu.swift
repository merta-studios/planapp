import SwiftUI

/// Die Optionen einer Notiz auf dem **iPhone** – exakt die Aktionen, die auf
/// dem iPad beim gedrückt Halten eines Stundenblocks erscheinen.
///
/// Der iPhone-Modus hat keinen Zeichenbereich mehr: Handschriftliche Notizen
/// (vom iPad) lassen sich dort nicht öffnen. Ein Tipp auf eine solche Notiz
/// zeigt diese Liste; „Notiz löschen“, „Kopieren“, „Einfügen“ und die
/// Tag-Auswahl funktionieren ganz normal weiter.
struct PhoneNoteOptionsMenu: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    let lesson: Lesson
    /// Fragt die Bestätigung zum Löschen an (der Dialog liegt in der
    /// Stundenplan-Ansicht, weil ein Dialog nicht aus einem Dialog heraus
    /// geöffnet werden kann).
    let onRequestDelete: (Lesson) -> Void

    var body: some View {
        let hasVisibleNote = viewModel.hasVisibleNote(for: lesson)

        Button {
            Haptics.tap()
            viewModel.revealLessonInStandardMode(lesson)
        } label: {
            Label("Im Standard-Modus anzeigen", systemImage: "rectangle.grid.3x2")
        }

        if hasVisibleNote {
            Button {
                Haptics.tap()
                viewModel.copyNote(for: lesson)
            } label: {
                Label("Kopieren", systemImage: "doc.on.doc")
            }
        }

        if viewModel.tagSettings.isEnabled, hasVisibleNote {
            ForEach(viewModel.tagSettings.tags) { tag in
                Button {
                    Haptics.select()
                    viewModel.setTag(tag.id, for: lesson)
                } label: {
                    if viewModel.tag(for: lesson)?.id == tag.id {
                        Label(tag.displayName, systemImage: "checkmark")
                    } else {
                        Text(tag.displayName)
                    }
                }
            }
            if viewModel.tag(for: lesson) != nil {
                Button(role: .destructive) {
                    Haptics.tap()
                    viewModel.setTag(nil, for: lesson)
                } label: {
                    Label("Tag entfernen", systemImage: "xmark.circle")
                }
            }
        }

        if viewModel.hasCopiedNote {
            Button {
                Haptics.tap()
                viewModel.pasteCopiedNote(into: lesson)
            } label: {
                Label(
                    hasVisibleNote ? "Einfügen (ersetzt Notiz)" : "Einfügen",
                    systemImage: "doc.on.clipboard"
                )
            }
        }

        if hasVisibleNote {
            Button(role: .destructive) {
                Haptics.warning()
                onRequestDelete(lesson)
            } label: {
                Label("Notiz löschen", systemImage: "trash")
            }
        }

        Button {
            Haptics.tap()
            viewModel.phoneOptionsLesson = nil
            let target = lesson
            Task { await viewModel.openNoteForNextOccurrence(after: target) }
        } label: {
            Label("Notiz für die nächste Stunde erstellen", systemImage: "calendar.badge.plus")
        }
    }
}
