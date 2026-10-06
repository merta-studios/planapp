import SwiftUI

/// Badges für Unterrichtsstatus (Entfall, Vertretung, Notiz vorhanden)
public struct StatusBadge: View {
    public enum BadgeType {
        case cancelled
        case substitution
        case hasNote
        case today
        /// Kommende Schulwoche: derselbe Hinweis wie „Heute“, nur in Gelb.
        case upcomingWeek
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
                .font(.system(size: 9, weight: .regular, design: .default))

            Text(title)
                .font(.system(size: 10, weight: .regular, design: .default))
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
        case .upcomingWeek:
            return "Nächste Woche"
        case .doublePeriod:
            return "Doppelstunde"
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
        case .upcomingWeek:
            return "calendar.badge.clock"
        case .doublePeriod:
            return "clock.fill"
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .cancelled:
            return Color.red.opacity(0.85)
        case .substitution:
            return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .hasNote:
            return Color.black.opacity(0.65)
        case .today:
            return Color.blue
        case .upcomingWeek:
            // Helles Gelb: Die kommende Woche soll auffallen, aber nicht wie
            // ein zweites „Heute“ in Blau wirken.
            return Color(red: 1.0, green: 0.90, blue: 0.45)
        case .doublePeriod:
            return Color.white.opacity(0.25)
        }
    }

    private var foregroundColor: Color {
        switch type {
        case .upcomingWeek:
            // Auf hellem Gelb wäre weiße Schrift unlesbar.
            return Color(red: 0.45, green: 0.35, blue: 0.02)
        default:
            return .white
        }
    }

    private var shadowColor: Color {
        switch type {
        case .cancelled:
            return Color.red.opacity(0.3)
        case .substitution:
            return Color.orange.opacity(0.3)
        case .upcomingWeek:
            return Color(red: 0.85, green: 0.70, blue: 0.15).opacity(0.35)
        default:
            return Color.black.opacity(0.15)
        }
    }
}
