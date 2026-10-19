import SwiftUI
import SwiftData

/// The transfer switch test: how long it took to transfer, and to come back. A set that starts
/// but does not transfer has not done its job, so this is measured against the system's own Type
/// — a number the user entered from their design documents, not a rule this app enforces.
struct ATSTestView: View {
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
                        .accessibilityIdentifier("ats.technicianField")
                }

                Section {
                    LabeledContent("Transfer time (seconds)") {
                        TextField("0", value: $test.transferSeconds, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("ats.transferSeconds")
                    }
                    LabeledContent("Retransfer time (seconds)") {
                        TextField("0", value: $test.retransferSeconds, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Toggle("Load transferred", isOn: $test.loadTransferred)
                    Toggle("Returned to normal source", isOn: $test.returnedToNormal)
                    Toggle("Left in AUTO after this test", isOn: $test.leftInAuto)
                    if let transfer = test.transfer(for: generator) {
                        Text(transfer.summaryLong).font(.subheadline).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("\(generator.atsName.isEmpty ? "The transfer switch" : generator.atsName)")
                } footer: {
                    Text(generator.systemType.seconds != nil
                         ? "Measured against \(generator.systemType.short): \(Format.seconds(generator.systemType.seconds!)), from Generator Details."
                         : "\(generator.systemType.name) carries no seconds figure to compare against.")
                }

                if !test.loadTransferred || !test.returnedToNormal {
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
            .navigationTitle("Transfer Switch Test")
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
            .alert("Delete this test?", isPresented: $confirmingDelete) {
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
        if test.leftInAuto { generator.confirmBackInAuto() }
        else { generator.takeOutOfAuto(reason: "Left out of AUTO after the transfer switch test.") }
        if !test.technicianName.isEmpty { UserDefaults.standard.set(test.technicianName, forKey: "technician.name") }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Generator>())) ?? [])
        dismiss()
    }

    private func cancel() {
        if test.transferSeconds == 0, test.technicianName.isEmpty {
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
