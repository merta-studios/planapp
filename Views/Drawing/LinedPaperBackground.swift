import SwiftUI

/// Zeichnet das linierte Notizpapier mit rotem Rand und dynamischer Zeilenanzahl
public struct LinedPaperBackground: View {
    public let lineCount: Int
    public let lineHeight: CGFloat
    public let headerHeight: CGFloat
    public let subjectName: String
    public let dateText: String

    public init(
        lineCount: Int,
        lineHeight: CGFloat = 52,
        headerHeight: CGFloat = 64,
        subjectName: String,
        dateText: String
    ) {
        self.lineCount = lineCount
        self.lineHeight = lineHeight
        self.headerHeight = headerHeight
        self.subjectName = subjectName
        self.dateText = dateText
    }

    public var totalHeight: CGFloat {
        headerHeight + CGFloat(lineCount) * lineHeight + 20
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Warmes Notizpapier
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.985, green: 0.980, blue: 0.965))
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

            // Kopfbereich des Zettels (Fach & Datum)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(subjectName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.25))

                    Spacer()

                    Text(dateText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Text("Hausaufgaben & Notizen")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.blue.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(height: headerHeight)

            // Roter linker Seitenrand
            Path { path in
                let marginX: CGFloat = 54
                path.move(to: CGPoint(x: marginX, y: 12))
                path.addLine(to: CGPoint(x: marginX, y: totalHeight - 12))
            }
            .stroke(Color.red.opacity(0.4), lineWidth: 1.5)

            // Horizontale Schreiblinien
            Path { path in
                for i in 1...lineCount {
                    let y = headerHeight + CGFloat(i) * lineHeight
                    path.move(to: CGPoint(x: 20, y: y))
                    path.addLine(to: CGPoint(x: 760, y: y))
                }
            }
            .stroke(Color.blue.opacity(0.18), lineWidth: 1.0)
        }
    }
}
