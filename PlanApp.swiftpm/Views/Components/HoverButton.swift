import SwiftUI

/// Wiederverwendbarer Button mit Apple Pencil Hover-Unterstützung und iPad-optimierter Haptik
public struct HoverButton<Content: View>: View {
    public let action: () -> Void
    public let content: () -> Content

    public init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            content()
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(.lift)
        .contentShape(Rectangle())
    }
}

/// Stilvoller Liquid-Glass-Kapsel-Button für Aktionen
public struct AccentPillButton: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let action: () -> Void

    public init(_ title: String, icon: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .default))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlassButton(cornerRadius: 20, tint: isSelected ? Color.blue : nil, isFilled: isSelected)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(.lift)
    }
}
