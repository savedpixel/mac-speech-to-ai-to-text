import SwiftUI

struct RecordingOverlayView: View {
    var pipelineCoordinator: PipelineCoordinator
    var audioRecorder: AudioRecorder
    @State private var copiedOverlay = false

    var body: some View {
        VStack(spacing: 16) {
            switch pipelineCoordinator.state {
            case .preparingToRecord:
                preparingContent

            case .recording:
                recordingContent

            case .transcribing:
                transcribingContent

            case .cleaning:
                cleaningContent

            case .completed(let result):
                completedContent(result)

            case .error(let message):
                errorContent(message)

            case .idle:
                EmptyView()
                    .onAppear {
                        pipelineCoordinator.dismiss()
                    }
            }
        }
        .padding(20)
        .frame(minWidth: 520, maxWidth: 520, minHeight: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }

    // MARK: - State Views

    private var preparingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Preparing…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 0) {
            // Main waveform area
            AudioWaveformView(
                audioRecorder: audioRecorder
            )
            .frame(height: 180)
            .background(
                Color(red: 0.23, green: 0.23, blue: 0.25)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer().frame(height: 10)

            // Mini overview bar
            MiniWaveformBar(
                audioRecorder: audioRecorder
            )
            .frame(height: 32)
            .background(Color(red: 0.23, green: 0.23, blue: 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer().frame(height: 14)

            // Time counter
            RecordingTimeCounter(audioRecorder: audioRecorder)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))

            Spacer().frame(height: 14)

            HStack(spacing: 10) {
                Button("Cancel") {
                    pipelineCoordinator.cancel()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    pipelineCoordinator.finishRecording()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var transcribingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Transcribing…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var cleaningContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Cleaning up via AI…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func completedContent(_ result: TranscriptionResult) -> some View {
        VStack(spacing: 12) {
            if result.cleanupFailed {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("AI cleanup failed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                if let reason = result.cleanupFailureReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Button("Retry Cleanup") {
                    pipelineCoordinator.retryCleanup()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if result.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("No speech detected", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("Transcription successful", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            ScrollView {
                Text(result.displayText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)

            HStack(spacing: 10) {
                Button(copiedOverlay ? "Copied!" : "Copy") {
                    pipelineCoordinator.copyResult()
                    copiedOverlay = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copiedOverlay = false }
                }
                .buttonStyle(.bordered)

                Button("Insert") {
                    pipelineCoordinator.insertResult()
                }
                .buttonStyle(.borderedProminent)

                Button("Dismiss") {
                    pipelineCoordinator.dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Dismiss") {
                pipelineCoordinator.dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
}
