import SwiftUI
import SwiftData

/// One generator: its AUTO state, its four clocks, its history, and its exports.
struct GeneratorView: View {
    @Bindable var generator: Generator
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var openTest: GenTest?
    @State private var editing = false
    @State private var confirmingBackToAuto = false
    @State private var reportingOutOfAuto = false
    @State private var outOfAutoReason = ""
    @State private var exportFile: ExportFile?
    @State private var exportError: String?


    var body: some View {
        List {
            Section {
                if generator.inAuto {
                    HStack {
                        Label("Controller in AUTO", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(.green)
                        Spacer()
                        Button("Report out of AUTO") { outOfAutoReason = ""; reportingOutOfAuto = true }
                            .font(.caption)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("NOT IN AUTO", systemImage: "exclamationmark.octagon.fill")
                            .font(.headline).foregroundStyle(.red)
                        if !generator.notInAutoReason.isEmpty { Text(generator.notInAutoReason).font(.subheadline) }
                        if let since = generator.notInAutoSince {
                            Text("Since \(since.formatted(date: .long, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Confirm back in AUTO") { confirmingBackToAuto = true }
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("A set left in OFF or MANUAL after a test will not start when the power fails. Only confirm AUTO once someone has actually set the selector back.")
            }

            Section("Start a test") {
                ForEach(TestTier.scheduled) { tier in
                    Button { start(tier) } label: {
                        HStack {
                            Label(tier.name, systemImage: tier.symbol)
                            Spacer()
                            let clock = generator.clock(tier)
                            Text(clock.state.headline)
                                .font(.caption)
                                .foregroundStyle(clock.state.needsAttention ? .orange : .secondary)
                        }
                    }
                }
                Button { start(.ats) } label: {
                    HStack {
                        Label(TestTier.ats.name, systemImage: TestTier.ats.symbol)
                        Spacer()
                        let clock = generator.clock(.ats)
                        Text(clock.state.headline)
                            .font(.caption)
                            .foregroundStyle(clock.state.needsAttention ? .orange : .secondary)
                    }
                }
            }

            Section {
                ForEach(TestTier.allCases) { tier in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name).font(.subheadline.weight(.medium))
                        Text(tier.whatItIs).font(.caption).foregroundStyle(.secondary)
                        if tier == .monthly {
                            Text("Your target: \(Format.duration(generator.requiredMonthlyMinutes)) at \(Format.percent(generator.requiredLoadPercent)) of \(Format.number(generator.nameplateKW)) kW")
                                .font(.caption2).foregroundStyle(.secondary)
                        } else if tier == .annual {
                            Text("Your target: \(Format.duration(generator.requiredAnnualMinutes))")
                                .font(.caption2).foregroundStyle(.secondary)
                        } else if tier == .ats, let seconds = generator.systemType.seconds {
                            Text("\(generator.systemType.short): \(Format.seconds(seconds))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("What NFPA 110 Chapter 8 asks for")
            } footer: {
                Text("The cadence is the standard's. The exact duration and load percentage depend on the edition your jurisdiction has adopted and this system's Level and Class, so the targets above are yours to set in Generator Details.")
            }

            Section("History") {
                if generator.sortedTests.isEmpty {
                    Text("Nothing recorded yet.").foregroundStyle(.secondary)
                }
                ForEach(generator.sortedTests) { test in
                    Button { openTest = test } label: { HistoryRow(test: test, generator: generator) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: deleteTests)
            }

            Section {
                Button { exportHistory() } label: {
                    Label("Generator History (PDF)", systemImage: "doc.richtext")
                }
            }
        }
        .navigationTitle(generator.unitID.isEmpty ? "Generator" : generator.unitID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { Label("Generator details", systemImage: "info.circle") }
            }
        }
        .sheet(item: $openTest) { test in
            switch test.tier {
            case .weekly: WeeklyInspectionView(test: test, generator: generator)
            case .monthly, .annual: RunTestView(test: test, generator: generator)
            case .ats: ATSTestView(test: test, generator: generator)
            }
        }
        .sheet(isPresented: $editing) { GeneratorEditorView(generator: generator) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Confirm back in AUTO", isPresented: $confirmingBackToAuto) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                generator.confirmBackInAuto()
                try? context.save()
                WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Generator>())) ?? [])
            }
        } message: {
            Text("Confirm someone has actually set the selector back to AUTO.")
        }
        .alert("Report controller out of AUTO", isPresented: $reportingOutOfAuto) {
            TextField("Reason", text: $outOfAutoReason)
            Button("Cancel", role: .cancel) {}
            Button("Report") {
                generator.takeOutOfAuto(reason: outOfAutoReason.isEmpty ? "Reported out of AUTO." : outOfAutoReason)
                try? context.save()
                WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Generator>())) ?? [])
            }
        } message: {
            Text("What happened, so the next person who looks knows why.")
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private func start(_ tier: TestTier) {
        let test = GenTest(tier: tier)
        test.technicianName = UserDefaults.standard.string(forKey: "technician.name") ?? ""
        test.generator = generator
        context.insert(test)
        try? context.save()
        openTest = test
    }

    private func deleteTests(_ offsets: IndexSet) {
        let list = generator.sortedTests
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }

    private func exportHistory() {
        try? context.save()
        do {
            exportFile = ExportFile(url: try PDFExporter.exportHistory(generator))
            ReviewPrompter.recordSuccess(request: requestReview)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct HistoryRow: View {
    let test: GenTest
    let generator: Generator

    private var tint: Color {
        if !test.leftInAuto { return .red }
        if !test.attentionItems.isEmpty { return .orange }
        return .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: test.tier.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(test.tier.name) · \(test.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.medium))
                Text(test.headline(for: generator)).font(.caption).foregroundStyle(tint)
                if !test.technicianName.isEmpty {
                    Text(test.technicianName).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if test.tier.requiresSignature && test.signature == nil {
                Label("unsigned", systemImage: "signature")
                    .font(.caption2).foregroundStyle(.orange).labelStyle(.titleOnly)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The generator's identity: what makes an exported record admissible, and the targets the app
/// measures every run against.
struct GeneratorEditorView: View {
    @Bindable var generator: Generator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// What the engineer has actually typed, per field, so a half-entered "12." survives the next
    /// keystroke instead of being reformatted away.
    @State private var rawNumberText: [String: String] = [:]

    /// Text-backed rather than `TextField(value:format:)`, which does not commit to the model until
    /// the field loses focus. The nameplate is what every load percentage on this generator is
    /// measured against, so an uncommitted nameplate silently turns the app's central number into
    /// "Enter the nameplate kW to see load as a percentage" while the engineer is looking straight
    /// at the figure they just typed.
    private func liveNumber(_ key: String, _ value: Binding<Double>) -> Binding<String> {
        Binding(
            get: {
                if let typed = rawNumberText[key] { return typed }
                return value.wrappedValue == 0 ? "" : value.wrappedValue.formatted(.number.precision(.fractionLength(0...2)))
            },
            set: { typed in
                rawNumberText[key] = typed
                let cleaned = typed.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                value.wrappedValue = Double(cleaned) ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Generator") {
                    TextField("Unit ID", text: $generator.unitID)
                        .accessibilityIdentifier("unitIDField")
                    TextField("Location", text: $generator.location)
                    TextField("Make", text: $generator.make)
                    TextField("Model", text: $generator.model)
                    TextField("Serial number", text: $generator.serialNumber)
                }

                Section {
                    LabeledContent("Nameplate kW") {
                        TextField("—", text: liveNumber("nameplateKW", $generator.nameplateKW))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("nameplateKWField")
                    }
                    LabeledContent("Nameplate volts") {
                        TextField("—", text: liveNumber("nameplateVolts", $generator.nameplateVolts))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fuel type").font(.subheadline)
                        ChoiceChips(options: FuelType.allCases, selection: $generator.fuelType) { $0.name }
                    }
                } header: {
                    Text("Nameplate")
                } footer: {
                    Text("Nameplate kW is what a load reading during a run is turned into a percentage against.")
                }

                Section("Photo") {
                    PhotoField(data: $generator.photoData, label: "Photo of the nameplate")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Level").font(.subheadline)
                        ChoiceChips(options: SystemLevel.allCases, selection: $generator.level) { $0.short }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Class").font(.subheadline)
                        ChoiceChips(options: SystemClass.allCases, selection: $generator.systemClass) { $0.short }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type").font(.subheadline)
                        ChoiceChips(options: SystemType.allCases, selection: $generator.systemType) { $0.short }
                    }
                } header: {
                    Text("NFPA 110 classification")
                } footer: {
                    Text("From your design documents or the AHJ, not decided by this app. Type sets the seconds a transfer is measured against.")
                }

                Section("Automatic transfer switch") {
                    TextField("ATS name", text: $generator.atsName)
                    TextField("ATS location", text: $generator.atsLocation)
                    Stepper("Test every \(generator.atsIntervalMonths) month\(generator.atsIntervalMonths == 1 ? "" : "s")",
                            value: $generator.atsIntervalMonths, in: 1...24)
                }

                Section {
                    Stepper("Monthly run at least \(Format.duration(generator.requiredMonthlyMinutes))",
                            value: $generator.requiredMonthlyMinutes, in: 0...600, step: 5)
                    Stepper("Load at least \(Format.percent(generator.requiredLoadPercent)) of nameplate",
                            value: $generator.requiredLoadPercent, in: 0...100, step: 5)
                    Stepper("Annual run at least \(Format.duration(generator.requiredAnnualMinutes))",
                            value: $generator.requiredAnnualMinutes, in: 0...1440, step: 15)
                } header: {
                    Text("Your targets")
                } footer: {
                    Text("Defaults are the commonly cited 30 minutes at 30% of nameplate and a 4-hour annual run. Confirm the figures your jurisdiction's adopted edition and this system's Level and Class actually call for, and set your own here.")
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $generator.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Delete this generator", role: .destructive) {
                        context.delete(generator)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Generator Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
