import Foundation

/// One row per test, across every generator, which is how a facilities engineer reconciles a
/// whole plant against a Joint Commission or AHJ request. Columns a tier does not use are blank
/// rather than omitted, so the header never changes shape.
enum CSVExporter {
    static let header = [
        "unit", "location", "make", "model", "serial", "nameplate_kw", "nameplate_v",
        "level", "class", "type", "ats_name",
        "date", "tier", "technician", "left_in_auto",
        "run_minutes", "load_kw", "load_percent", "target_minutes", "target_load_percent",
        "volts_l1", "volts_l2", "volts_l3", "amps_l1", "amps_l2", "amps_l3",
        "frequency_hz", "oil_pressure_psi", "coolant_temp_f", "battery_volts", "exhaust_temp_f",
        "load_bank_used", "fuel_quality",
        "transfer_seconds", "retransfer_seconds", "load_transferred", "returned_to_normal",
        "weekly_items_ok", "weekly_items_attention", "weekly_attention_list",
        "corrective_action", "notes", "signed",
    ].joined(separator: ",")

    /// Every test on every generator, most recent first within each generator.
    static func export(_ generators: [Generator]) throws -> URL {
        var rows = [header]
        for generator in generators.sorted(by: { $0.unitID < $1.unitID }) {
            for test in generator.sortedTests {
                rows.append(row(for: test, generator: generator).map(escape).joined(separator: ","))
            }
        }
        let text = rows.joined(separator: "\n") + "\n"
        let url = ExportFile.temporaryURL(extension: "csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func row(for test: GenTest, generator: Generator) -> [String] {
        let outcome = test.outcome(for: generator)
        let transfer = test.transfer(for: generator)
        return [
            generator.unitID, generator.location, generator.make, generator.model, generator.serialNumber,
            num(generator.nameplateKW), num(generator.nameplateVolts),
            generator.level.short, generator.systemClass.short, generator.systemType.short, generator.atsName,
            ISO8601DateFormatter.day.string(from: test.date), test.tier.name, test.technicianName,
            yesNo(test.leftInAuto),
            num(Double(test.runMinutes)), num(test.loadKW), outcome?.loadPercent.map { num($0) } ?? "",
            num(Double(outcome?.targetMinutes ?? 0)), num(outcome?.targetLoadPercent ?? 0),
            num(test.voltsL1), num(test.voltsL2), num(test.voltsL3),
            num(test.ampsL1), num(test.ampsL2), num(test.ampsL3),
            num(test.frequencyHz), num(test.oilPressurePSI), num(test.coolantTempF),
            num(test.batteryVolts), num(test.exhaustTempF),
            test.tier == .annual ? yesNo(test.loadBankUsed) : "",
            test.tier == .annual ? test.fuelQuality.name : "",
            num(transfer?.transferSeconds ?? 0), num(transfer?.retransferSeconds ?? 0),
            test.tier == .ats ? yesNo(test.loadTransferred) : "",
            test.tier == .ats ? yesNo(test.returnedToNormal) : "",
            test.tier == .weekly ? "\(test.items.filter { test.result($0) == .ok }.count)" : "",
            test.tier == .weekly ? "\(test.attentionItems.count)" : "",
            test.tier == .weekly ? test.attentionItems.map(\.name).joined(separator: "; ") : "",
            test.correctiveAction, test.notes,
            test.tier.requiresSignature ? yesNo(test.signature != nil) : "",
        ]
    }

    private static func num(_ value: Double) -> String {
        value == 0 ? "" : (value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value))
    }

    private static func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }

    private static func escape(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
