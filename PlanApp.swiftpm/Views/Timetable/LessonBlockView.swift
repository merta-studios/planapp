import SwiftUI

/// Block-Karte für ein Unterrichtsfach im Stundenplan
public struct LessonBlockView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let lesson: Lesson
    public let height: CGFloat
    public let noteNamespace: Namespace.ID

    @State private var isHovered: Bool = false
    @State private var pinchScale: CGFloat = 1.0

    public init(lesson: Lesson, height: CGFloat, noteNamespace: Namespace.ID) {
        self.lesson = lesson
        self.height = height
        self.noteNamespace = noteNamespace
    }

    public var body: some View {
        let (displayName, _, subjectColor) = viewModel.resolveSubjectDisplay(for: lesson)
        let note = viewModel.noteFor(lesson: lesson)
        let settings = viewModel.displaySettings

        ZStack(alignment: .topLeading) {
            // Hintergrund mit Farbverlauf & Schattierung
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    lesson.isCancelled
                        ? LinearGradient(
                            colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [subjectColor, subjectColor.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            lesson.isCancelled
                                ? Color.red.opacity(0.6)
                                : (lesson.isSubstitution ? Color.orange.opacity(0.8) : Color.white.opacity(0.2)),
                            lineWidth: lesson.isCancelled || lesson.isSubstitution ? 1.5 : 1.0
                        )
                )
                .shadow(
                    color: lesson.isCancelled ? Color.clear : subjectColor.opacity(0.25),
                    radius: isHovered ? 8 : 4,
                    x: 0,
                    y: isHovered ? 4 : 2
                )

            // Block-Inhalte
            VStack(alignment: .leading, spacing: 4) {
                // Obere Zeile: Fachname + Status-Badges
                HStack(alignment: .top, spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingTextColor)
                        .strikethrough(lesson.isCancelled, color: .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    // Badges
                    VStack(alignment: .trailing, spacing: 3) {
                        if lesson.isCancelled {
                            StatusBadge(.cancelled)
                        } else if lesson.isSubstitution {
                            StatusBadge(.substitution)
                        }
                    }
                }

                // Anpassbare Zusatz-Informationen (Lehrer, Raum, Details)
                HStack(spacing: 8) {
                    if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "person")
                                .font(.system(size: 10, weight: .regular, design: .default))
                            if let orig = lesson.originalTeacher, lesson.isSubstitution {
                                Text(orig)
                                    .strikethrough(true, color: .red)
                                Text("➔ \(lesson.teacherRaw)")
                            } else {
                                Text(lesson.teacherRaw)
                            }
                        }
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                    }

                    if settings.showRoom && !lesson.roomRaw.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .regular, design: .default))
                            if let orig = lesson.originalRoom, lesson.isSubstitution {
                                Text(orig)
                                    .strikethrough(true, color: .red)
                                Text("➔ \(lesson.roomRaw)")
                            } else {
                                Text(lesson.roomRaw)
                            }
                        }
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                    }
                }

                // Vertretungsnotiz / Grund
                if settings.showSubstitutionDetails && !lesson.substitutionText.isEmpty {
                    Text(lesson.substitutionText)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(lesson.isCancelled ? .red.opacity(0.9) : subjectColor.contrastingTextColor)
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                Spacer(minLength: 2)

                // Handschriftliche Notiz-Vorschau
                if settings.showNotesPreview, let imgData = note?.croppedImageData, let uiImg = UIImage(data: imgData) {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: max(24, height * 0.42))
                        Spacer()
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(8)
        }
        .frame(height: height)
        .matchedGeometryEffect(
            id: "lesson_card_\(lesson.noteKey)",
            in: noteNamespace,
            properties: .frame,
            anchor: .center,
            isSource: true
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .hoverEffect(.lift)
        // Zoom-Geste mit zwei Fingern öffnet Notiz-Bereich
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in
                    pinchScale = scale
                }
                .onEnded { scale in
                    if scale > 1.15 {
                        viewModel.openNote(for: lesson)
                    }
                    pinchScale = 1.0
                }
        )
        // Klick öffnet Notiz-Bereich
        .onTapGesture {
            viewModel.openNote(for: lesson)
        }
    }
}
