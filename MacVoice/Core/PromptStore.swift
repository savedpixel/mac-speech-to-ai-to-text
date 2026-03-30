import Foundation
import os

@Observable
final class PromptStore {
    private let logger = Logger(subsystem: "com.macvoice.app", category: "core")
    private let fileURL: URL
    private(set) var prompts: [CleanupPrompt] = []
    var selectedPromptID: UUID = CleanupPrompt.default.id

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("prompts.json")
        load()
    }

    var selectedPrompt: CleanupPrompt {
        prompts.first(where: { $0.id == selectedPromptID }) ?? CleanupPrompt.default
    }

    func add(_ prompt: CleanupPrompt) {
        prompts.append(prompt)
        save()
    }

    func update(_ prompt: CleanupPrompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        prompts[index] = prompt
        save()
    }

    func delete(id: UUID) {
        guard let prompt = prompts.first(where: { $0.id == id }), !prompt.isBuiltIn else { return }
        prompts.removeAll(where: { $0.id == id })
        if selectedPromptID == id {
            selectedPromptID = CleanupPrompt.default.id
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            prompts = [CleanupPrompt.default]
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            prompts = try JSONDecoder().decode([CleanupPrompt].self, from: data)
            if !prompts.contains(where: { $0.isBuiltIn }) {
                prompts.insert(CleanupPrompt.default, at: 0)
                save()
            }
        } catch {
            logger.error("Failed to load prompts: \(error.localizedDescription)")
            prompts = [CleanupPrompt.default]
            save()
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(prompts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save prompts: \(error.localizedDescription)")
        }
    }
}
