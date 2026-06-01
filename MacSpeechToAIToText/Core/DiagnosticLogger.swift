import Foundation
import os

final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    private let lock = NSLock()
    private let dateFormatter: ISO8601DateFormatter
    private var enabled = false

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    static var diagnosticsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MacVoice", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    static var currentLogFileURL: URL {
        let day = DateFormatter.diagnosticDay.string(from: Date())
        return diagnosticsDirectory.appendingPathComponent("macvoice-diagnostics-\(day).log")
    }

    func configure(enabled: Bool) {
        lock.lock()
        self.enabled = enabled
        lock.unlock()
        write("diagnostics", "Diagnostic file logging \(enabled ? "enabled" : "disabled")")
    }

    func write(_ category: String, _ message: String) {
        lock.lock()
        let shouldWrite = enabled
        lock.unlock()
        guard shouldWrite else { return }

        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp) [\(category)] \(message)\n"
        let url = Self.currentLogFileURL

        lock.lock()
        defer { lock.unlock() }

        do {
            try FileManager.default.createDirectory(at: Self.diagnosticsDirectory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try Data().write(to: url)
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            os_log(.error, log: OSLog(subsystem: "com.macvoice.app", category: "diagnostics"), "Failed to write diagnostic log: %{public}s", error.localizedDescription)
        }
    }
}

private extension DateFormatter {
    static let diagnosticDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
