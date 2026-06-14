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
        case preparingLocal
        case downloading
        case loaded
        case failed(String)
    }

    private(set) var modelState: ModelState = .notLoaded

    private static let hubSubpath = "models/argmaxinc/whisperkit-coreml"

    /// Default Hub cache directory (~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/).
    private var defaultHubModelDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/\(Self.hubSubpath)", isDirectory: true)
    }

    /// The downloadBase URL passed to WhisperKit.
    /// If user set a custom path, use that; otherwise nil (WhisperKit default).
    private var downloadBaseURL: URL? {
        let customPath = settings.modelStoragePath
        guard !customPath.isEmpty else { return nil }
        return URL(fileURLWithPath: customPath)
    }

    /// Primary directory where openai_whisper-* model directories actually reside.
    /// Hub library creates {downloadBase}/models/argmaxinc/whisperkit-coreml/ inside any base.
    private var modelStorageDirectory: URL {
        if let base = downloadBaseURL {
            let dir = base.appendingPathComponent(Self.hubSubpath, isDirectory: true)
            let fm = FileManager.default
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        }
        return defaultHubModelDirectory
    }

    /// All directories to scan for models.
    private var allModelDirectories: [URL] {
        var dirs = [modelStorageDirectory]
        // Also scan default Hub cache if using a custom path
        if downloadBaseURL != nil {
            dirs.append(defaultHubModelDirectory)
        }
        return dirs
    }

    init(settings: Settings) {
        self.settings = settings
    }

    /// Merge downloaded model names into the available models list so the picker always shows them.
    private func mergeDownloadedIntoAvailable(_ models: [String]) -> [String] {
        var combined = models
        for dm in downloadedModels {
            let normalizedDM = normalizeModelName(dm.name)
            let alreadyPresent = combined.contains { normalizeModelName($0) == normalizedDM }
            if !alreadyPresent {
                combined.append(dm.name)
            }
        }
        return combined
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
                self.availableModels = self.mergeDownloadedIntoAvailable(filtered.isEmpty ? Settings.fallbackModels : filtered)
            }
            logger.info("Fetched \(self.availableModels.count) available models")
        } catch {
            logger.warning("Failed to fetch available models, using fallbacks: \(error.localizedDescription)")
            await MainActor.run {
                self.availableModels = self.mergeDownloadedIntoAvailable(Settings.fallbackModels)
            }
        }
    }

    /// Scan both App Support and legacy Hub cache for downloaded WhisperKit models.
    /// Only models passing integrity validation (contain .mlmodelc with weight.bin) are included.
    func scanDownloadedModels() {
        var found: [DownloadedModel] = []

        // Scan directories: primary (App Support) + legacy Hub cache
        let dirsToScan = allModelDirectories

        let fm = FileManager.default
        var seenNames: Set<String> = []

        for dir in dirsToScan {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in contents where item.lastPathComponent.hasPrefix("openai_whisper-") {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else { continue }
                guard isModelDirectoryValid(item) else {
                    logger.warning("Skipping corrupt model directory: \(item.lastPathComponent, privacy: .public)")
                    continue
                }
                let name = item.lastPathComponent.replacingOccurrences(of: "openai_whisper-", with: "")
                guard !seenNames.contains(name) else { continue } // prefer first (App Support)
                seenNames.insert(name)
                let size = directorySize(url: item)
                found.append(DownloadedModel(name: name, sizeBytes: size, path: item))
            }
        }
        downloadedModels = found.sorted { $0.name < $1.name }
        availableModels = mergeDownloadedIntoAvailable(availableModels.isEmpty ? Settings.fallbackModels : availableModels)
        logger.info("Found \(found.count) valid downloaded models")
    }

    /// Validate that a model directory contains at least one .mlmodelc with a weights/weight.bin file.
    private func isModelDirectoryValid(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return false }
        for item in contents where item.lastPathComponent.hasSuffix(".mlmodelc") {
            let weightFile = item.appendingPathComponent("weights/weight.bin")
            if fm.fileExists(atPath: weightFile.path) {
                return true
            }
        }
        return false
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

    /// Normalise a model name for comparison: lowercase, underscores → hyphens, strip size suffixes.
    private func normalizeModelName(_ name: String) -> String {
        var n = name.lowercased().replacingOccurrences(of: "_", with: "-")
        // Strip size suffixes like -947mb, -954mb so "large-v3-turbo-954mb" matches "large-v3-turbo"
        if let range = n.range(of: #"-\d+mb$"#, options: .regularExpression) {
            n.removeSubrange(range)
        }
        return n
    }

    private func canonicalModelName(_ name: String) -> String {
        let normalized = normalizeModelName(name)
        let canonicalSources = availableModels + Settings.fallbackModels
        if let canonical = canonicalSources.first(where: { normalizeModelName($0) == normalized }) {
            return canonical
        }
        return name
    }

    func preferredSelectionName(for name: String) -> String {
        canonicalModelName(name)
    }

    func selectModel(_ name: String) {
        let canonicalName = canonicalModelName(name)
        settings.whisperModel = canonicalName

        if isReadyToTranscribe(modelName: canonicalName) {
            modelState = .loaded
            return
        }

        if let loadingModelName, normalizeModelName(loadingModelName) == normalizeModelName(canonicalName) {
            return
        }

        modelState = .notLoaded
    }

    func availableModelsToDownload() -> [String] {
        let downloadedNames = Set(downloadedModels.map { normalizeModelName($0.name) })
        let sourceModels = availableModels.isEmpty ? Settings.fallbackModels : availableModels
        return sourceModels.filter { !downloadedNames.contains(normalizeModelName($0)) }
    }

    func isSelectedModel(_ name: String) -> Bool {
        normalizeModelName(settings.whisperModel) == normalizeModelName(name)
    }

    func isLoadedModel(_ name: String) -> Bool {
        guard let loadedModelName else { return false }
        return normalizeModelName(loadedModelName) == normalizeModelName(name) && isModelLoaded
    }

    private func isReadyToTranscribe(modelName: String) -> Bool {
        guard let loadedModelName, whisperKit != nil else { return false }
        return isModelLoaded && normalizeModelName(loadedModelName) == normalizeModelName(modelName)
    }

    /// Returns the exact model directory path for a downloaded model.
    private func localModelPath(for modelName: String) -> String? {
        let target = normalizeModelName(modelName)
        guard let model = downloadedModels.first(where: {
            normalizeModelName($0.name) == target
        }) else { return nil }
        return model.path.path
    }

    /// Only purge a cached local model when the failure points to unreadable/missing model files.
    /// Tokenizer or network-related failures should leave the model cache intact.
    private func shouldRedownloadLocalModel(after error: Error) -> Bool {
        if let whisperError = error as? WhisperError {
            switch whisperError {
            case .tokenizerUnavailable:
                return false
            case .modelsUnavailable(let message):
                return isLocalModelCorruptionMessage(message)
            default:
                return false
            }
        }

        return isLocalModelCorruptionMessage(error.localizedDescription)
    }

    private func isLocalModelCorruptionMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()

        if normalized.contains("tokenizer") {
            return false
        }

        return normalized.contains("model file not found")
            || normalized.contains("model folder is not set")
            || normalized.contains("could not open")
            || normalized.contains("weight.bin")
            || normalized.contains(".mlmodelc")
    }

    private var isLoadingModel = false
    private var loadingTask: Task<Void, Never>?
    private var loadingModelName: String?

    func cancelModelLoad() {
        loadingTask?.cancel()
        modelState = .notLoaded
        logger.info("Model load cancelled by user")
    }

    private func startOrJoinModelLoad(for requestedModelName: String, forceReload: Bool = false) async {
        let modelName = canonicalModelName(requestedModelName)

        if !forceReload && isReadyToTranscribe(modelName: modelName) {
            return
        }

        if let loadingTask, let loadingModelName {
            let isSameModel = normalizeModelName(loadingModelName) == normalizeModelName(modelName)
            if isSameModel && !forceReload {
                logger.info("Awaiting in-flight model load for \(modelName, privacy: .public)")
                await loadingTask.value
                return
            }

            logger.info("Cancelling in-flight model load for \(loadingModelName, privacy: .public) in favor of \(modelName, privacy: .public)")
            loadingTask.cancel()
            await loadingTask.value
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadModel(named: modelName)
        }
        self.loadingTask = task
        self.loadingModelName = modelName
        await task.value
    }

    /// Load the Whisper model in the background.
    /// Uses the exact model directory if found locally, otherwise downloads fresh.
    /// On failure with a local model, deletes it and retries once with a fresh download.
    private func performLoadModel(named modelName: String) async {
        guard !isLoadingModel else {
            logger.info("Model load already in progress, skipping")
            return
        }
        isLoadingModel = true
        defer {
            isLoadingModel = false
            loadingTask = nil
            loadingModelName = nil
        }

        logger.info("Loading Whisper model: \(modelName, privacy: .public)")

        // Always rescan so path changes and newly-downloaded models are resolved from disk.
        scanDownloadedModels()

        let localPath = localModelPath(for: modelName)
        modelState = localPath != nil ? .preparingLocal : .downloading

        do {
            try Task.checkCancellation()
            let config: WhisperKitConfig
            if let localPath {
                // Local model found — pass exact directory containing .mlmodelc files
                logger.info("Loading from local cache: \(localPath, privacy: .public)")
                config = WhisperKitConfig(
                    downloadBase: self.downloadBaseURL,
                    modelFolder: localPath,
                    verbose: false,
                    prewarm: false
                )
            } else {
                // No local model — download via WhisperKit into configured directory
                logger.info("No local model found for '\(modelName, privacy: .public)', downloading…")
                config = WhisperKitConfig(
                    model: "openai_whisper-\(modelName)",
                    downloadBase: self.downloadBaseURL,
                    verbose: false,
                    prewarm: false
                )
            }
            whisperKit = try await WhisperKit(config)
            try Task.checkCancellation()
            isModelLoaded = true
            loadedModelName = modelName
            modelState = .loaded
            scanDownloadedModels()
            logger.info("Whisper model loaded successfully")
        } catch is CancellationError {
            logger.info("Model load was cancelled")
            modelState = .notLoaded
            return
        } catch {
            logger.error("Failed to load Whisper model: \(error.localizedDescription, privacy: .public)")

            // If we had a local copy and the on-disk model files are unreadable, delete it and retry once.
            if let localPath, shouldRedownloadLocalModel(after: error) {
                let failedURL = URL(fileURLWithPath: localPath)
                logger.warning("Deleting failed model at: \(localPath, privacy: .public)")
                try? FileManager.default.removeItem(at: failedURL)
                scanDownloadedModels()

                do {
                    // Fresh download — don't pass modelFolder, let WhisperKit download
                    let retryConfig = WhisperKitConfig(
                        model: "openai_whisper-\(modelName)",
                        downloadBase: self.downloadBaseURL,
                        verbose: false,
                        prewarm: false
                    )
                    logger.info("Retry: downloading fresh model")
                    whisperKit = try await WhisperKit(retryConfig)
                    isModelLoaded = true
                    loadedModelName = modelName
                    modelState = .loaded
                    scanDownloadedModels()
                    logger.info("Whisper model loaded successfully on retry")
                    return
                } catch {
                    logger.error("Retry also failed: \(error.localizedDescription)")
                }
            } else if localPath != nil {
                logger.warning("Keeping cached local model; failure did not indicate model corruption")
            }

            isModelLoaded = false
            loadedModelName = nil
            modelState = .failed(error.localizedDescription)
        }
    }

    func loadModel() async {
        await startOrJoinModelLoad(for: settings.whisperModel)
    }

    /// Load a specific model variant (for re-transcription with a different model).
    func loadModel(_ name: String) async {
        settings.whisperModel = canonicalModelName(name)
        await reloadModel()
    }

    /// Reload with the current model from settings (e.g. after user changes model).
    func reloadModel() async {
        whisperKit = nil
        isModelLoaded = false
        loadedModelName = nil
        await startOrJoinModelLoad(for: settings.whisperModel, forceReload: true)
    }

    private func ensureSelectedModelLoaded() async throws {
        let modelName = canonicalModelName(settings.whisperModel)
        settings.whisperModel = modelName

        if isReadyToTranscribe(modelName: modelName) {
            return
        }

        logger.info("Ensuring selected Whisper model is ready before transcription: \(modelName, privacy: .public)")
        await startOrJoinModelLoad(for: modelName)

        guard isReadyToTranscribe(modelName: modelName) else {
            if case .failed(let message) = modelState {
                throw TranscriptionError.modelLoadFailed(message)
            }
            throw TranscriptionError.modelNotLoaded
        }
    }

    // MARK: - Transcription

    /// Transcribe audio from a file URL.
    func transcribe(audioFileURL: URL) async throws -> String {
        try await ensureSelectedModelLoaded()
        guard let whisperKit else { throw TranscriptionError.modelNotLoaded }

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
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please wait for model initialization."
        case .modelLoadFailed(let message):
            return "Whisper model could not be loaded: \(message)"
        }
    }
}
