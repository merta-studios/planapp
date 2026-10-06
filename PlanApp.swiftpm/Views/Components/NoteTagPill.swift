import SwiftUI

/// Größenstufen der Tag-Pille.
public enum NoteTagPillSize {
    /// Im Stundenplan-Block (Vorschau unten rechts).
    case mini
    /// In Notiz-Karten der „Nur Notizen“-Übersicht und in der Filterleiste.
    case small
    /// In der Kopfzeile der Zeichenfläche.
    case regular
    /// Große Auswahl in der Zeichenfläche / im Filter.
    case large

    var fontSize: CGFloat {
        switch self {
        case .mini: return 9
        case .small: return 11
        case .regular: return 13
        case .large: return 16
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .mini: return 6
        case .small: return 8
        case .regular: return 11
        case .large: return 14
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .mini: return 2
        case .small: return 3
        case .regular: return 5
        case .large: return 8
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
    /// Begrenzt die ganze Auswahl. Titel und „Tag entfernen“ bleiben sichtbar;
    /// nur die Liste scrollt.
    public var maxPanelHeight: CGFloat? = nil
    public let onSelect: (UUID?) -> Void

    public init(
        tags: [NoteTag],
        selectedTagID: UUID?,
        maxPanelHeight: CGFloat? = nil,
        onSelect: @escaping (UUID?) -> Void
    ) {
        self.tags = tags
        self.selectedTagID = selectedTagID
        self.maxPanelHeight = maxPanelHeight
        self.onSelect = onSelect
    }

    public var body: some View {
        pickerStack
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxPanelHeight ?? 480)
            .frame(height: maxPanelHeight)
            .clipped()
    }

    private var pickerStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tag wählen")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            if tags.isEmpty {
                Text("Noch keine Tags angelegt.\nTags findest du in den Einstellungen unter „Tag-System“.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(tags) { tag in
                            Button {
                                Haptics.select()
                                onSelect(tag.id)
                            } label: {
                                HStack(spacing: 14) {
                                    NoteTagPill(tag: tag, size: .large)
                                    Spacer(minLength: 8)
                                    if tag.id == selectedTagID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tag.id == selectedTagID
                                              ? Color.blue.opacity(0.10)
                                              : Color(UIColor.tertiarySystemBackground).opacity(0.7))
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if selectedTagID != nil {
                Divider().padding(.top, 6)
                Button(role: .destructive) {
                    Haptics.tap()
                    onSelect(nil)
                } label: {
                    Label("Tag entfernen", systemImage: "xmark.circle")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .layoutPriority(1)
            }
        }
        .padding(.bottom, selectedTagID == nil ? 8 : 0)
    }
}

/// Mehrfachauswahl der Tags für den Modus „Nur Notizen“.
struct TagFilterSheet: View {
    @EnvironmentObject private var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Haptics.select()
                        viewModel.activeTagFilter.removeAll()
                    } label: {
                        HStack {
                            Text("Alle Notizen")
                            Spacer()
                            if viewModel.activeTagFilter.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        // Ganze Zeile ist anwählbar – nicht nur das Häkchen.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                } footer: {
                    Text("Ohne Auswahl werden alle Notizen gezeigt. Mehrere Tags lassen sich gleichzeitig abhaken.")
                }

                Section("Tags") {
                    if viewModel.tagSettings.tags.isEmpty {
                        Text("Noch keine Tags angelegt.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.tagSettings.tags) { tag in
                            Button {
                                Haptics.select()
                                viewModel.toggleTagFilter(tag.id)
                            } label: {
                                HStack(spacing: 14) {
                                    NoteTagPill(tag: tag, size: .large)
                                    Spacer()
                                    Image(systemName: viewModel.activeTagFilter.contains(tag.id)
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(viewModel.activeTagFilter.contains(tag.id) ? .blue : .secondary)
                                }
                                .padding(.vertical, 6)
                                // Ganze Zeile ist anwählbar – nicht nur Pille
                                // oder das kleine Häkchen am rechten Rand.
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
