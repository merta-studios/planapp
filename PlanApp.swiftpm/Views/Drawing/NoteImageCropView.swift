import SwiftUI
import UIKit

/// Eigene Übersicht zum Zuschneiden eines Notiz-Bildes: Das Bild liegt
/// komplett sichtbar darunter, der helle Ausschnitt lässt sich verschieben
/// und an den vier Ecken in der Größe verändern. „Übernehmen“ schneidet zu.
struct NoteImageCropView: View {
    let image: UIImage
    var onApply: (UIImage) -> Void
    var onCancel: () -> Void

    /// Ausschnitt in normalisierten Bild-Koordinaten (0…1).
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)

    private let minimumCropEdge: CGFloat = 0.05
    private let handleDiameter: CGFloat = 30

    private enum Corner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let container = CGRect(origin: .zero, size: geometry.size)
                let fitted = fittedRect(for: image, in: container.insetBy(dx: 16, dy: 16))
                let cropRect = CGRect(
                    x: fitted.minX + crop.minX * fitted.width,
                    y: fitted.minY + crop.minY * fitted.height,
                    width: max(1, crop.width * fitted.width),
                    height: max(1, crop.height * fitted.height)
                )

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: fitted.midX, y: fitted.midY)

                    // Abdunkelung außerhalb des Ausschnitts (4 Streifen).
                    dimStrip(
                        x: fitted.minX, y: fitted.minY,
                        width: fitted.width, height: cropRect.minY - fitted.minY
                    )
                    dimStrip(
                        x: fitted.minX, y: cropRect.maxY,
                        width: fitted.width, height: fitted.maxY - cropRect.maxY
                    )
                    dimStrip(
                        x: fitted.minX, y: cropRect.minY,
                        width: cropRect.minX - fitted.minX, height: cropRect.height
                    )
                    dimStrip(
                        x: cropRect.maxX, y: cropRect.minY,
                        width: fitted.maxX - cropRect.maxX, height: cropRect.height
                    )

                    // Drittellinien und Rahmen.
                    Path { path in
                        for third in [1.0 / 3.0, 2.0 / 3.0] {
                            let vx = cropRect.minX + cropRect.width * third
                            path.move(to: CGPoint(x: vx, y: cropRect.minY))
                            path.addLine(to: CGPoint(x: vx, y: cropRect.maxY))
                            let hy = cropRect.minY + cropRect.height * third
                            path.move(to: CGPoint(x: cropRect.minX, y: hy))
                            path.addLine(to: CGPoint(x: cropRect.maxX, y: hy))
                        }
                    }
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)

                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                        .contentShape(Rectangle())
                        .gesture(moveGesture(fitted: fitted, cropRect: cropRect))

                    cropHandle(.topLeading, cropRect: cropRect, fitted: fitted)
                    cropHandle(.topTrailing, cropRect: cropRect, fitted: fitted)
                    cropHandle(.bottomLeading, cropRect: cropRect, fitted: fitted)
                    cropHandle(.bottomTrailing, cropRect: cropRect, fitted: fitted)
                }
                .frame(width: container.width, height: container.height)
                .coordinateSpace(name: "noteImageCrop")
            }
            .navigationTitle("Zuschneiden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        Haptics.tap()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Zurücksetzen") {
                            Haptics.tap()
                            withAnimation(.easeOut(duration: 0.2)) {
                                crop = CGRect(x: 0, y: 0, width: 1, height: 1)
                            }
                        }
                        .disabled(isFullCrop)
                        Button("Übernehmen") {
                            Haptics.success()
                            if let cropped = Self.cropped(image, to: crop) {
                                onApply(cropped)
                            } else {
                                onCancel()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var isFullCrop: Bool {
        crop.minX <= 0.001 && crop.minY <= 0.001
            && crop.maxX >= 0.999 && crop.maxY >= 0.999
    }

    // MARK: - Geometrie

    private func fittedRect(for image: UIImage, in bounds: CGRect) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let factor = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * factor, height: imageSize.height * factor)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func dimStrip(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if width > 0.5, height > 0.5 {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: width, height: height)
                    .position(x: x + width / 2, y: y + height / 2)
            }
        }
    }

    // MARK: - Gesten

    @State private var moveStartCrop: CGRect? = nil

    private func moveGesture(fitted: CGRect, cropRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard fitted.width > 0, fitted.height > 0 else { return }
                if moveStartCrop == nil {
                    moveStartCrop = crop
                }
                guard let start = moveStartCrop else { return }
                let dx = value.translation.width / fitted.width
                let dy = value.translation.height / fitted.height
                var next = start
                next.origin.x = min(max(0, start.minX + dx), max(0, 1 - start.width))
                next.origin.y = min(max(0, start.minY + dy), max(0, 1 - start.height))
                crop = next
            }
            .onEnded { _ in
                moveStartCrop = nil
            }
    }

    private func cropHandle(_ corner: Corner, cropRect: CGRect, fitted: CGRect) -> some View {
        let position: CGPoint = {
            switch corner {
            case .topLeading: return CGPoint(x: cropRect.minX, y: cropRect.minY)
            case .topTrailing: return CGPoint(x: cropRect.maxX, y: cropRect.minY)
            case .bottomLeading: return CGPoint(x: cropRect.minX, y: cropRect.maxY)
            case .bottomTrailing: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
            }
        }()
        return Circle()
            .fill(Color.white)
            .frame(width: handleDiameter, height: handleDiameter)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
            .position(position)
            .contentShape(Circle().inset(by: -12))
            .gesture(handleGesture(corner, fitted: fitted))
    }

    private func handleGesture(_ corner: Corner, fitted: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                guard fitted.width > 0, fitted.height > 0 else { return }
                // Griffposition in normalisierten Koordinaten.
                let point = CGPoint(
                    x: (value.location.x - fitted.minX) / fitted.width,
                    y: (value.location.y - fitted.minY) / fitted.height
                )
                guard point.x.isFinite, point.y.isFinite else { return }
                var next = crop
                switch corner {
                case .topLeading:
                    next.origin.x = min(max(0, point.x), next.maxX - minimumCropEdge)
                    next.origin.y = min(max(0, point.y), next.maxY - minimumCropEdge)
                    next.size.width = crop.maxX - next.minX
                    next.size.height = crop.maxY - next.minY
                case .topTrailing:
                    next.origin.y = min(max(0, point.y), next.maxY - minimumCropEdge)
                    next.size.width = max(minimumCropEdge, min(1, point.x) - next.minX)
                    next.size.height = crop.maxY - next.minY
                case .bottomLeading:
                    next.origin.x = min(max(0, point.x), next.maxX - minimumCropEdge)
                    next.size.width = crop.maxX - next.minX
                    next.size.height = max(minimumCropEdge, min(1, point.y) - next.minY)
                case .bottomTrailing:
                    next.size.width = max(minimumCropEdge, min(1, point.x) - next.minX)
                    next.size.height = max(minimumCropEdge, min(1, point.y) - next.minY)
                }
                crop = next
            }
    }

    // MARK: - Zuschneiden

    /// Schneidet das Bild auf den normalisierten Ausschnitt zu.
    /// Orientierung und Auflösung bleiben erhalten.
    static func cropped(_ image: UIImage, to normalized: CGRect) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let rect = CGRect(
            x: max(0, normalized.minX) * size.width,
            y: max(0, normalized.minY) * size.height,
            width: min(1, normalized.width) * size.width,
            height: min(1, normalized.height) * size.height
        )
        guard rect.width >= 4, rect.height >= 4 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            image.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}
