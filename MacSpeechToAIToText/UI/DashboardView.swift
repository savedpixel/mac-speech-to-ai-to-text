import SwiftUI

/// Top-level readiness dashboard (Sprint 1 foundation).
/// Shows actionable status for permissions, model, AI connection, shortcuts, and recent activity.
/// Cards will be extracted and enriched in later phases of this sprint.
struct DashboardView: View {
    var historyStore: HistoryStore
    @Bindable var settings: Settings
    var permissionManager: PermissionManager
    var transcriptionEngine: TranscriptionEngine
    var transcriptionCleaner: TranscriptionCleaner
    var promptStore: PromptStore
    var audioSignalPlayer: AudioSignalPlayer

    @State private var lastResultSummary: String = "No recordings yet"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Dashboard")
                        .font(.largeTitle.bold())
                    Spacer()
                    if hasAnyIssues {
                        Label("\(issueCount) items need attention", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Label("Ready to record", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 8)

                Text("Your voice-to-text system status at a glance. Fix issues here before recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // Permissions card (compact readiness)
                readinessCard(title: "Permissions", systemImage: "lock.shield") {
                    VStack(alignment: .leading, spacing: 8) {
                        permissionStatusRow(title: "Accessibility", granted: permissionManager.accessibilityGranted)
                        permissionStatusRow(title: "Microphone", granted: permissionManager.microphoneGranted)
                        permissionStatusRow(title: "Input Monitoring", granted: permissionManager.inputMonitoringGranted)

                        Button("Refresh All") {
                            Task { await permissionManager.checkAllPermissions() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }

                // Model card — wrapped for consistent card styling across Dashboard
                readinessCard(title: "Whisper Model", systemImage: "brain") {
                    ModelReadinessCard(
                        transcriptionEngine: transcriptionEngine,
                        settings: settings,
                        contentOnly: true
                    )
                }

                // AI Connection Card (Phase 3) — status only (no key paste field)
                AIConnectionCard(
                    settings: settings,
                    transcriptionCleaner: transcriptionCleaner
                )

                // Quick actions / last result
                readinessCard(title: "Quick Actions", systemImage: "bolt") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lastResultSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Open History") {
                                // Parent will handle selection change if we expose a binding later
                            }
                            .buttonStyle(.bordered)

                            Button("Start Recording (Shortcut)") {
                                // Visual hint only in Sprint 1 stub
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Spacer(minLength: 20)

                Text("Full readiness cards, one-click recovery, and deeper diagnostics are being added in this Sprint 1 update.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            updateLastResultSummary()
        }
    }

    private var hasAnyIssues: Bool {
        !permissionManager.accessibilityGranted ||
        !permissionManager.microphoneGranted ||
        !permissionManager.inputMonitoringGranted ||
        transcriptionEngine.modelState != .loaded ||
        (settings.aiCleanupEnabled && settings.aiCleanupAPIKey.isEmpty)
    }

    private var issueCount: Int {
        var count = 0
        if !permissionManager.accessibilityGranted { count += 1 }
        if !permissionManager.microphoneGranted { count += 1 }
        if !permissionManager.inputMonitoringGranted { count += 1 }
        if transcriptionEngine.modelState != .loaded { count += 1 }
        if settings.aiCleanupEnabled && settings.aiCleanupAPIKey.isEmpty { count += 1 }
        return count
    }

    private func permissionStatusRow(title: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(title)
            Spacer()
            if !granted {
                Button("Grant") {
                    // Best-effort open; real actions live in Settings for now
                    if title == "Microphone" {
                        permissionManager.openMicrophoneSettings()
                    } else {
                        permissionManager.requestAccessibility()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func readinessCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func updateLastResultSummary() {
        if let latest = historyStore.records.first {
            let preview = (latest.cleanedText ?? latest.rawText).prefix(60)
            lastResultSummary = "Last: \(latest.date.formatted(date: .abbreviated, time: .shortened)) — \(preview)…"
        }
    }
}