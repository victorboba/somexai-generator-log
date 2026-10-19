import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the widget summary from the current fleet and reloads timelines. Sorts the
    /// same way the board does, so the widget's "worst" line always matches the app's top row.
    static func update(with generators: [Generator]) {
        var snapshot = WidgetSnapshot()
        snapshot.generatorCount = generators.count
        snapshot.notInAutoCount = generators.filter { !$0.inAuto }.count
        snapshot.needingAttentionCount = generators.filter(\.anyClockNeedsAttention).count
        if let worst = generators.sorted(by: { $0.boardUrgency() > $1.boardUrgency() }).first {
            snapshot.worstUnitID = worst.unitID.isEmpty ? "Unnamed set" : worst.unitID
            snapshot.worstHeadline = worst.inAuto
                ? (worst.clocks().first?.state.headline ?? "No tests recorded")
                : "Controller not in AUTO"
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
