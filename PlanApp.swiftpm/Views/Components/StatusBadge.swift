import SwiftUI

/// Badges für Unterrichtsstatus (Entfall, Vertretung, Notiz vorhanden)
public struct StatusBadge: View {
    public enum BadgeType {
        case cancelled
        case substitution
        case hasNote
        case today
        case doublePeriod
    }

    public let type: BadgeType
    public let customText: String?

    public init(_ type: BadgeType, text: String? = nil) {
        self.type = type
        self.customText = text
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .bold))

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .foregroundColor(foregroundColor)
        .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
    }

    private var title: String {
        if let customText = customText, !customText.isEmpty {
            return customText
        }
        switch type {
        case .cancelled:
            return "Entfällt"
        case .substitution:
            return "Vertretung"
        case .hasNote:
            return "Notiz"
        case .today:
            return "Heute"
        case .doublePeriod:
            return "Doppelstd."
        }
    }

    private var iconName: String {
        switch type {
        case .cancelled:
            return "xmark.circle.fill"
        case .substitution:
            return "arrow.triangle.2.circlepath"
        case .hasNote:
            return "pencil.line"
        case .today:
            return "calendar"
        case .doublePeriod:
            return "clock.fill"
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .cancelled:
            return Color.red
        case .substitution:
            return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .hasNote:
            return Color.black.opacity(0.65)
        case .today:
            return Color.blue
        case .doublePeriod:
            return Color.white.opacity(0.25)
        }
    }

    private var foregroundColor: Color {
        .white
    }

    private var shadowColor: Color {
        switch type {
        case .cancelled:
            return Color.red.opacity(0.3)
        case .substitution:
            return Color.orange.opacity(0.3)
        default:
            return Color.black.opacity(0.15)
        }
    }
}
