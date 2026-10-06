import SwiftUI

/// Größenstufen der Tag-Pille.
public enum NoteTagPillSize {
    /// Im Stundenplan-Block (Vorschau unten rechts).
    case mini
    /// In Notiz-Karten der „Nur Notizen“-Übersicht und in der Filterleiste.
    case small
    /// In der Kopfzeile der Zeichenfläche.
    case regular

    var fontSize: CGFloat {
        switch self {
        case .mini: return 9
        case .small: return 11
        case .regular: return 13
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .mini: return 6
        case .small: return 8
        case .regular: return 11
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .mini: return 2
        case .small: return 3
        case .regular: return 5
        }
    }
}

/// Gefüllte Pille mit Tag-Farbe und Tag-Name. Auf dunklen Farben ist die
/// Schrift weiß, auf hellen dunkel.
public struct NoteTagPill: View {
    public let tag: NoteTag
    public var size: NoteTagPillSize = .regular
    /// Abgeschwächte Darstellung (z. B. nicht ausgewählter Filter).
    public var isDimmed: Bool = false

    public init(tag: NoteTag, size: NoteTagPillSize = .regular, isDimmed: Bool = false) {
        self.tag = tag
        self.size = size
        self.isDimmed = isDimmed
    }

    public var body: some View {
        let fill = Color(hex: tag.colorHex)
        let textColor: Color = tag.usesLightText ? .white : Color.black.opacity(0.85)

        Text(tag.displayName)
            .font(.system(size: size.fontSize, weight: .semibold, design: .default))
            .lineLimit(1)
            .foregroundColor(isDimmed ? .primary : textColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                Capsule().fill(isDimmed ? fill.opacity(0.18) : fill)
            )
            .overlay(
                Capsule().strokeBorder(
                    isDimmed ? fill.opacity(0.7) : Color.white.opacity(0.25),
                    lineWidth: 1
                )
            )
            .accessibilityLabel("Tag \(tag.displayName)")
    }
}

/// Gestrichelte, graue Pille „+ Tag hinzufügen“.
public struct AddTagPill: View {
    public var size: NoteTagPillSize = .regular
    public var tint: Color = .secondary

    public init(size: NoteTagPillSize = .regular, tint: Color = .secondary) {
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "plus")
                .font(.system(size: size.fontSize - 1, weight: .semibold))
            Text("Tag hinzufügen")
                .font(.system(size: size.fontSize, weight: .medium))
        }
        .lineLimit(1)
        .foregroundColor(tint)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            Capsule().fill(tint.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .foregroundColor(tint.opacity(0.7))
        )
        .accessibilityLabel("Tag hinzufügen")
    }
}

/// Kleine, scrollbare Auswahl aller Tags (Popover). Der aktuell gesetzte Tag
/// ist markiert; „Tag entfernen“ erscheint nur, wenn einer gesetzt ist.
public struct NoteTagPickerView: View {
    public let tags: [NoteTag]
    public let selectedTagID: UUID?
    public let onSelect: (UUID?) -> Void

    public init(tags: [NoteTag], selectedTagID: UUID?, onSelect: @escaping (UUID?) -> Void) {
        self.tags = tags
        self.selectedTagID = selectedTagID
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tag wählen")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if tags.isEmpty {
                Text("Noch keine Tags angelegt.\nTags findest du in den Einstellungen unter „Tag-System“.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .frame(width: 240, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(tags) { tag in
                            Button {
                                Haptics.select()
                                onSelect(tag.id)
                            } label: {
                                HStack(spacing: 10) {
                                    NoteTagPill(tag: tag, size: .small)
                                    Spacer(minLength: 6)
                                    if tag.id == selectedTagID {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(width: 240, height: min(CGFloat(tags.count) * 36 + 8, 260))
            }

            if selectedTagID != nil {
                Divider()
                Button(role: .destructive) {
                    Haptics.tap()
                    onSelect(nil)
                } label: {
                    Label("Tag entfernen", systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(.bottom, 6)
        .presentationCompactAdaptation(.popover)
    }
}
