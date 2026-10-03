import Foundation

/// Drei kompakte Karten auf normalen iPad-Breiten, zwei bzw. eine im schmalen
/// Split View. Fensterbreite statt Geräteausrichtung ist ausschlaggebend.
enum NotesOverviewLayout {
    static let horizontalPadding: CGFloat = 14
    static let columnSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let minimumCardWidth: CGFloat = 220

    static func columnCount(for width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 1 }
        let available = max(0, width - 2 * horizontalPadding)
        let count = (available + columnSpacing) / (minimumCardWidth + columnSpacing)
        return Int(min(3, max(1, count.rounded(.down))))
    }
}
