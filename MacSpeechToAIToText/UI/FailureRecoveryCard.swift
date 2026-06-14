import SwiftUI

/// Guided recovery card for pipeline failures (Sprint 1 Phase 4).
/// Focuses on making old "Invalid API response" and similar failures actionable.
struct FailureRecoveryCard: View {
    let record: TranscriptionRecord?
    let result: TranscriptionResult?

    var historyStore: HistoryStore
    var transcriptionCleaner: TranscriptionCleaner
    var promptStore: PromptStore
    @Bindable var settings: Settings

    var onActionPerformed: (() -> Void)? = nil

    private var effectiveReason: String {
        if let r = result?.cleanupFailureReason, !r.isEmpty {
            return r
        }
        if let rec = record, let reason = rec.cleanupFailureReason, !reason.isEmpty {
            return reason
        }
        return "AI cleanup failed."
    }

    private var effectiveRawText: String {
        result?.rawText ?? record?.rawText ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("AI Cleanup Failed")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Text(effectiveReason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Action buttons - prominent and practical
            VStack(spacing: 8) {
                // Primary simple action the user wants
                Button {
                    retryCleanup()
                } label: {
                    Label("Re-clean", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                HStack(spacing: 8) {
                    Button {
                        testAIKeyNow()
                    } label: {
                        Label("Test API Key", systemImage: "key")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        copyRawText()
                    } label: {
                        Label("Copy Raw", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    if let rec = record, rec.audioFileName != nil {
                        Button {
                            onActionPerformed?()
                        } label: {
                            Label("Re-transcribe & Clean", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button(role: .destructive) {
                        markAsResolved()
                    } label: {
                        Label("Mark Resolved", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let rec = record, rec.cleanupFailed {
                Text("Raw transcript is preserved. You can safely retry cleanup or re-transcribe.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func retryCleanup() {
        guard !effectiveRawText.isEmpty else { return }

        Task {
            do {
                let cleaned = try await transcriptionCleaner.clean(
                    effectiveRawText,
                    promptID: promptStore.selectedPromptID
                )

                if let rec = record {
                    var updated = rec
                    updated.cleanedText = cleaned
                    updated.cleanupFailed = false
                    updated.cleanupFailureReason = nil
                    historyStore.updateRecord(updated)
                }

                onActionPerformed?()
            } catch {
                if let rec = record {
                    var updated = rec
                    updated.cleanupFailed = true
                    updated.cleanupFailureReason = error.localizedDescription
                    historyStore.updateRecord(updated)
                }
                onActionPerformed?()
            }
        }
    }

    private func testAIKeyNow() {
        // This will be handled by the parent or we can trigger a notification.
        // For now, we rely on the fact that the user has the AIConnectionCard in Dashboard/Settings.
        // We can improve this later by surfacing a sheet.
        onActionPerformed?()
    }

    private func copyRawText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(effectiveRawText, forType: .string)
        onActionPerformed?()
    }

    private func markAsResolved() {
        if let rec = record {
            var updated = rec
            updated.cleanupFailed = false
            updated.cleanupFailureReason = "Manually marked as resolved"
            historyStore.updateRecord(updated)
        }
        onActionPerformed?()
    }
}