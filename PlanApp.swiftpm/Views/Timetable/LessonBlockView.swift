import SwiftUI

/// Block-Karte für ein Unterrichtsfach im Stundenplan
public struct LessonBlockView: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    public let lesson: Lesson
    public let height: CGFloat

    @State private var isHovered: Bool = false
    @State private var pinchScale: CGFloat = 1.0

    public init(lesson: Lesson, height: CGFloat) {
        self.lesson = lesson
        self.height = height
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
                    // Feiner subtiler Rahmen
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            lesson.isCancelled
                                ? Color.red.opacity(0.6)
                                : (lesson.isSubstitution ? Color.orange.opacity(0.8) : Color.white.opacity(0.2)),
                            lineWidth: lesson.isCancelled || lesson.isSubstitution ? 2.0 : 1.0
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
                    VStack(alignment: .leading, spacing: 1) {
                        // Standard: Der fette Fachname
                        Text(displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingTextColor)
                            .strikethrough(lesson.isCancelled, color: .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if lesson.durationPeriods == 2 {
                            Text("Doppelstunde")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(subjectColor.contrastingSecondaryTextColor)
                        }
                    }

                    Spacer(minLength: 0)

                    // Badges
                    VStack(alignment: .trailing, spacing: 3) {
                        if lesson.isCancelled {
                            StatusBadge(.cancelled)
                        } else if lesson.isSubstitution {
                            StatusBadge(.substitution)
                        }

                        if note?.hasDrawing == true {
                            StatusBadge(.hasNote)
                        }
                    }
                }

                // Anpassbare Zusatz-Informationen (Lehrer, Raum, Details)
                HStack(spacing: 8) {
                    if settings.showTeacher && !lesson.teacherRaw.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            if let orig = lesson.originalTeacher, lesson.isSubstitution {
                                Text(orig)
                                    .strikethrough(true, color: .red)
                                Text("➔ \(lesson.teacherRaw)")
                                    .fontWeight(.bold)
                            } else {
                                Text(lesson.teacherRaw)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                    }

                    if settings.showRoom && !lesson.roomRaw.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            if let orig = lesson.originalRoom, lesson.isSubstitution {
                                Text(orig)
                                    .strikethrough(true, color: .red)
                                Text("➔ \(lesson.roomRaw)")
                                    .fontWeight(.bold)
                            } else {
                                Text(lesson.roomRaw)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(lesson.isCancelled ? .secondary : subjectColor.contrastingSecondaryTextColor)
                    }
                }

                // Vertretungsnotiz / Grund
                if settings.showSubstitutionDetails && !lesson.substitutionText.isEmpty {
                    Text(lesson.substitutionText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(lesson.isCancelled ? .red.opacity(0.9) : subjectColor.contrastingTextColor)
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                Spacer(minLength: 2)

                // Handschriftliche Notiz-Vorschau (automatisch zugeschnitten)
                if settings.showNotesPreview, let imgData = note?.croppedImageData, let uiImg = UIImage(data: imgData) {
                    HStack {
                        Spacer()
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: max(24, height * 0.42))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.98, green: 0.98, blue: 0.96).opacity(0.9))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                        Spacer()
                    }
                    .padding(.bottom, 2)
                }
            }
            .padding(9)
        }
        .frame(height: height)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // Apple Pencil Hover Unterstützung
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
