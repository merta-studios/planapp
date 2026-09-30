import SwiftUI

/// Transparente, linienlose Zeichenfläche mit Fach- und Datumsüberschrift.
/// Der historische Typname bleibt bestehen, damit bestehende Aufrufer kompatibel bleiben.
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
            // Nur eine leichte transparente Abgrenzung; kein Papier und keine Linien.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)

            HStack(alignment: .firstTextBaseline) {
                Text(subjectName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text(dateText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .frame(height: headerHeight)
        }
    }
}
