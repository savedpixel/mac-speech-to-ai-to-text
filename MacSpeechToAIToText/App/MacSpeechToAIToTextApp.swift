import SwiftUI

@main
struct MacSpeechToAIToTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Mac Speech to AI to Text", id: "main") {
            MainWindowView(
                historyStore: appDelegate.historyStore,
                promptStore: appDelegate.promptStore,
                settings: appDelegate.settings,
                permissionManager: appDelegate.permissionManager,
                transcriptionCleaner: appDelegate.transcriptionCleaner,
                transcriptionEngine: appDelegate.transcriptionEngine,
                audioPlayer: appDelegate.audioPlayer,
                audioSignalPlayer: appDelegate.audioSignalPlayer
            )
            .groupBoxStyle(MacSpeechToAIToTextGroupBoxStyle())
        }
        .defaultSize(width: 1080, height: 720)
    }
}
