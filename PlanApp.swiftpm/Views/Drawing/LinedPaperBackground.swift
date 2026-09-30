import SwiftUI

/// Transparente, linienlose Zeichenfläche mit Fach- und Datumsüberschrift im Liquid-Glass Design.
public struct LinedPaperBackground: View {
    public let height: CGFloat
    public let headerHeight: CGFloat
    public let subjectName: String
    public let dateText: String

    public init(
        height: CGFloat = 460,
        headerHeight: CGFloat = 56,
        subjectName: String,
        dateText: String
    ) {
        self.height = height
        self.headerHeight = headerHeight
        self.subjectName = subjectName
        self.dateText = dateText
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Liquid Glass Hintergrund
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)

            HStack(alignment: .center) {
                Text(subjectName)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .foregroundColor(.white)

                Spacer()

                Text(dateText)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.80))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .frame(height: headerHeight)
        }
    }
}
