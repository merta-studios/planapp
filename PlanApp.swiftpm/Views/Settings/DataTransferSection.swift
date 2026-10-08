import SwiftUI
import UIKit

/// Einstellungen → „Daten“: iCloud-Synchronisation über eine Sync-Datei,
/// komplette Sicherung als Text exportieren (teilen oder kopieren) und aus
/// der Zwischenablage wieder importieren – mit Vorschau und Bestätigung.
struct DataTransferSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var shareItem: BackupShareItem? = nil
    @State private var pendingImport: AppBackup? = nil
    @State private var importProblemMessage: String? = nil
    @State private var statusMessage: String? = nil
    @State private var isPreparingExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FileSyncCard(service: viewModel.fileSyncService)

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

                Text("Erstellt einen Text mit allen gespeicherten Daten: Notizen (Zeichnungen, Textfelder, Bilder, Tags), Stundenplan, Zugangsdaten, Fächer- und Lehrkraft-Anpassungen sowie sämtliche Einstellungen. Den Text kannst du teilen oder kopieren und auf einem anderen Gerät importieren.")
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
                    .liquidGlassButton(cornerRadius: 12, tint: .blue, isFilled: true)
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
                    .liquidGlassButton(cornerRadius: 12, tint: .blue)
                    .foregroundColor(.blue)
                }
                .disabled(isPreparingExport)
                .opacity(isPreparingExport ? 0.6 : 1)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)

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
                .liquidGlassButton(cornerRadius: 12, tint: .green)
                .foregroundColor(.green)
            }
            .padding(DeviceLayout.settingsInnerPadding)
            .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(DeviceLayout.settingsOuterPadding)
        .liquidGlassCard(cornerRadius: 16, strokeOpacity: 0.25)
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

// MARK: - iCloud-Synchronisation

/// Schalter und Status der automatischen Synchronisation über eine
/// Sync-Textdatei in iCloud Drive. Standardmäßig aus; beim Einschalten
/// führt ein Dialog durch die Einrichtung (bestehende Datei wählen oder
/// neue Datei in einem Ordner anlegen).
private struct FileSyncCard: View {
    @ObservedObject var service: FileSyncService

