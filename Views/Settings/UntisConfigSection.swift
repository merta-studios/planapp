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
        Section(header: Text("WebUntis API Verbindung").font(.system(size: 14, weight: .bold))) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Trage hier die Zugangsdaten deiner Schule ein. PlanApp ruft deinen Stundenplan und die Stundenzeiten automatisch über die WebUntis JSON-RPC Schnittstelle ab.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Server Feld
                HStack {
                    Text("Server:")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("z.B. ikarus.webuntis.com", text: $server)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Schule Feld
                HStack {
                    Text("Schule:")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("z.B. gym-musterstadt", text: $school)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Benutzername Feld
                HStack {
                    Text("Benutzer:")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("Dein Untis-Benutzername", text: $user)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Passwort Feld
                HStack {
                    Text("Passwort:")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    SecureField("Dein Passwort", text: $pass)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Toggle("Beim App-Start automatisch aktualisieren", isOn: $autoSync)
                    .padding(.top, 4)

                // Speichern Button
                Button(action: saveInputs) {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                        Text("Zugangsdaten speichern")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .hoverEffect(.lift)
                .padding(.top, 4)

                Divider()
                    .padding(.vertical, 6)

                // Sync Aktionen
                HStack(spacing: 12) {
                    // Synchronisieren
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
                            }
                            Text("Jetzt synchronisieren")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                    .disabled(viewModel.isLoading)

                    // Beispieldaten laden
                    Button(action: {
                        viewModel.loadDemoData()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Demo-Daten laden")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverEffect(.lift)
                }

                // Statusmeldung & Letzter Sync
                if let lastSync = viewModel.untisCredentials.lastSyncDate {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("Letzte Synchronisation: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 6)
        }
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
    }
}
