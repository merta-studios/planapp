import SwiftUI

/// Einstellungsbereich für die WebUntis API Zugangsdaten und Synchronisation
public struct UntisConfigSection: View {
    @EnvironmentObject private var viewModel: TimetableViewModel

    @State private var server: String = ""
    @State private var school: String = ""
    @State private var user: String = ""
    @State private var pass: String = ""
    @State private var autoSync: Bool = true

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Abschnittsüberschrift
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("WebUntis API Verbindung")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            Text("Trage hier die Zugangsdaten deiner Schule ein. PlanApp ruft deinen Stundenplan und die Stundenzeiten automatisch über die WebUntis JSON-RPC Schnittstelle ab.")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.secondary)

            // Eingabefelder
            VStack(spacing: 10) {
                // Server Feld
                HStack {
                    Text("Server:")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .frame(width: 85, alignment: .leading)
                    KeyboardTextField(
                        "z.B. ikarus.webuntis.com",
                        text: $server,
                        capitalization: .none,
                        autocorrection: .no,
                        keyboardType: .URL,
                        contentType: .URL
                    )
                }

                // Schule Feld
                HStack {
                    Text("Schule:")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .frame(width: 85, alignment: .leading)
                    KeyboardTextField(
                        "z.B. gym-musterstadt",
                        text: $school,
                        capitalization: .none,
                        autocorrection: .no
                    )
                }

                // Benutzername Feld
                HStack {
                    Text("Benutzer:")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .frame(width: 85, alignment: .leading)
                    KeyboardTextField(
                        "Dein Untis-Benutzername",
                        text: $user,
                        capitalization: .none,
                        autocorrection: .no,
                        contentType: .username
                    )
                }

                // Passwort Feld
                HStack {
                    Text("Passwort:")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .frame(width: 85, alignment: .leading)
                    KeyboardTextField(
                        "Dein Passwort",
                        text: $pass,
                        isSecure: true,
                        capitalization: .none,
                        autocorrection: .no,
                        contentType: .password,
                        returnKeyType: .done,
                        onSubmit: saveInputs
                    )
                }
            }

            Toggle("Beim App-Start automatisch aktualisieren", isOn: $autoSync)
                .font(.system(size: 14, weight: .regular, design: .default))
                .padding(.top, 4)

            // Speichern Liquid Glass Button
            Button(action: saveInputs) {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Text("Zugangsdaten speichern")
                        .font(.system(size: 14, weight: .regular, design: .default))
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .lightButton(cornerRadius: 10, tint: .blue, isFilled: true)
            .foregroundColor(.white)
            .padding(.top, 4)

            Divider()
                .padding(.vertical, 4)

            // Sync Aktionen
            HStack(spacing: 12) {
                // Synchronisieren Liquid Glass Button
                Button(action: {
                    saveInputs()
                    Task { await viewModel.syncWithUntis() }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .regular, design: .default))
                        }
                        Text("Jetzt synchronisieren")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .lightButton(cornerRadius: 10, tint: .blue)
                .foregroundColor(.blue)
                .disabled(viewModel.isLoading)

                // Beispieldaten laden Liquid Glass Button
                Button(action: {
                    viewModel.loadDemoData()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .regular, design: .default))
                        Text("Demo-Daten laden")
                            .font(.system(size: 14, weight: .regular, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .lightButton(cornerRadius: 10, tint: .orange)
                .foregroundColor(.orange)
            }

            // Statusmeldung & Letzter Sync
            if let lastSync = viewModel.untisCredentials.lastSyncDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .regular, design: .default))
                    Text("Letzte Synchronisation: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12, weight: .regular, design: .default))
                }
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
        .onAppear {
            self.server = viewModel.untisCredentials.server
            self.school = viewModel.untisCredentials.school
            self.user = viewModel.untisCredentials.user
            self.pass = viewModel.untisCredentials.password
            self.autoSync = viewModel.untisCredentials.autoSyncOnLaunch
        }
    }

    private func saveInputs() {
        viewModel.untisCredentials.server = server
        viewModel.untisCredentials.school = school
        viewModel.untisCredentials.user = user
        viewModel.untisCredentials.password = pass
        viewModel.untisCredentials.autoSyncOnLaunch = autoSync
        viewModel.saveCredentials()
        viewModel.successMessage = "Zugangsdaten gespeichert."
    }
}