    @State private var showSetup = false
    @State private var showUnlinkConfirmation = false
    @State private var restoreCandidate: FileSyncSafetyBackup? = nil
    @State private var restoreMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { service.isEnabled },
                set: { turnedOn in
                    Haptics.tap()
                    if turnedOn {
                        showSetup = true
                    } else {
                        showUnlinkConfirmation = true
                    }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud-Synchronisierung")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Hält alle Geräte über eine Datei in iCloud Drive automatisch auf demselben Stand.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .disabled(service.isWorking)

            if service.isEnabled {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(service.syncFileDisplayName)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if service.isWorking {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.icloud")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }

                if let lastSync = service.lastSyncDescription {
                    Text("Zuletzt synchronisiert: \(lastSync)")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }

                Button {
                    Haptics.tap()
                    Task {
                        await service.pullNow()
                        await service.pushNow()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Jetzt synchronisieren")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .liquidGlassButton(cornerRadius: 12, tint: .blue)
                .foregroundColor(.blue)
                .disabled(service.isWorking)
            } else {
                Text("Beim Einschalten wirst du gefragt, ob du bereits auf einem anderen Gerät synchronisierst – dann wählst du die bestehende Datei, sonst legst du eine neue an. Es muss eine Datei in iCloud Drive sein.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status = service.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = service.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(.red)
            }

            if !service.safetyBackups.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Automatische Sicherheitskopien")
                            .font(.system(size: 13, weight: .medium, design: .default))
                    }
                    Text("Vor jeder Übernahme eines fremden Stands sichert die App deinen Stand. Die letzten drei bleiben hier und lassen sich zurückholen.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(service.safetyBackups) { backup in
                        HStack(spacing: 8) {
                            Text(backup.summary)
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Button("Zurückholen") {
                                Haptics.tap()
                                restoreCandidate = backup
                            }
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundColor(.blue)
                            Button {
                                Haptics.tap()
                                service.deleteSafetyBackup(id: backup.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                            .accessibilityLabel("Sicherheitskopie löschen")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
        }
        .padding(DeviceLayout.settingsInnerPadding)
        .liquidGlassCard(cornerRadius: 14, strokeOpacity: 0.18)
        .sheet(isPresented: $showSetup) {
            FileSyncSetupSheet(service: service)
        }
        .confirmationDialog(
            "Synchronisation trennen?",
            isPresented: $showUnlinkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Trennen", role: .destructive) {
                Haptics.tap()
                service.unlink()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine Daten und die Sync-Datei bleiben erhalten – es wird nur nicht mehr automatisch synchronisiert.")
        }
        .alert(
            "Sicherheitskopie zurückholen?",
            isPresented: Binding(
                get: { restoreCandidate != nil },
                set: { if !$0 { restoreCandidate = nil } }
            ),
            presenting: restoreCandidate
        ) { backup in
            Button("Zurückholen und ersetzen", role: .destructive) {
                Haptics.warning()
                let message = service.restoreSafetyBackup(backup)
                restoreCandidate = nil
                restoreMessage = message
            }
            Button("Abbrechen", role: .cancel) {
                restoreCandidate = nil
            }
        } message: { backup in
            Text("\(backup.summary)\n\nDer aktuelle Stand wird vorher erneut gesichert. Danach wird die Kopie auf alle Geräte verteilt.")
        }
    }
}

/// Einrichtung beim Einschalten: „Hast du bereits auf einem anderen Gerät
/// die Synchronisierung aktiviert?“ – Ja wählt die bestehende Textdatei,
/// Nein legt über einen Ordner eine neue Datei an.
private struct FileSyncSetupSheet: View {
    @ObservedObject var service: FileSyncService
    @Environment(\.dismiss) private var dismiss

    @State private var showFolderPicker = false
    @State private var showFilePicker = false
    @State private var isLinking = false
    @State private var failureMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "icloud")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud-Synchronisierung")
                            .font(.system(size: 17, weight: .semibold, design: .default))
                        Text("Alle Geräte teilen sich eine Datei in iCloud Drive.")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }
                }

                Text("Hast du bereits auf einem anderen Gerät die Synchronisierung aktiviert?")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button {
                        Haptics.tap()
                        showFilePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ja (bestehende Datei auswählen)")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                Text("Wähle die Sync-Datei in iCloud Drive. Deine Daten werden mit ihr zusammengeführt – es geht nichts verloren.")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .opacity(0.85)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    .liquidGlassButton(cornerRadius: 14, tint: .blue, isFilled: true)
                    .foregroundColor(.white)
                    .disabled(isLinking)

                    Button {
                        Haptics.tap()
                        showFolderPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nein (neue Datei anlegen)")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                Text("Wähle einen Ordner in iCloud Drive – darin wird die Sync-Datei angelegt und mit deinen Daten gefüllt.")
                                    .font(.system(size: 12, weight: .regular, design: .default))
                                    .opacity(0.85)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    .liquidGlassButton(cornerRadius: 14, tint: .green)
                    .foregroundColor(.green)
                    .disabled(isLinking)
                }

                if isLinking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Wird eingerichtet …")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Sync einrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        Haptics.tap()
                        dismiss()
                    }
                    .disabled(isLinking)
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                SyncFolderPicker(
                    onPick: { url in
                        showFolderPicker = false
                        linkNewFile(in: url)
                    },
                    onCancel: { showFolderPicker = false }
                )
            }
            .sheet(isPresented: $showFilePicker) {
                SyncTextFilePicker(
                    onPick: { url in
                        showFilePicker = false
                        linkExistingFile(at: url)
                    },
                    onCancel: { showFilePicker = false }
                )
            }
            .alert(
                "Verknüpfung fehlgeschlagen",
                isPresented: Binding(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { failureMessage = nil }
            } message: {
                Text(failureMessage ?? "")
            }
        }
    }

    private func linkNewFile(in folderURL: URL) {
        guard !isLinking else { return }
        isLinking = true
        Task {
            let outcome = await service.linkNewFile(in: folderURL)
            isLinking = false
            switch outcome {
            case .linked:
                Haptics.success()
                dismiss()
            case .failed(let message):
                Haptics.warning()
                failureMessage = message
            }
        }
    }

    private func linkExistingFile(at fileURL: URL) {
        guard !isLinking else { return }
        isLinking = true
        Task {
            let outcome = await service.linkExistingFile(at: fileURL)
            isLinking = false
            switch outcome {
            case .linked:
                Haptics.success()
                dismiss()
            case .failed(let message):
                Haptics.warning()
                failureMessage = message
            }
        }
    }
}
