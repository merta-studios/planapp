import Foundation
import CoreGraphics
import Vision

/// Kapselt die komplette Vision-Texterkennung für „Handschrift in Text
/// umwandeln“.
///
/// Warum ausgelagert? Die Erkennung lief vorher direkt in der SwiftUI-View:
/// Der Vision-Completion-Handler kommt auf einem Hintergrund-Thread zurück,
/// hat dort SwiftUI-Zustand angefasst und mehrere Fehlerpfade (kein Ergebnis,
/// nicht unterstützte Sprache, Abbruch der Analyse) waren nicht abgedeckt.
/// Hier passiert alles gekapselt, jeder Fehler wird abgefangen und das
/// Ergebnis landet garantiert auf dem Main-Thread.
public enum HandwritingRecognizer {

    public enum RecognitionError: Error {
        /// Vision konnte die Analyse nicht ausführen.
        case analysisFailed
    }

    /// Erkennt Text im übergebenen Bild und liefert fertige, bereits in die
    /// Zeichenfläche eingepasste Textfelder zurück.
    ///
    /// - Parameters:
    ///   - cgImage: Gerendertes Bild der Zeichnung (schwarz auf weiß, nicht zugeschnitten).
    ///   - canvasSize: Größe der Zeichenfläche in Punkten – Basis für die Rückrechnung.
    ///   - completion: Wird **immer auf dem Main-Thread** aufgerufen.
    public static func recognizeTextBoxes(
        in cgImage: CGImage,
        canvasSize: CGSize,
        completion: @escaping (Result<[NoteTextBox], Error>) -> Void
    ) {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else {
            DispatchQueue.main.async { completion(.failure(RecognitionError.analysisFailed)) }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            func finish(_ result: Result<[NoteTextBox], Error>) {
                DispatchQueue.main.async { completion(result) }
            }

            // Bewusst OHNE Completion-Block-Initializer: Das Ergebnis wird
            // direkt nach `perform` synchron aus `request.results` gelesen.
            func makeRequest(usesLanguageCorrection: Bool) -> VNRecognizeTextRequest {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                // Bei Handschrift sind Wortabstände und Schreibweisen oft
                // nicht lexikalisch korrekt. Die Korrektur konnte zuvor
                // gültige Buchstabenfolgen verwerfen.
                request.usesLanguageCorrection = usesLanguageCorrection
                // Die Zeichenfläche kann auf dem iPad stark verkleinert sein.
                // Keine feste Mindesthöhe vor der eigentlichen Erkennung.
                request.minimumTextHeight = 0
                applyPreferredLanguages(to: request)
                return request
            }

            func observations(from request: VNRecognizeTextRequest) -> [VNRecognizedTextObservation] {
                // `results` ist je nach SDK-Version unterschiedlich
                // typisiert – der Umweg über `[VNObservation]?` funktioniert
                // in beiden Fällen.
                let rawResults: [VNObservation]? = request.results
                return (rawResults ?? []).compactMap { $0 as? VNRecognizedTextObservation }
            }

            let firstRequest = makeRequest(usesLanguageCorrection: false)
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                    .perform([firstRequest])
            } catch {
                finish(.failure(error))
                return
            }

            var recognized = observations(from: firstRequest)

            // Die beiden Vision-Modi verhalten sich bei verbundener
            // Handschrift unterschiedlich. Ein zweiter, korrigierender Lauf
            // ist ein Fallback, nicht die Voraussetzung für das Ergebnis.
            if recognized.isEmpty {
                let fallbackRequest = makeRequest(usesLanguageCorrection: true)
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
                        .perform([fallbackRequest])
                    recognized = observations(from: fallbackRequest)
                } catch {
                    // Ein fehlgeschlagener Fallback soll ein brauchbares
                    // Ergebnis des ersten Laufs nicht nachträglich verwerfen.
                }
            }

            finish(.success(makeTextBoxes(from: recognized, canvasSize: canvasSize)))
        }
    }

    /// Vision bricht auf einigen iOS-Versionen ab, wenn nicht unterstützte
    /// Sprachcodes gesetzt werden. Deshalb werden die gewünschten Sprachen
    /// vorher gegen die tatsächlich verfügbare Liste gefiltert; ohne Treffer
    /// bleibt Visions Standardkonfiguration aktiv.
    private static func applyPreferredLanguages(to request: VNRecognizeTextRequest) {
        let preferred = ["de-DE", "de", "en-US", "en"]
        guard let supported = try? request.supportedRecognitionLanguages() else { return }
        let selected = preferred.filter { supported.contains($0) }
        guard !selected.isEmpty else { return }
        request.recognitionLanguages = selected
    }

    // MARK: - Umrechnung in Textfelder

    static func makeTextBoxes(
        from observations: [VNRecognizedTextObservation],
        canvasSize: CGSize
    ) -> [NoteTextBox] {
        let margin: CGFloat = 6

        let sorted = observations.sorted {
            if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.02 {
                return $0.boundingBox.minY > $1.boundingBox.minY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }

        return sorted.compactMap { observation -> NoteTextBox? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            let normalized = observation.boundingBox
            guard normalized.minX.isFinite,
                  normalized.minY.isFinite,
                  normalized.maxY.isFinite,
                  normalized.width.isFinite,
                  normalized.height.isFinite,
                  normalized.width > 0,
                  normalized.height > 0 else {
                return nil
            }

            let rawX = normalized.minX * canvasSize.width
            let rawY = (1 - normalized.maxY) * canvasSize.height
            let rawWidth = normalized.width * canvasSize.width
            let rawHeight = normalized.height * canvasSize.height
            guard rawX.isFinite,
                  rawY.isFinite,
                  rawWidth.isFinite,
                  rawHeight.isFinite,
                  rawWidth > 0,
                  rawHeight > 0 else {
                return nil
            }

            let fontSize = max(12, min(34, rawHeight * 0.82))
            let width = min(
                max(90, rawWidth + 28),
                max(90, canvasSize.width - (margin * 2))
            )
            let x = min(
                max(margin, rawX - 8),
                max(margin, canvasSize.width - width - margin)
            )
            let y = min(
                max(margin, rawY - 6),
                max(margin, canvasSize.height - max(42, rawHeight + 16) - margin)
            )

            return NoteTextBox(
                text: text,
                x: Double(x),
                y: Double(y),
                width: Double(width),
                fontSize: Double(fontSize)
            ).sanitized(in: canvasSize)
        }
    }
}
