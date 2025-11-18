import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeAPIKey") private var claudeAPIKey: String = ""
    @AppStorage("maxSearchResults") private var maxSearchResults: Int = 100
    @AppStorage("enableFilePreview") private var enableFilePreview: Bool = true

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ClaudeSettingsView(apiKey: $claudeAPIKey)
                .tabItem {
                    Label("Claude", systemImage: "brain")
                }

            SearchSettingsView(maxResults: $maxSearchResults)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("enableFilePreview") private var enableFilePreview: Bool = true
    @AppStorage("showHiddenFiles") private var showHiddenFiles: Bool = false

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Enable file preview", isOn: $enableFilePreview)
                Toggle("Show hidden files", isOn: $showHiddenFiles)
            }
        }
        .padding()
    }
}

struct ClaudeSettingsView: View {
    @Binding var apiKey: String
    @Environment(AppState.self) private var appState

    @State private var cliVersion: String?
    @State private var isAuthenticated: Bool = false
    @State private var isCLIAvailable: Bool = false
    @State private var isCheckingAuth: Bool = false

    var body: some View {
        Form {
            // Claude Code CLI Status Section
            Section("Claude Agent SDK") {
                HStack {
                    Image(systemName: isCLIAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCLIAvailable ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Agent SDK")
                            .font(.body)

                        if let version = cliVersion {
                            Text("Version: \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if isCLIAvailable {
                            Text("Installed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not installed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if !isCLIAvailable {
                        Link(destination: URL(string: "https://docs.claude.com")!) {
                            Text("Install")
                                .font(.caption)
                        }
                    }
                }

                if isCLIAvailable {
                    Divider()

                    HStack {
                        Image(systemName: isAuthenticated ? "person.fill.checkmark" : "person.fill.xmark")
                            .foregroundColor(isAuthenticated ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Authentication Status")
                                .font(.body)

                            Text(isAuthenticated ? "Authenticated with Claude.ai" : "Not authenticated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isCheckingAuth {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if !isAuthenticated {
                            Button("Sign In") {
                                Task {
                                    await authenticateWithClaude()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Button("Refresh Status") {
                        Task {
                            await checkAuthenticationStatus()
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Text(isCLIAvailable ?
                     "Using Claude Agent SDK v0.1.37 with full agentic capabilities" :
                     "Install Claude Agent SDK for advanced features or use API key below"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider()

            // API Key Fallback Section
            Section("API Key (Fallback)") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Text("API key is used only when Claude Code CLI is not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Features") {
                Text("Claude integration allows you to:")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Summarize documents")
                    Text("• Search with natural language")
                    Text("• Extract information")
                    Text("• Analyze content")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .task {
            await checkAuthenticationStatus()
        }
    }

    private func checkAuthenticationStatus() async {
        isCheckingAuth = true
        defer { isCheckingAuth = false }

        // Check if CLI is available
        isCLIAvailable = appState.claudeService.isCLIAvailable()

        // Get version if available
        if isCLIAvailable {
            cliVersion = await appState.claudeService.getCLIVersion()
        }

        // Check authentication status
        isAuthenticated = await appState.claudeService.isAuthenticated()
    }

    private func authenticateWithClaude() async {
        isCheckingAuth = true
        defer { isCheckingAuth = false }

        do {
            try await appState.claudeService.authenticate()
            // Recheck status after authentication
            await checkAuthenticationStatus()
        } catch {
            print("Authentication error: \(error)")
        }
    }
}

struct SearchSettingsView: View {
    @Binding var maxResults: Int
    @AppStorage("searchInContent") private var searchInContent: Bool = true

    var body: some View {
        Form {
            Section("Search Options") {
                Toggle("Search in file content", isOn: $searchInContent)

                Stepper("Max results: \(maxResults)", value: $maxResults, in: 10...1000, step: 10)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
