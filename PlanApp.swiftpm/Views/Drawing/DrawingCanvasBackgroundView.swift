import SwiftUI
import UIKit

/// Sichtbarer Papier-Hintergrund der Zeichenfläche.
/// Die Linien/Punkte bleiben bewusst dezent grau, damit Stiftfarben darüber klar lesbar sind.
public struct DrawingCanvasBackgroundView: View {
    public let style: NoteBackgroundStyle

    public init(style: NoteBackgroundStyle) {
        self.style = style
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(UIColor.systemBackground).opacity(0.76))

            DrawingCanvasPattern(style: style)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }
}

private struct DrawingCanvasPattern: View {
    let style: NoteBackgroundStyle

    var body: some View {
        Canvas { context, size in
            drawPattern(style, in: CGRect(origin: .zero, size: size), context: context)
        }
        .allowsHitTesting(false)
    }

    private func drawPattern(_ style: NoteBackgroundStyle, in rect: CGRect, context: GraphicsContext) {
        switch style {
        case .blank:
            return
        case .dotted:
            let spacing: CGFloat = 22
            let dotRadius: CGFloat = 1.2
            let color = Color.gray.opacity(0.30)
            var y = spacing
            while y < rect.height {
                var x = spacing
                while x < rect.width {
                    let dot = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Path(ellipseIn: dot), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        case .lined:
            let spacing: CGFloat = 28
            var path = Path()
            var y = spacing
            while y < rect.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Color.gray.opacity(0.26)), lineWidth: 1)
        case .grid:
            let spacing: CGFloat = 28
            var path = Path()
            var x = spacing
            while x < rect.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: rect.height))
                x += spacing
            }
            var y = spacing
            while y < rect.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Color.gray.opacity(0.22)), lineWidth: 1)
        }
    }
}
