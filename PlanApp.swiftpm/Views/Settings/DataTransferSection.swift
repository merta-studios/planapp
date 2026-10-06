import SwiftUI
import UIKit

/// Einstellungen → „Daten“: komplette Sicherung als Text exportieren
/// (teilen oder in die Zwischenablage kopieren) und aus der Zwischenablage
/// wieder importieren – mit Vorschau und Bestätigung.
///
/// Das ist der Weg, um denselben Stand auf mehreren Geräten zu haben: Der
/// Export-Text lässt sich z. B. über AirDrop, iCloud Drive (Dateien-App),
/// Nachrichten oder die Universal-Zwischenablage auf das andere Gerät bringen.
struct DataTransferSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var shareItem: BackupShareItem? = nil
    @State private var pendingImport: AppBackup? = nil
    @State private var importProblemMessage: String? = nil
    @State private var statusMessage: String? = nil
    @State private var isPreparingExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Sichern & Übertragen")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            // EXPORT
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    Text("Export alles")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }

                Text("Erstellt einen Text mit allen gespeicherten Daten: Notizen (Zeichnungen, Textfelder, Tags), Stundenplan, Zugangsdaten, Fächer- und Lehrkraft-Anpassungen sowie sämtliche Einstellungen. Den Text kannst du teilen oder kopieren und auf einem anderen Gerät importieren.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(action: shareExport) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Teilen")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .lightButton(cornerRadius: 12, tint: .blue, isFilled: true)
                    .foregroundColor(.white)

                    Button(action: copyExportToClipboard) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .regular, design: .default))
                            Text("Kopieren")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .lightButton(cornerRadius: 12, tint: .blue)
                    .foregroundColor(.blue)
                }
                .disabled(isPreparingExport)
                .opacity(isPreparingExport ? 0.6 : 1)
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // IMPORT
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.green)
                    Text("Import")
                        .font(.system(size: 14, weight: .regular, design: .default))
                }

                Text("Liest eine Sicherung aus der Zwischenablage. Vor dem Import siehst du, was enthalten ist. Achtung: Alle aktuellen Daten dieses Geräts werden dabei vollständig ersetzt.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: prepareImportFromClipboard) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Aus Zwischenablage importieren")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .lightButton(cornerRadius: 12, tint: .green)
                .foregroundColor(.green)
            }
            .padding(14)
            .lightCard(cornerRadius: 14, strokeOpacity: 0.18)

            // HINWEIS ZU MEHREREN GERÄTEN
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "icloud")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text("Eine automatische iCloud-Synchronisation ist für diese App nicht möglich: Sie wird ohne Apple-Entwicklerkonto (Swift Playgrounds / Sideloadly) installiert und bekommt deshalb keine iCloud-Berechtigung. Nutze stattdessen Export & Import – der Text lässt sich bequem über AirDrop, die Dateien-App (iCloud Drive) oder die Universal-Zwischenablage auf dein anderes Gerät bringen.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.text])
        }
        .alert(
            "Sicherung importieren?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            presenting: pendingImport
        ) { backup in
            Button("Importieren und ersetzen", role: .destructive) {
                Haptics.warning()
                viewModel.applyBackup(backup)
                pendingImport = nil
                showStatus("Import abgeschlossen.")
            }
            Button("Abbrechen", role: .cancel) {
                pendingImport = nil
            }
        } message: { backup in
            Text("\(backup.summary)\n\nAlle aktuellen Daten auf diesem Gerät werden durch diese Sicherung ersetzt.")
        }
        .alert(
            "Import nicht möglich",
            isPresented: Binding(
                get: { importProblemMessage != nil },
                set: { if !$0 { importProblemMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importProblemMessage = nil }
        } message: {
            Text(importProblemMessage ?? "")
        }
    }

    // MARK: - Aktionen

    private func shareExport() {
        Haptics.tap()
        guard let text = makeExport() else { return }
        shareItem = BackupShareItem(text: text)
    }

    private func copyExportToClipboard() {
        Haptics.tap()
        guard let text = makeExport() else { return }
        UIPasteboard.general.string = text
        Haptics.success()
        showStatus("Sicherung kopiert (\(formattedSize(text.utf8.count))). Auf dem anderen Gerät: Einstellungen → Daten → „Aus Zwischenablage importieren“.")
    }

    private func makeExport() -> String? {
        isPreparingExport = true
        defer { isPreparingExport = false }
        return viewModel.exportBackupString()
    }

    private func prepareImportFromClipboard() {
        Haptics.tap()
        let pasteboard = UIPasteboard.general
        guard pasteboard.hasStrings, let text = pasteboard.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            importProblemMessage = "Die Zwischenablage enthält keinen Text. Kopiere zuerst auf dem anderen Gerät die Sicherung über „Export alles“."
            Haptics.warning()
            return
        }
        guard AppBackupCodec.looksLikeBackup(text) else {
            importProblemMessage = "Der Text in der Zwischenablage ist keine PlanApp-Sicherung."
            Haptics.warning()
            return
        }
        guard let backup = viewModel.decodeBackup(from: text) else {
            importProblemMessage = "Die Sicherung konnte nicht gelesen werden. Möglicherweise wurde der Text beim Kopieren abgeschnitten oder stammt aus einer neueren App-Version."
            Haptics.warning()
            return
        }
        pendingImport = backup
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            statusMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation(.easeIn(duration: 0.25)) {
                if statusMessage == message { statusMessage = nil }
            }
        }
    }

    private func formattedSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.0f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

private struct BackupShareItem: Identifiable {
    let id = UUID()
    let text: String
}
