import SwiftUI

/// Settings: language, providers, data, about. DEBUG adds provider diagnostics/demo tools.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.localized("settings.language")) {
                    ForEach([AppLanguage.system, .english, .russian]) { language in
                        Button {
                            settings.language = language
                        } label: {
                            HStack {
                                Text(languageTitle(language))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.language == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .accessibilityIdentifier("language_\(language.rawValue)")
                    }
                }

                Section(settings.localized("settings.search")) {
                    Toggle("Google", isOn: googleBinding)
                        .accessibilityIdentifier("googleToggle")
                    Toggle("Allegro", isOn: allegroBinding)
                        .accessibilityIdentifier("allegroToggle")
                }

                Section(settings.localized("settings.data")) {
                    Button(settings.localized("history.clear"), role: .destructive) {
                        container.historyRepository.clearAll()
                    }
                }

                Section(settings.localized("settings.about")) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                        Text(settings.localized("settings.privacy.note"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(settings.localized("settings.experimental.note"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(settings.localized("settings.version"))
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                Section("DEBUG") {
                    Toggle("Use fixture data (demo mode)", isOn: fixtureBinding)
                        .accessibilityIdentifier("fixtureToggle")
                    NavigationLink("Provider diagnostics") {
                        ProviderDiagnosticsView()
                            .environment(container)
                            .environment(settings)
                    }
                }
                #endif
            }
            .navigationTitle(settings.localized("settings.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.localized("action.done")) { dismiss() }
                }
            }
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { settings.language }, set: { settings.language = $0 })
    }

    private func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system: return settings.localized("settings.language.system")
        case .english: return "English"
        case .russian: return "Русский"
        }
    }

    private var googleBinding: Binding<Bool> {
        Binding(get: { settings.isGoogleEnabled },
                set: { settings.setProvider(.google, enabled: $0) })
    }

    private var allegroBinding: Binding<Bool> {
        Binding(get: { settings.isAllegroEnabled },
                set: { settings.setProvider(.allegro, enabled: $0) })
    }

    #if DEBUG
    private var fixtureBinding: Binding<Bool> {
        Binding(get: { container.useFixtureData }, set: { container.useFixtureData = $0 })
    }
    #endif

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
