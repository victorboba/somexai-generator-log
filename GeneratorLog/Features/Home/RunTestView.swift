import SwiftUI
import SwiftData

/// The monthly load test and the annual test share this screen — same readings, same signature,
/// same arithmetic. What differs is the target duration and, for the annual, the load bank and
/// fuel quality check. The run time and the load percentage against nameplate are computed live,
/// against the target this generator's own owner configured — arithmetic, never a verdict.
struct RunTestView: View {
    @Bindable var test: GenTest
    @Bindable var generator: Generator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var usesClockTimes = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var confirmingDelete = false

    private var title: String { test.tier == .monthly ? "Monthly Load Test" : "Annual Test" }


    /// What the technician has actually typed, per field, so a half-entered "1." is not reformatted
    /// out from under them on the next keystroke.
    @State private var rawNumberText: [String: String] = [:]

    /// Text-backed rather than `TextField(value:format:)`, which does not commit until the field
    /// loses focus. This screen shows run time and load percentage *as the numbers land* — that live
    /// arithmetic is the thing the app is for — and with a formatted binding the model never sees a
    /// digit until the technician happens to tap somewhere else, so the figures sit blank while they
    /// type and the Save button misjudges whether a reading exists.
    private func liveDouble(_ key: String, _ value: Binding<Double>) -> Binding<String> {
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

    private func liveInt(_ key: String, _ value: Binding<Int>) -> Binding<String> {
        Binding(
            get: {
                if let typed = rawNumberText[key] { return typed }
                return value.wrappedValue == 0 ? "" : String(value.wrappedValue)
            },
            set: { typed in
                rawNumberText[key] = typed
                value.wrappedValue = Int(typed.trimmingCharacters(in: .whitespaces)) ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $test.date, displayedComponents: .date)
                    TextField("Technician", text: $test.technicianName)
                        .accessibilityIdentifier("run.technicianField")
                }

                Section {
                    Toggle("Recorded with start and stop times", isOn: $usesClockTimes)
                        .onChange(of: usesClockTimes) { _, on in
                            if on {
                                if test.runStart == nil { test.runStart = test.date }
                                if test.runEnd == nil { test.runEnd = test.runStart }
                            } else {
                                test.runStart = nil
                                test.runEnd = nil
                            }
                        }
                    if usesClockTimes {
                        DatePicker("Start", selection: Binding(
                            get: { test.runStart ?? test.date },
                            set: { test.runStart = $0 }))
                        DatePicker("Stop", selection: Binding(
                            get: { test.runEnd ?? test.runStart ?? test.date },
                            set: { test.runEnd = $0 }))
                    } else {
                        LabeledContent("Run time (minutes)") {
                            TextField("0", text: liveInt("runMinutes", $test.runMinutesEntered))
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("run.runMinutes")
                        }
                    }
                    LabeledContent("Load (kW)") {
                        TextField("0", text: liveDouble("loadKW", $test.loadKW))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("run.loadKW")
                    }
                    if let outcome = test.outcome(for: generator) {
                        Text(outcome.durationText).font(.subheadline)
                            .foregroundStyle(outcome.metDuration ? .green : .orange)
                        Text(outcome.loadText).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Toggle("Left in AUTO after this test", isOn: $test.leftInAuto)
                } header: {
                    Text("The run")
                } footer: {
                    Text(generator.nameplateKW > 0
                         ? "Measured against \(Format.duration(generator.requiredMinutes(test.tier))) and \(Format.percent(generator.requiredLoadPercent)) of the \(Format.number(generator.nameplateKW)) kW nameplate — the target set for this generator."
                         : "Set the nameplate kW in Generator Details to see load as a percentage.")
                }

                Section("Readings") {
                    numberField("Frequency (Hz)", $test.frequencyHz)
                    numberField("Oil pressure (psi)", $test.oilPressurePSI)
                    numberField("Coolant temperature (°F)", $test.coolantTempF)
                    numberField("Battery voltage (V)", $test.batteryVolts)
                    numberField("Exhaust temperature (°F)", $test.exhaustTempF)
                }

                Section("Three-phase (optional)") {
                    numberField("Volts L1", $test.voltsL1)
                    numberField("Volts L2", $test.voltsL2)
                    numberField("Volts L3", $test.voltsL3)
                    numberField("Amps L1", $test.ampsL1)
                    numberField("Amps L2", $test.ampsL2)
                    numberField("Amps L3", $test.ampsL3)
                }

                if test.tier == .annual {
                    Section("Fuel quality") {
                        Toggle("Load bank used", isOn: $test.loadBankUsed)
                        if generator.fuelType.isStored {
                            ChoiceChips(options: FuelQuality.allCases, selection: $test.fuelQuality) { $0.name }
                            TextField("Sample result or note", text: $test.fuelQualityNote, axis: .vertical)
                                .lineLimit(1...3)
                        }
                    }
                }

                Section("Signature") {
                    SignaturePad(data: $test.signature, name: test.technicianName)
                }

                Section("Photo") {
                    PhotoField(data: $test.photoData, label: "Photo of the gauges or load bank readout")
                }

                if !test.correctiveAction.isEmpty || (test.outcome(for: generator)?.metEverything == false) {
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
            .navigationTitle(title)
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
            .onAppear { usesClockTimes = test.runStart != nil }
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

    @ViewBuilder
    private func numberField(_ label: String, _ value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }

    private func save() {
        if test.leftInAuto {
            generator.confirmBackInAuto()
        } else {
            generator.takeOutOfAuto(reason: "Left in \(test.leftInAuto ? "AUTO" : "MANUAL or OFF") after the \(test.tier.name.lowercased()).")
        }
        if !test.technicianName.isEmpty { UserDefaults.standard.set(test.technicianName, forKey: "technician.name") }
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Generator>())) ?? [])
        dismiss()
    }

    /// A brand-new test nobody entered anything on is discarded rather than left as an empty stub.
    private func cancel() {
        if test.runMinutes == 0, test.loadKW == 0, test.technicianName.isEmpty {
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
