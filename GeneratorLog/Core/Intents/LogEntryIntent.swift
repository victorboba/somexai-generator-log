import AppIntents
import Foundation

/// "Open <App>" from Siri, Spotlight or the Shortcuts app. The app has three different test
/// screens rather than one "new entry" form, so the shortcut opens straight to the fleet board —
/// the same screen a facilities engineer would tap the Home Screen icon for — rather than guessing
/// which tier to start.
struct LogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Generator Test Log"
    static var description = IntentDescription("Opens the app to the generator board.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct GeneratorLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogEntryIntent(),
            phrases: ["Open \(.applicationName)", "Check generators in \(.applicationName)"],
            shortTitle: "Open Board",
            systemImageName: "bolt.fill"
        )
    }
}
