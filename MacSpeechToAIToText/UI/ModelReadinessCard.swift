import SwiftUI

/// Reusable card for Whisper model readiness (Sprint 1).
/// Renders the exact states requested in the 2026-06-01 audit:
/// Not downloaded / Downloaded, not loaded / Preparing / Ready / Failed preparation / Corrupt/needs repair.
struct ModelReadinessCard: View {
    var transcriptionEngine: TranscriptionEngine
    @Bindable var settings: Settings

    /// When true, the card renders only its inner content (no outer material/background).
    /// This lets the parent (e.g. Dashboard) apply a consistent card wrapper.
    var contentOnly: Bool = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Whisper Model", systemImage: "brain")
                    .font(.headline)
                Spacer()
                Text(Settings.whisperModelDisplayName(settings.whisperModel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let readiness = transcriptionEngine.selectedModelReadiness

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                statusView(for: readiness)

                Spacer()

                if case .ready = readiness {
                    Label("Instant", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if case .preparing = readiness {
                Text("First-time preparation (especially large models) can take 15–60 seconds. Subsequent launches will be near-instant with Fast Mode enabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions(for: readiness)
        }

        if contentOnly {
            content
        } else {
            content
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func statusView(for readiness: ModelReadiness) -> some View {
        switch readiness {
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.weight(.medium))

        case .preparing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Preparing…")
                    .foregroundStyle(.orange)
            }

        case .downloadedNotLoaded:
            Label("Downloaded, not loaded", systemImage: "arrow.down.circle")
                .foregroundStyle(.orange)

        case .notDownloaded:
            Label("Not downloaded", systemImage: "icloud.and.arrow.down")
                .foregroundStyle(.secondary)

        case .failedPreparation(let msg):
            Label("Failed: \(msg)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)

        case .corruptOrNeedsRepair(let msg):
            Label("Corrupt: \(msg)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func actions(for readiness: ModelReadiness) -> some View {
        HStack(spacing: 8) {
            if !readiness.isReady {
                Button(readiness == .preparing ? "Force Prepare Now" : "Prepare Now") {
                    Task { await transcriptionEngine.loadModel(settings.whisperModel) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if case .preparing = readiness {
                Button("Cancel") {
                    transcriptionEngine.cancelModelLoad()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if case .failedPreparation = readiness {
                Button("Retry") {
                    Task { await transcriptionEngine.reloadModel() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if case .corruptOrNeedsRepair = readiness {
                Button("Repair / Redownload") {
                    Task { await transcriptionEngine.reloadModel() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if settings.keepWhisperModelWarm {
                Text("Fast mode on")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
    }
}