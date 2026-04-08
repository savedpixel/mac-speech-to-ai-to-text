import Foundation
import WhisperKit
import os

struct DownloadedModel: Identifiable {
    let name: String
    let sizeBytes: Int64
    let path: URL
    var id: String { name }
}

@Observable
final class TranscriptionEngine {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "transcription")

    private let settings: Settings
    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var isTranscribing = false
    private(set) var loadedModelName: String?

    /// Available models from WhisperKit (fetched from remote)
    private(set) var availableModels: [String] = []
    /// Models downloaded locally on disk
    private(set) var downloadedModels: [DownloadedModel] = []

    enum ModelState: Equatable {
        case notLoaded
        case loading
        case loaded
        case failed(String)
    }

    private(set) var modelState: ModelState = .notLoaded

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Model Discovery

    /// Fetch available models from WhisperKit's remote model list.
    func fetchAvailableModels() async {
        do {
            let models = try await WhisperKit.fetchAvailableModels()
            // Filter to openai_whisper- prefix, strip prefix for display
            let filtered = models
                .filter { $0.hasPrefix("openai_whisper-") }
                .map { $0.replacingOccurrences(of: "openai_whisper-", with: "") }
                .sorted()
            await MainActor.run {
                self.availableModels = filtered.isEmpty ? Settings.fallbackModels : filtered
            }
            logger.info("Fetched \(self.availableModels.count) available models")
        } catch {
            logger.warning("Failed to fetch available models, using fallbacks: \(error.localizedDescription)")
            await MainActor.run {
                self.availableModels = Settings.fallbackModels
            }
        }
    }

    /// Scan the local Hub cache for downloaded WhisperKit models.
    func scanDownloadedModels() {
        let fm = FileManager.default
        // Hub API defaults to documentDirectory/huggingface/models/<repo>
        guard let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            downloadedModels = []
            return
        }
        let modelDir = documentsDir
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true)

        guard let contents = try? fm.contentsOfDirectory(at: modelDir, includingPropertiesForKeys: nil) else {
            downloadedModels = []
            return
        }

        var found: [DownloadedModel] = []
        for item in contents where item.lastPathComponent.hasPrefix("openai_whisper-") {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = directorySize(url: item)
            let name = item.lastPathComponent.replacingOccurrences(of: "openai_whisper-", with: "")
            found.append(DownloadedModel(name: name, sizeBytes: size, path: item))
        }
        downloadedModels = found.sorted { $0.name < $1.name }
        logger.info("Found \(found.count) downloaded models")
    }

    /// Delete a downloaded model from local cache.
    func deleteModel(_ name: String) throws {
        guard let model = downloadedModels.first(where: { $0.name == name }) else { return }
        try FileManager.default.removeItem(at: model.path)
        downloadedModels.removeAll(where: { $0.name == name })
        logger.info("Deleted model: \(name)")
    }

    private func directorySize(url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - Model Loading

    /// Returns the local folder path for a downloaded model, normalising underscores/hyphens.
    private func localModelPath(for modelName: String) -> String? {
        let normalized = modelName.lowercased().replacingOccurrences(of: "_", with: "-")
        return downloadedModels.first(where: {
            $0.name.lowercased().replacingOccurrences(of: "_", with: "-") == normalized
        })?.path.path
    }

    /// Load the Whisper model in the background.
    func loadModel() async {
        let modelName = settings.whisperModel
        logger.info("Loading Whisper model: \(modelName)")
        modelState = .loading

        // Scan locally first so we can bypass Hub lookup when possible
        if downloadedModels.isEmpty {
            scanDownloadedModels()
        }

        let localPath = localModelPath(for: modelName)

        do {
            let config: WhisperKitConfig
            if let localPath {
                logger.info("Loading from local path: \(localPath)")
                config = WhisperKitConfig(
                    model: "openai_whisper-\(modelName)",
                    modelFolder: localPath,
                    verbose: false,
                    prewarm: true
                )
            } else {
                logger.info("No local model found for '\(modelName)', attempting download…")
                config = WhisperKitConfig(
                    model: "openai_whisper-\(modelName)",
                    verbose: false,
                    prewarm: true
                )
            }
            whisperKit = try await WhisperKit(config)
            isModelLoaded = true
            loadedModelName = modelName
            modelState = .loaded
            logger.info("Whisper model loaded successfully")
        } catch {
            logger.error("Failed to load Whisper model: \(error.localizedDescription)")
            isModelLoaded = false
            loadedModelName = nil
            modelState = .failed(error.localizedDescription)
        }
    }

    /// Load a specific model variant (for re-transcription with a different model).
    func loadModel(_ name: String) async {
        settings.whisperModel = name
        whisperKit = nil
        isModelLoaded = false
        await loadModel()
    }

    /// Reload with the current model from settings (e.g. after user changes model).
    func reloadModel() async {
        whisperKit = nil
        isModelLoaded = false
        loadedModelName = nil
        await loadModel()
    }

    // MARK: - Transcription

    /// Transcribe audio from a file URL.
    func transcribe(audioFileURL: URL) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        isTranscribing = true
        defer { isTranscribing = false }

        logger.info("Transcribing: \(audioFileURL.lastPathComponent)")

        let results = try await whisperKit.transcribe(audioPath: audioFileURL.path)

        let text = results
            .compactMap(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        logger.info("Transcription complete: \(text.prefix(50))…")
        return text
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please wait for model initialization."
        }
    }
}
