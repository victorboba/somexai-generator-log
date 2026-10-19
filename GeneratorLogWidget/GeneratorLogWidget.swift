import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

/// Leads with whichever needs attention most: a generator out of AUTO first, since that is the
/// one that will not start when the power fails, then the worst clock.
struct GeneratorLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var tint: Color {
        entry.snapshot.notInAutoCount > 0 ? .red
            : entry.snapshot.needingAttentionCount > 0 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConfig.appName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if entry.snapshot.generatorCount == 0 {
                Text("No generators yet").font(.subheadline).foregroundStyle(.secondary)
            } else if entry.snapshot.notInAutoCount > 0 {
                Text("\(entry.snapshot.notInAutoCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(entry.snapshot.notInAutoCount == 1 ? "not in AUTO" : "sets not in AUTO")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(entry.snapshot.needingAttentionCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(entry.snapshot.needingAttentionCount == 1 ? "clock needs attention" : "clocks need attention")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if family != .systemSmall, let unit = entry.snapshot.worstUnitID, let headline = entry.snapshot.worstHeadline {
                Divider()
                Text(unit).font(.footnote.weight(.medium)).lineLimit(1)
                Text(headline).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct GeneratorLogWidget: Widget {
    let kind = "GeneratorLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            GeneratorLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("Which generator needs attention first: out of AUTO, then the worst clock.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GeneratorLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        GeneratorLogWidget()
    }
}
