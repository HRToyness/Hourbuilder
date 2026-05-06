import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Services
import Styling

public struct SettingsView: View {
    // MARK: - AI state

    @State private var activeProvider: AIProvider
    @State private var apiKeyInput: String = ""
    @State private var hasKey: Bool = false
    @State private var apiKeyStatus: String?
    @State private var modelOverrideInput: String = ""

    // MARK: - Branding state

    @State private var accentColor: Color
    @State private var logoData: Data?
    @State private var brandingStatus: String?
    @State private var showLogoPicker = false

    public init() {
        let provider = AISettings.loadProvider()
        _activeProvider = State(initialValue: provider)
        _modelOverrideInput = State(initialValue: AISettings.loadModel(for: provider))
        let hex = BrandingStore.loadAccentHex()
        _accentColor = State(initialValue: Color(hex: hex))
        _logoData = State(initialValue: BrandingStore.loadLogoData())
    }

    public var body: some View {
        TabView {
            aiTab
                .tabItem { Label("AI", systemImage: "sparkles") }
            brandingTab
                .tabItem { Label("Branding", systemImage: "paintpalette.fill") }
        }
        .frame(minWidth: 560, minHeight: 460)
        .padding(20)
    }

    // MARK: - AI tab

    private var aiTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "AI provider",
                subtitle: "Sleutels staan in Keychain — nooit in plaintext, nooit gelogd."
            )

            Picker("Actieve provider", selection: $activeProvider) {
                ForEach(AIProvider.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: activeProvider) { _, newProvider in
                AISettings.saveProvider(newProvider)
                refreshKeyState()
                modelOverrideInput = AISettings.loadModel(for: newProvider)
                apiKeyStatus = "Actief: \(newProvider.label)"
            }

            HStack {
                Image(systemName: hasKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(hasKey ? Color.appAccentDark : Color.appWarning)
                Text(hasKey ? "Sleutel actief" : "Geen sleutel ingesteld")
                    .font(.appBody())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(activeProvider.label) API sleutel")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                    .textCase(.uppercase)
                SecureField(placeholderForKey, text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 360)
            }

            HStack {
                AppPrimaryButton(
                    title: "Opslaan",
                    isDisabled: apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    saveAPIKey()
                }
                AppSecondaryButton(title: "Verwijderen", isDisabled: !hasKey) {
                    deleteAPIKey()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                    .textCase(.uppercase)
                HStack {
                    TextField(defaultModelLabel, text: $modelOverrideInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 220)
                    AppSecondaryButton(title: "Toepassen") {
                        AISettings.saveModel(modelOverrideInput, for: activeProvider)
                        apiKeyStatus = "Model voor \(activeProvider.shortLabel): \(AISettings.loadModel(for: activeProvider))"
                    }
                    AppSecondaryButton(title: "Standaard") {
                        AISettings.saveModel("", for: activeProvider)
                        modelOverrideInput = AISettings.loadModel(for: activeProvider)
                        apiKeyStatus = "Standaardmodel teruggezet."
                    }
                    Spacer()
                }
                Text("Standaard: \(defaultModelLabel)")
                    .font(.appLabel(10))
                    .foregroundStyle(.tertiary)
            }

            if let apiKeyStatus {
                Text(apiKeyStatus)
                    .font(.appBody(12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .onAppear { refreshKeyState() }
    }

    private var placeholderForKey: String {
        switch activeProvider {
        case .claude: return "sk-ant-…"
        case .openai: return "sk-…"
        }
    }

    private var defaultModelLabel: String {
        switch activeProvider {
        case .claude: return AISettings.defaultClaudeModel
        case .openai: return AISettings.defaultOpenAIModel
        }
    }

    // MARK: - Branding tab

    private var brandingTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(
                title: "Branding",
                subtitle: "Accent kleur + logo gebruikt voor PDF exports."
            )

            HStack {
                ColorPicker("Accent kleur", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { _, newValue in
                        let hex = Self.hex(from: newValue)
                        BrandingStore.saveAccentHex(hex)
                        brandingStatus = "Accent opgeslagen."
                    }
                Spacer()
                Button("Reset") {
                    BrandingStore.resetAccent()
                    accentColor = Color(hex: BrandingStore.defaultAccentHex)
                    brandingStatus = "Accent teruggezet naar standaard."
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Logo")
                    .font(.appH2(13))
                if let data = logoData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 80, alignment: .leading)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("Geen logo ingesteld.")
                        .font(.appBody())
                        .foregroundStyle(Color.appTextSecondary)
                }
                HStack {
                    Button(logoData == nil ? "Logo kiezen…" : "Logo vervangen…") {
                        showLogoPicker = true
                    }
                    Button("Verwijderen", role: .destructive) {
                        clearLogo()
                    }
                    .disabled(logoData == nil)
                }
            }

            if let brandingStatus {
                Text(brandingStatus)
                    .font(.appBody(12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .fileImporter(
            isPresented: $showLogoPicker,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importLogo(at: url)
                }
            case .failure(let error):
                brandingStatus = "Logo kiezen mislukt: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Actions

    private func refreshKeyState() {
        hasKey = KeychainHelper.hasAPIKey(for: activeProvider)
    }

    private func saveAPIKey() {
        do {
            try KeychainHelper.saveAPIKey(
                apiKeyInput.trimmingCharacters(in: .whitespaces),
                for: activeProvider
            )
            hasKey = true
            apiKeyInput = ""
            apiKeyStatus = "\(activeProvider.shortLabel) sleutel opgeslagen in Keychain."
        } catch {
            apiKeyStatus = "Opslaan mislukt: \(error.localizedDescription)"
        }
    }

    private func deleteAPIKey() {
        do {
            try KeychainHelper.deleteAPIKey(for: activeProvider)
            hasKey = false
            apiKeyStatus = "\(activeProvider.shortLabel) sleutel verwijderd."
        } catch {
            apiKeyStatus = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    private func importLogo(at url: URL) {
        let security = url.startAccessingSecurityScopedResource()
        defer { if security { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try BrandingStore.saveLogo(data)
            logoData = data
            brandingStatus = "Logo opgeslagen."
        } catch {
            brandingStatus = "Logo importeren mislukt: \(error.localizedDescription)"
        }
    }

    private func clearLogo() {
        do {
            try BrandingStore.clearLogo()
            logoData = nil
            brandingStatus = "Logo verwijderd."
        } catch {
            brandingStatus = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }

    private static func hex(from color: Color) -> UInt32 {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = UInt32(max(0, min(255, nsColor.redComponent * 255)))
        let g = UInt32(max(0, min(255, nsColor.greenComponent * 255)))
        let b = UInt32(max(0, min(255, nsColor.blueComponent * 255)))
        return (r << 16) | (g << 8) | b
    }
}
