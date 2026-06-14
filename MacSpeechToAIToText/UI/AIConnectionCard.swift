import SwiftUI

/// Reusable AI Connection status + actions card (Sprint 1 Phase 3).
/// Shows provider, model, key suffix, last test result with status chip,
/// and direct Test / Replace actions.
struct AIConnectionCard: View {
    @Bindable var settings: Settings
    var transcriptionCleaner: TranscriptionCleaner

    /// When true, the card shows a field to paste a replacement key and handles the full
    /// "paste → test pasted key first → save only on success" flow (recommended in Settings).
    var showKeyReplacementField: Bool = false

    @State private var pastedKeyText: String = ""
    @State private var testState: TestConnectionState = .idle
    @State private var isTesting = false

    private enum TestConnectionState {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("AI Cleanup", systemImage: "sparkles")
                    .font(.headline)
                Spacer()

                if settings.aiCleanupEnabled {
                    Text("Enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            if settings.aiCleanupEnabled {
                // Provider + Model row
                HStack(spacing: 6) {
                    Text(settings.aiCleanupProvider.displayName)
                        .font(.subheadline.weight(.medium))
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(settings.resolvedModel)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Endpoint (redacted if long)
                LabeledContent("Endpoint") {
                    Text(shortEndpoint(settings.aiCleanupProvider.fullEndpointURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                // Key status
                HStack {
                    if let suffix = settings.aiCleanupAPIKeySuffix {
                        Text("Key saved (…\(suffix))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No API key saved")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                }
                .font(.caption)
                .textSelection(.enabled)

                // Last test status chip
                lastTestStatusView

                // Key replacement field (only shown in Settings context)
                if showKeyReplacementField {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Paste new API key to replace stored key", text: $pastedKeyText)
                            .textContentType(.password)

                        Text("Test first, save only on success")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Actions
                HStack(spacing: 8) {
                    let buttonTitle = isTesting ? "Testing..." :
                        (pastedKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Test Connection" : "Save & Test Connection")

                    Button(buttonTitle) {
                        testConnection()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isTesting)
                }

                if let msg = settings.lastAIKeyTestMessage, !msg.isEmpty {
                    Text("Last result: \(msg)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("AI cleanup is disabled. Transcripts will be saved as raw text only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var lastTestStatusView: some View {
        HStack(spacing: 6) {
            let (label, color, icon) = statusInfo
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption)
            .foregroundStyle(color)

            if let date = settings.lastAIKeyTestDate, date > .distantPast {
                Text("• \(date, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusInfo: (String, Color, String) {
        if isTesting {
            return ("Testing…", .blue, "arrow.triangle.2.circlepath")
        }

        if settings.aiCleanupAPIKeySuffix == nil {
            return ("No key", .orange, "exclamationmark.triangle.fill")
        }

        if let msg = settings.lastAIKeyTestMessage?.lowercased() {
            if msg.contains("connected") || msg.contains("success") || msg.contains("ok") {
                return ("Connected", .green, "checkmark.circle.fill")
            } else if msg.contains("fail") || msg.contains("error") || msg.contains("invalid") {
                return ("Failed", .red, "xmark.circle.fill")
            }
        }

        return ("Untested", .secondary, "questionmark.circle")
    }

    private func shortEndpoint(_ url: String) -> String {
        if url.count > 45 {
            let prefix = String(url.prefix(25))
            return prefix + "…"
        }
        return url
    }

    private func testConnection() {
        isTesting = true
        testState = .testing

        let pasted = pastedKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplacement = !pasted.isEmpty

        Task {
            let result = await transcriptionCleaner.testAPIKey(apiKey: isReplacement ? pasted : nil)
            await MainActor.run {
                let now = Date()
                settings.lastAIKeyTestDate = now

                switch result {
                case .success(let preview):
                    let message = preview.isEmpty ? "Connected: OK" : "Connected: \(preview)"

                    if isReplacement {
                        // The live API test succeeded. Now prove the key was actually persisted
                        // before claiming success or clearing the pasted replacement field.
                        guard settings.saveAICleanupAPIKey(pasted),
                              settings.aiCleanupAPIKey.trimmingCharacters(in: .whitespacesAndNewlines) == pasted else {
                            let saveFailure = "Connection worked, but Keychain save failed. The key was not stored."
                            settings.lastAIKeyTestMessage = saveFailure
                            testState = .failure(saveFailure)
                            isTesting = false
                            return
                        }
                        pastedKeyText = ""
                    } else if settings.aiCleanupAPIKeySuffix == nil {
                        let missingKey = "Connection test cannot be saved because no API key is stored. Paste a key and choose Save & Test Connection."
                        settings.lastAIKeyTestMessage = missingKey
                        testState = .failure(missingKey)
                        isTesting = false
                        return
                    }

                    let suffixNote = settings.aiCleanupAPIKeySuffix.map { " with saved key …\($0)" } ?? ""
                    let savedMessage = message + suffixNote
                    settings.lastAIKeyTestMessage = savedMessage
                    testState = .success(isReplacement ? "Saved & connected: \(savedMessage)" : savedMessage)

                case .failure(let error):
                    let prefix = isReplacement ? "New pasted key failed: " : ""
                    let message = prefix + error.localizedDescription
                    settings.lastAIKeyTestMessage = message
                    testState = .failure(message)
                }

                isTesting = false
            }
        }
    }
}