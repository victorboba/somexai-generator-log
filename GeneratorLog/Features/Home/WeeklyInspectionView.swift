import SwiftUI
import SwiftData

/// The weekly walk-round. The set does not have to run; NFPA 110 asks for the items on it and
/// the controller's state, nothing more. Saving syncs the generator's own AUTO state to whatever
/// the controller item actually said, because that is the one finding the whole board leads with.
struct WeeklyInspectionView: View {
    @Bindable var test: GenTest
    @Bindable var generator: Generator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $test.date, displayedComponents: .date)
                    TextField("Technician", text: $test.technicianName)
                        .accessibilityIdentifier("weekly.technicianField")
                    if !test.uncheckedItems.isEmpty {
                        Button("Mark Remaining Items OK") {
                            for item in test.uncheckedItems { test.set(.ok, for: item) }
                        }
                    }
                }
                ForEach(WeeklySection.allCases) { section in
                    let items = WeeklyItem.items(in: section, for: generator.fuelType)
                    if !items.isEmpty {
                        Section(section.name) {
                            ForEach(items) { item in WeeklyItemRow(test: test, item: item) }
                        }
                    }
                }
                if !test.attentionItems.isEmpty {
                    Section("Corrective action") {
                        TextField("What was done, or what is planned", text: $test.correctiveAction, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
                Section("Notes") {
                    TextField("Anything else worth recording", text: $test.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Weekly Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { export() } label: { Label("Export PDF", systemImage: "doc.richtext") }
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() }.bold() }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Delete this inspection?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive) { context.delete(test); try? context.save(); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
        .presentationDetents([.large])
    }

    private func save() {
        switch test.result(.controllerInAuto) {
        case .attention:
            let reason = test.note(.controllerInAuto)
            generator.takeOutOfAuto(reason: reason.isEmpty ? "Found not in AUTO during the weekly inspection." : reason)
        case .ok:
            generator.confirmBackInAuto()
        case .notChecked, .notApplicable:
            break
        }
        if !test.technicianName.isEmpty { UserDefaults.standard.set(test.technicianName, forKey: "technician.name") }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Generator>())) ?? [])
        dismiss()
    }

    /// A brand-new inspection nobody answered anything on is discarded rather than left as an
    /// empty stub in the history.
    private func cancel() {
        if test.uncheckedItems.count == test.items.count {
            context.delete(test)
            try? context.save()
        }
        dismiss()
    }

    private func export() {
        do { exportFile = ExportFile(url: try PDFExporter.export(test, generator: generator)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct WeeklyItemRow: View {
    @Bindable var test: GenTest
    let item: WeeklyItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name).font(.subheadline.weight(.medium))
            Text(item.hint).font(.caption).foregroundStyle(.secondary)
            ChoiceChips(
                options: [ItemState.ok, .attention, .notApplicable],
                selection: Binding(get: { test.result(item) }, set: { test.set($0, for: item) })
            ) { $0.name } tint: { $0 == .attention ? .orange : .accentColor }

            if test.result(item) == .attention {
                TextField("What's wrong", text: Binding(get: { test.note(item) }, set: { test.setNote($0, for: item) }))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
