import SwiftUI
import SwiftData

/// The fleet board: every generator, worst first. A set out of AUTO always leads, because it is
/// the one that will not start when the power fails — ahead of any overdue clock, which is only a
/// late record.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var generators: [Generator]

    @State private var openGenerator: Generator?
    @State private var editingGenerator: Generator?
    @State private var showingSettings = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var sorted: [Generator] {
        generators.sorted { $0.boardUrgency() > $1.boardUrgency() }
    }

    var body: some View {
        NavigationStack {
            Group {
                if generators.isEmpty {
                    ContentUnavailableView {
                        Label("No generators yet", systemImage: "bolt.square")
                    } description: {
                        Text("Add a generator and the app starts its clocks: weekly inspection, monthly load test, annual test and the transfer switch test.")
                    } actions: {
                        Button("Add a Generator") { addGenerator() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(sorted) { generator in
                            Button { openGenerator = generator } label: { GeneratorRow(generator: generator) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Generators")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How do I use this app")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addGenerator() } label: { Label("Add a Generator", systemImage: "plus") }
                        if !generators.isEmpty {
                            Button { exportCSV() } label: {
                                Label("Every test as CSV", systemImage: "tablecells")
                            }
                        }
                        Divider()
                        Button { showingSettings = true } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(item: $openGenerator) { GeneratorView(generator: $0) }
            .sheet(item: $editingGenerator) { GeneratorEditorView(generator: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), generators.isEmpty { SampleData.insert(into: context) }
            #endif
        }
        .onChange(of: generators.count, initial: true) { WidgetSync.update(with: generators) }
    }

    private func addGenerator() {
        let generator = Generator()
        context.insert(generator)
        try? context.save()
        editingGenerator = generator
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(sorted[index]) }
        try? context.save()
        WidgetSync.update(with: generators)
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.export(generators)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct GeneratorRow: View {
    let generator: Generator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(generator.title).font(.headline)
                Spacer()
                if !generator.inAuto {
                    Label("NOT IN AUTO", systemImage: "exclamationmark.octagon.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                        .labelStyle(.titleOnly)
                }
            }
            if !generator.location.isEmpty {
                Text(generator.location).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(generator.classification).font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(generator.clocks(tiers: TestTier.scheduled)) { clock in
                    ClockChip(clock: clock)
                }
                ATSChip(clock: generator.clock(.ats))
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("generatorRow-\(generator.unitID)")
    }
}

private struct ClockChip: View {
    let clock: Clock

    private var tint: Color {
        switch clock.state {
        case .overdue, .neverTested: .red
        case .dueToday: .orange
        case .dueIn(let d): d <= 3 ? .orange : .green
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: clock.tier.symbol).font(.caption)
            Text(clock.tier.shortName).font(.caption2.weight(.medium))
            Text(clock.state.badge).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(tint)
    }
}

/// The ATS line sits apart from the three scheduled clocks — it runs on its own interval and is
/// what proves the set actually does its job, not just that it starts.
private struct ATSChip: View {
    let clock: Clock

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.left.arrow.right").font(.caption)
            Text("ATS").font(.caption2.weight(.medium))
            Text(clock.state.badge).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.secondary)
    }
}
