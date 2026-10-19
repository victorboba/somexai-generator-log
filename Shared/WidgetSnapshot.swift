import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render without
/// touching SwiftData. The app updates it whenever a generator or a test changes.
struct WidgetSnapshot: Codable {
    var generatorCount: Int = 0
    /// Controllers currently left in something other than AUTO. The one number that matters most.
    var notInAutoCount: Int = 0
    /// Generators with at least one overdue or never-tested clock.
    var needingAttentionCount: Int = 0
    var worstHeadline: String?
    var worstUnitID: String?
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(generatorCount: 4, notInAutoCount: 1, needingAttentionCount: 2,
                                            worstHeadline: "Overdue by 6 days", worstUnitID: "EG-2")
}
