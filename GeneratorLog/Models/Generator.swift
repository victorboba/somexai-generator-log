import Foundation
import SwiftData

/// One emergency power supply (EPS), and the four clocks NFPA 110 Chapter 8 runs on it at once.
///
/// NFPA 110, *Standard for Emergency and Standby Power Systems*, Chapter 8 (Routine Maintenance
/// and Operational Testing) is the reason this app exists. Its cadence is the app's structure:
///
/// - **Weekly** — an inspection of the EPS. The set does not have to run. Fuel, oil and coolant
///   levels, battery and charger, block heater, louvres and ventilation, no leaks, and that the
///   controller is in AUTO.
/// - **Monthly** — an operational test under load, run long enough and loaded heavily enough to
///   meet the criteria the system's Level and Class carry, with the electrical and engine
///   readings written down.
/// - **Annual** — a longer continuous run, commonly on a load bank where the building load is
///   not enough on its own, plus the fuel quality check.
/// - **ATS** — the automatic transfer switch is exercised, transfer and retransfer, with the
///   time to transfer recorded. A set that starts but does not transfer has not done its job.
///
/// **Why the targets are the user's own.** The chapter and the cadence are stable, but the exact
/// numbers — what load percentage counts, how many hours the annual run is — depend on the
/// edition of NFPA 110 the jurisdiction has adopted and on the system's own Level and Class. The
/// app therefore never ships a threshold as if it were the rule. Each generator carries the
/// duration and load threshold **its owner** configured, defaulting to the commonly cited 30
/// minutes at 30% of nameplate kW and a 4-hour annual run, and every record says what was
/// achieved against that configured target. The app reports arithmetic. It does not declare a
/// generator compliant and it does not print a clause number.
@Model
final class Generator {
    var id: UUID = UUID()
    var unitID: String = ""
    var location: String = ""
    var make: String = ""
    var model: String = ""
    var serialNumber: String = ""

    // Nameplate. The kW is what a load reading is turned into a percentage against, so it is the
    // one number the app genuinely needs.
    var nameplateKW: Double = 0
    var nameplateVolts: Double = 0
    var fuelTypeRaw: String = FuelType.diesel.rawValue

    // NFPA 110 classification. Level, Class and Type are assigned by the design documents or the
    // AHJ, not by this app; it records what the user was given and uses Type as the yardstick for
    // the transfer timing.
    var levelRaw: String = SystemLevel.level1.rawValue
    var classRaw: String = SystemClass.class6.rawValue
    var typeRaw: String = SystemType.type10.rawValue

    // The transfer switch this set feeds.
    var atsName: String = ""
    var atsLocation: String = ""
    var atsIntervalMonths: Int = 1

    // The user's own targets. Defaults are sensible, not authoritative.
    var requiredMonthlyMinutes: Int = 30
    var requiredLoadPercent: Double = 30
    var requiredAnnualMinutes: Int = 240

    /// The one state that makes every other record meaningless if it is wrong. A set left in OFF
    /// or MANUAL after a test will not start when the power fails, and it is a classic finding.
    var inAuto: Bool = true
    var notInAutoSince: Date? = nil
    var notInAutoReason: String = ""

    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \GenTest.generator)
    var tests: [GenTest]? = nil

    var createdAt: Date = Date()

    init(unitID: String = "", location: String = "", nameplateKW: Double = 0) {
        self.id = UUID()
        self.unitID = unitID
        self.location = location
        self.nameplateKW = nameplateKW
        self.createdAt = .now
    }

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .diesel }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var level: SystemLevel {
        get { SystemLevel(rawValue: levelRaw) ?? .level1 }
        set { levelRaw = newValue.rawValue }
    }

    var systemClass: SystemClass {
        get { SystemClass(rawValue: classRaw) ?? .class6 }
        set { classRaw = newValue.rawValue }
    }

    var systemType: SystemType {
        get { SystemType(rawValue: typeRaw) ?? .type10 }
        set { typeRaw = newValue.rawValue }
    }

    /// "EG-1 — Cummins C750D6" — the way a unit is named on a one-line diagram.
    var title: String {
        let unit = unitID.isEmpty ? "Unnamed set" : unitID
        let machine = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return machine.isEmpty ? unit : "\(unit) — \(machine)"
    }

    /// "Level 1 · Class 6 · Type 10" — the classification strip that says this is an NFPA 110
    /// record and not a generic equipment log.
    var classification: String {
        "\(level.short) · \(systemClass.short) · \(systemType.short)"
    }

    var nameplateSummary: String {
        var parts: [String] = []
        if nameplateKW > 0 { parts.append("\(Format.number(nameplateKW)) kW") }
        if nameplateVolts > 0 { parts.append("\(Format.number(nameplateVolts)) V") }
        parts.append(fuelType.name)
        return parts.joined(separator: " · ")
    }

    var sortedTests: [GenTest] { (tests ?? []).sorted { $0.date > $1.date } }

    func tests(_ tier: TestTier) -> [GenTest] { sortedTests.filter { $0.tier == tier } }

    func latest(_ tier: TestTier) -> GenTest? { sortedTests.first { $0.tier == tier } }

    /// How long this generator's owner has between one test of a tier and the next.
    func intervalDays(_ tier: TestTier) -> Int {
        switch tier {
        case .weekly: return 7
        case .monthly: return 30
        case .annual: return 365
        case .ats: return max(1, atsIntervalMonths) * 30
        }
    }

    func requiredMinutes(_ tier: TestTier) -> Int {
        switch tier {
        case .monthly: return max(0, requiredMonthlyMinutes)
        case .annual: return max(0, requiredAnnualMinutes)
        case .weekly, .ats: return 0
        }
    }

    func nextDue(_ tier: TestTier) -> Date? {
        guard let last = latest(tier) else { return nil }
        return Calendar.current.date(byAdding: .day, value: intervalDays(tier),
                                     to: Calendar.current.startOfDay(for: last.date))
    }

    func clock(_ tier: TestTier, asOf today: Date = .now) -> Clock {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        guard let last = latest(tier) else {
            return Clock(tier: tier, last: nil, due: nil, state: .neverTested, fractionElapsed: 1)
        }
        let due = nextDue(tier) ?? start
        let remaining = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: due)).day ?? 0
        let elapsed = cal.dateComponents([.day], from: cal.startOfDay(for: last.date), to: start).day ?? 0
        let fraction = Double(elapsed) / Double(max(1, intervalDays(tier)))
        let state: ClockState
        if remaining < 0 { state = .overdue(days: -remaining) }
        else if remaining == 0 { state = .dueToday }
        else { state = .dueIn(days: remaining) }
        return Clock(tier: tier, last: last.date, due: due, state: state, fractionElapsed: fraction)
    }

    /// Worst first, which is the order somebody walking a plant room wants them.
    func clocks(asOf today: Date = .now, tiers: [TestTier] = TestTier.allCases) -> [Clock] {
        tiers.map { clock($0, asOf: today) }
            .sorted { ($0.state.urgency, $0.fractionElapsed) > ($1.state.urgency, $1.fractionElapsed) }
    }

    /// The single number the board sorts on: a generator out of AUTO outranks any overdue clock,
    /// because an overdue test is a late record and a set out of AUTO is a set that will not start.
    func boardUrgency(asOf today: Date = .now) -> Int {
        (inAuto ? 0 : 1000) + (clocks(asOf: today).first?.state.urgency ?? 0)
    }

    var anyClockNeedsAttention: Bool { clocks().contains { $0.state.needsAttention } }

    /// Put the set back in AUTO, recording that a person said so and when.
    func confirmBackInAuto() {
        inAuto = true
        notInAutoSince = nil
        notInAutoReason = ""
    }

    func takeOutOfAuto(reason: String, on date: Date = .now) {
        guard inAuto else { return }
        inAuto = false
        notInAutoSince = date
        notInAutoReason = reason
    }

    /// The twelve-month picture a surveyor asks for: how many monthly tests are on file inside
    /// the last year, and how many of them reached the targets this generator is configured with.
    func annualSummary(asOf today: Date = .now) -> AnnualSummary {
        let cal = Calendar.current
        let from = cal.date(byAdding: .month, value: -12, to: today) ?? today
        let window = sortedTests.filter { $0.date >= from && $0.date <= today }
        let monthly = window.filter { $0.tier == .monthly }
        let met = monthly.filter { $0.outcome(for: self)?.metEverything == true }.count
        return AnnualSummary(
            from: from, to: today,
            weeklyCount: window.filter { $0.tier == .weekly }.count,
            monthlyCount: monthly.count,
            monthlyMeetingTarget: met,
            annualCount: window.filter { $0.tier == .annual }.count,
            atsCount: window.filter { $0.tier == .ats }.count)
    }
}

/// One test, at one tier, of one generator.
///
/// The tiers share a record because a facility engineer thinks of them as one file per set. The
/// fields a tier does not use simply stay at zero, and `isRecordComplete` asks only for what that
/// tier needs.
@Model
final class GenTest {
    var id: UUID = UUID()
    var date: Date = Date()
    var tierRaw: String = TestTier.weekly.rawValue
    var technicianName: String = ""

    /// Weekly walk-round results, keyed by item so adding an item later cannot rewrite history.
    var resultsRaw: [String: String] = [:]
    var itemNotes: [String: String] = [:]

    // The run. Start and stop are what a technician actually has; the minutes follow from them.
    var runStart: Date? = nil
    var runEnd: Date? = nil
    /// Used when the technician has the elapsed minutes off the controller rather than two clock
    /// times. Ignored whenever both a start and an end are present.
    var runMinutesEntered: Int = 0

    // Readings taken with the set on load.
    var loadKW: Double = 0
    var voltsL1: Double = 0
    var voltsL2: Double = 0
    var voltsL3: Double = 0
    var ampsL1: Double = 0
    var ampsL2: Double = 0
    var ampsL3: Double = 0
    var frequencyHz: Double = 0
    var oilPressurePSI: Double = 0
    var coolantTempF: Double = 0
    var batteryVolts: Double = 0
    var exhaustTempF: Double = 0

    // Annual only.
    var loadBankUsed: Bool = false
    var fuelQualityRaw: String = FuelQuality.notTested.rawValue
    var fuelQualityNote: String = ""

    // ATS only.
    var transferSeconds: Double = 0
    var retransferSeconds: Double = 0
    var loadTransferred: Bool = true
    var returnedToNormal: Bool = true

    /// Answered on the weekly walk-round and on every run: the controller was left in AUTO.
    var leftInAuto: Bool = true

    var correctiveAction: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var signature: Data? = nil
    @Attribute(.externalStorage) var photoData: Data? = nil

    var generator: Generator? = nil

    init(date: Date = .now, tier: TestTier = .weekly) {
        self.id = UUID()
        self.date = date
        self.tierRaw = tier.rawValue
    }

    var tier: TestTier {
        get { TestTier(rawValue: tierRaw) ?? .weekly }
        set { tierRaw = newValue.rawValue }
    }

    var fuelQuality: FuelQuality {
        get { FuelQuality(rawValue: fuelQualityRaw) ?? .notTested }
        set { fuelQualityRaw = newValue.rawValue }
    }

    // MARK: Weekly items

    /// A set fed from a gas main is never asked for a tank level, and never short a record for it.
    var items: [WeeklyItem] {
        tier == .weekly ? WeeklyItem.items(for: generator?.fuelType ?? .diesel) : []
    }

    func result(_ item: WeeklyItem) -> ItemState {
        ItemState(rawValue: resultsRaw[item.rawValue] ?? "") ?? .notChecked
    }

    func set(_ state: ItemState, for item: WeeklyItem) {
        resultsRaw[item.rawValue] = state.rawValue
        if item == .controllerInAuto { leftInAuto = state != .attention }
    }

    func note(_ item: WeeklyItem) -> String { itemNotes[item.rawValue] ?? "" }

    func setNote(_ text: String, for item: WeeklyItem) {
        if text.isEmpty { itemNotes.removeValue(forKey: item.rawValue) }
        else { itemNotes[item.rawValue] = text }
    }

    var attentionItems: [WeeklyItem] { items.filter { result($0) == .attention } }
    var uncheckedItems: [WeeklyItem] { items.filter { result($0) == .notChecked } }

    // MARK: The run

    /// Minutes the set actually ran. Two clock times win over a typed figure; an end before its
    /// start is treated as nothing recorded rather than as a negative run.
    var runMinutes: Int {
        if let start = runStart, let end = runEnd {
            let seconds = end.timeIntervalSince(start)
            return seconds <= 0 ? 0 : Int((seconds / 60).rounded())
        }
        return max(0, runMinutesEntered)
    }

    /// What the run achieved against the targets this generator's owner configured. Arithmetic on
    /// their own numbers — never a compliance decision.
    func outcome(for generator: Generator?) -> RunOutcome? {
        guard tier.isRun else { return nil }
        let targetMinutes = generator?.requiredMinutes(tier) ?? 0
        let targetLoad = generator?.requiredLoadPercent ?? 0
        let nameplate = generator?.nameplateKW ?? 0
        let percent: Double? = (nameplate > 0 && loadKW > 0) ? (loadKW / nameplate * 100) : nil
        return RunOutcome(minutes: runMinutes, targetMinutes: targetMinutes,
                          loadKW: loadKW, nameplateKW: nameplate,
                          loadPercent: percent, targetLoadPercent: targetLoad)
    }

    /// What the transfer test measured against the Type the system is classified as.
    func transfer(for generator: Generator?) -> TransferOutcome? {
        guard tier == .ats else { return nil }
        return TransferOutcome(transferSeconds: transferSeconds,
                               retransferSeconds: retransferSeconds,
                               loadTransferred: loadTransferred,
                               returnedToNormal: returnedToNormal,
                               type: generator?.systemType ?? .type10)
    }

    // MARK: Completeness

    /// A record that is missing what its tier needs is not a record. The app says which piece.
    var missingPieces: [String] {
        var missing: [String] = []
        switch tier {
        case .weekly:
            if !uncheckedItems.isEmpty { missing.append("\(uncheckedItems.count) items not answered") }
        case .monthly, .annual:
            if runMinutes == 0 { missing.append("no run time") }
            if loadKW == 0 { missing.append("no load reading") }
            if technicianName.isEmpty { missing.append("no technician named") }
            if signature == nil { missing.append("not signed") }
        case .ats:
            if transferSeconds == 0 { missing.append("no transfer time") }
        }
        return missing
    }

    var isRecordComplete: Bool { missingPieces.isEmpty }

    /// The short line the history row and the packet both use.
    func headline(for generator: Generator?) -> String {
        switch tier {
        case .weekly:
            if !uncheckedItems.isEmpty { return "Not finished" }
            if !attentionItems.isEmpty {
                return "\(attentionItems.count) item\(attentionItems.count == 1 ? "" : "s") needing attention"
            }
            return "Walk-round complete, nothing flagged"
        case .monthly, .annual:
            return outcome(for: generator)?.summaryShort ?? "No run recorded"
        case .ats:
            return transfer(for: generator)?.summaryShort ?? "No transfer recorded"
        }
    }

    var day: Date { Calendar.current.startOfDay(for: date) }
}

// MARK: - The arithmetic, kept out of the views so it can be tested

/// What a run achieved against the targets the user configured for that generator.
/// Every property here is arithmetic on numbers the user entered. Nothing in it is a verdict.
struct RunOutcome: Equatable {
    var minutes: Int
    var targetMinutes: Int
    var loadKW: Double
    var nameplateKW: Double
    /// Nil when the nameplate kW or the load reading is missing, which is not the same as zero.
    var loadPercent: Double?
    var targetLoadPercent: Double

    var metDuration: Bool { targetMinutes > 0 && minutes >= targetMinutes }
    var shortfallMinutes: Int { max(0, targetMinutes - minutes) }

    /// Nil when there is nothing to compare, so the UI can say "not enough entered" rather than
    /// implying the run fell short.
    var metLoad: Bool? {
        guard let loadPercent else { return nil }
        return loadPercent >= targetLoadPercent
    }

    var metEverything: Bool { metDuration && metLoad == true }

    var durationText: String {
        minutes == 0 ? "No run time recorded" : "\(Format.duration(minutes)) of the \(Format.duration(targetMinutes)) target"
    }

    var loadText: String {
        guard let loadPercent else {
            return nameplateKW <= 0
                ? "Enter the nameplate kW to see load as a percentage"
                : "No load reading entered"
        }
        return "\(Format.number(loadKW)) kW is \(Format.percent(loadPercent)) of the "
             + "\(Format.number(nameplateKW)) kW nameplate, against a \(Format.percent(targetLoadPercent)) target"
    }

    var summaryShort: String {
        guard minutes > 0 else { return "No run recorded" }
        var text = Format.duration(minutes)
        if let loadPercent { text += " at \(Format.percent(loadPercent))" }
        if !metDuration { text += " · \(Format.duration(shortfallMinutes)) short of target" }
        else if metLoad == false { text += " · below the load target" }
        return text
    }

    /// The sentence that goes on the PDF. Deliberately reports, never rules.
    var summaryLong: String {
        guard minutes > 0 else { return "No run time was recorded for this test." }
        var text = "Ran \(Format.duration(minutes)) against a target of \(Format.duration(targetMinutes)) set for this generator."
        if !metDuration { text += " That is \(Format.duration(shortfallMinutes)) short of the target." }
        if let loadPercent {
            text += " Average load \(Format.number(loadKW)) kW is \(Format.percent(loadPercent)) of the "
                 + "\(Format.number(nameplateKW)) kW nameplate, against a \(Format.percent(targetLoadPercent)) target."
        }
        return text
    }
}

/// What the transfer test measured, against the Type the system is classified as. The Type is a
/// number the user entered from their own design documents, so comparing to it is arithmetic.
struct TransferOutcome: Equatable {
    var transferSeconds: Double
    var retransferSeconds: Double
    var loadTransferred: Bool
    var returnedToNormal: Bool
    var type: SystemType

    /// Nil for Type U and Type M, which carry no number to compare against.
    var withinTypeWindow: Bool? {
        guard let limit = type.seconds, transferSeconds > 0 else { return nil }
        return transferSeconds <= limit
    }

    var summaryShort: String {
        guard transferSeconds > 0 else { return "No transfer recorded" }
        var text = "Transferred in \(Format.seconds(transferSeconds))"
        if let limit = type.seconds {
            text += " against \(Format.seconds(limit)) for \(type.short)"
        }
        if !loadTransferred { text += " · load did not transfer" }
        return text
    }

    var summaryLong: String {
        guard transferSeconds > 0 else { return "No transfer time was recorded for this test." }
        var text = "The switch transferred the load in \(Format.seconds(transferSeconds))"
        if retransferSeconds > 0 { text += " and retransferred in \(Format.seconds(retransferSeconds))" }
        text += "."
        if let limit = type.seconds {
            text += " This system is recorded as \(type.short), which is \(Format.seconds(limit))."
        } else {
            text += " \(type.name) carries no transfer-time figure to compare against."
        }
        if !loadTransferred { text += " The load did not transfer." }
        if !returnedToNormal { text += " The switch did not return to the normal source." }
        return text
    }
}

struct AnnualSummary: Equatable {
    var from: Date
    var to: Date
    var weeklyCount: Int
    var monthlyCount: Int
    var monthlyMeetingTarget: Int
    var annualCount: Int
    var atsCount: Int
}

// MARK: - Clocks

struct Clock: Equatable, Identifiable {
    var tier: TestTier
    var last: Date?
    var due: Date?
    var state: ClockState
    /// Elapsed share of the interval. Drives the bar on the board; can exceed 1 when overdue.
    var fractionElapsed: Double

    var id: String { tier.rawValue }
    var barFraction: Double { min(1, max(0.02, fractionElapsed)) }
}

enum ClockState: Equatable {
    case neverTested
    case dueToday
    case dueIn(days: Int)
    case overdue(days: Int)

    var headline: String {
        switch self {
        case .neverTested: return "Never recorded"
        case .dueToday: return "Due today"
        case .dueIn(let d): return d == 1 ? "Due tomorrow" : "Due in \(Format.days(d))"
        case .overdue(let d): return "Overdue by \(Format.days(d))"
        }
    }

    /// Two or three characters for the bar label, where the full sentence will not fit.
    var badge: String {
        switch self {
        case .neverTested: return "—"
        case .dueToday: return "today"
        case .dueIn(let d): return d >= 60 ? "\(d / 30) mo" : "\(d) d"
        case .overdue(let d): return d >= 60 ? "−\(d / 30) mo" : "−\(d) d"
        }
    }

    var urgency: Int {
        switch self {
        case .overdue: return 4
        case .neverTested: return 3
        case .dueToday: return 2
        case .dueIn(let d): return d <= 3 ? 1 : 0
        }
    }

    var needsAttention: Bool { urgency >= 2 }
    var isOverdue: Bool { if case .overdue = self { return true }; return false }
}

// MARK: - The vocabulary of NFPA 110

enum TestTier: String, CaseIterable, Identifiable {
    case weekly, monthly, annual, ats

    var id: String { rawValue }

    var name: String {
        switch self {
        case .weekly: return "Weekly Inspection"
        case .monthly: return "Monthly Load Test"
        case .annual: return "Annual Test"
        case .ats: return "Transfer Switch Test"
        }
    }

    var shortName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .ats: return "ATS"
        }
    }

    /// The three that appear as bars on the board. The ATS test has its own line underneath.
    static var scheduled: [TestTier] { [.weekly, .monthly, .annual] }

    /// Tiers where the set is running and readings are taken.
    var isRun: Bool { self == .monthly || self == .annual }

    /// The tiers the brief asks to carry the technician's signature.
    var requiresSignature: Bool { isRun }

    var symbol: String {
        switch self {
        case .weekly: return "figure.walk"
        case .monthly: return "bolt.fill"
        case .annual: return "calendar.badge.clock"
        case .ats: return "arrow.left.arrow.right.square"
        }
    }

    var whatItIs: String {
        switch self {
        case .weekly:
            return "A walk-round of the set, which does not have to be running: fuel, oil and coolant levels, battery and charger, block heater, louvres and ventilation, no leaks, and the controller in AUTO."
        case .monthly:
            return "The set run under load for at least the duration and load you set for it, with the electrical and engine readings written down. Exactly what counts depends on the edition your jurisdiction adopted and on the system's Level and Class, so the targets are yours to set."
        case .annual:
            return "A longer continuous run, commonly on a load bank where the building load is not enough on its own, plus the fuel quality check."
        case .ats:
            return "The transfer switch exercised through transfer and retransfer, with the time to transfer recorded. A set that starts but does not transfer has not done its job."
        }
    }
}

enum ItemState: String, CaseIterable, Identifiable {
    case notChecked, ok, attention, notApplicable
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notChecked: return "Not checked"
        case .ok: return "OK"
        case .attention: return "Needs attention"
        case .notApplicable: return "Not applicable"
        }
    }

    var symbol: String {
        switch self {
        case .notChecked: return "circle"
        case .ok: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .notApplicable: return "minus.circle"
        }
    }
}

enum FuelType: String, CaseIterable, Identifiable {
    case diesel, naturalGas, propane, dualFuel
    var id: String { rawValue }

    var name: String {
        switch self {
        case .diesel: return "Diesel"
        case .naturalGas: return "Natural gas"
        case .propane: return "Propane"
        case .dualFuel: return "Dual fuel"
        }
    }

    /// Stored fuel goes stale; piped fuel does not. That is the whole reason the annual test
    /// carries a fuel quality check for some sets and not others.
    var isStored: Bool { self == .diesel || self == .propane || self == .dualFuel }
}

/// Level 1 is where failure of the emergency power supply system could result in loss of human
/// life or serious injury. Level 2 is where the failure is less critical to life and safety.
enum SystemLevel: String, CaseIterable, Identifiable {
    case level1, level2, unclassified
    var id: String { rawValue }

    var short: String {
        switch self {
        case .level1: return "Level 1"
        case .level2: return "Level 2"
        case .unclassified: return "Level not set"
        }
    }

    var detail: String {
        switch self {
        case .level1: return "Failure could result in loss of human life or serious injury."
        case .level2: return "Failure is less critical to human life and safety."
        case .unclassified: return "Not classified in the documents you were given."
        }
    }
}

/// Class is the minimum time, in hours, the system is designed to run at its rated load without
/// being refuelled or recharged.
enum SystemClass: String, CaseIterable, Identifiable {
    case class0083, class025, class2, class6, class48, classX
    var id: String { rawValue }

    var short: String {
        switch self {
        case .class0083: return "Class 0.083"
        case .class025: return "Class 0.25"
        case .class2: return "Class 2"
        case .class6: return "Class 6"
        case .class48: return "Class 48"
        case .classX: return "Class X"
        }
    }

    var hours: Double? {
        switch self {
        case .class0083: return 0.083
        case .class025: return 0.25
        case .class2: return 2
        case .class6: return 6
        case .class48: return 48
        case .classX: return nil
        }
    }

    var detail: String {
        switch self {
        case .class0083: return "Five minutes at rated load without refuelling."
        case .class025: return "Fifteen minutes at rated load without refuelling."
        case .class2: return "Two hours at rated load without refuelling."
        case .class6: return "Six hours at rated load without refuelling."
        case .class48: return "Forty-eight hours at rated load without refuelling."
        case .classX: return "A duration specified for this system rather than one of the standard classes."
        }
    }
}

/// Type is the maximum time, in seconds, the system will allow the load terminals of the transfer
/// switch to be without acceptable power.
enum SystemType: String, CaseIterable, Identifiable {
    case typeU, type10, type60, type120, typeM
    var id: String { rawValue }

    var short: String {
        switch self {
        case .typeU: return "Type U"
        case .type10: return "Type 10"
        case .type60: return "Type 60"
        case .type120: return "Type 120"
        case .typeM: return "Type M"
        }
    }

    var name: String {
        switch self {
        case .typeU: return "Type U (essentially uninterruptible)"
        case .type10: return "Type 10 (ten seconds)"
        case .type60: return "Type 60 (sixty seconds)"
        case .type120: return "Type 120 (one hundred and twenty seconds)"
        case .typeM: return "Type M (manual, no time limit)"
        }
    }

    /// The seconds a transfer time is measured against. Nil where the Type carries no figure.
    var seconds: Double? {
        switch self {
        case .typeU: return nil
        case .type10: return 10
        case .type60: return 60
        case .type120: return 120
        case .typeM: return nil
        }
    }
}

enum FuelQuality: String, CaseIterable, Identifiable {
    case notTested, sampled, acceptable, needsTreatment, polished
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notTested: return "Not tested"
        case .sampled: return "Sample sent"
        case .acceptable: return "Result acceptable"
        case .needsTreatment: return "Treatment needed"
        case .polished: return "Fuel polished"
        }
    }
}

// MARK: - Formatting, shared by the UI and both exporters

enum Format {
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    static func seconds(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value)) sec" : String(format: "%.1f sec", value)
    }

    static func days(_ value: Int) -> String { value == 1 ? "1 day" : "\(value) days" }

    /// Long units, spelled out. "1 hr 45 min", never "1:45".
    static func duration(_ minutes: Int) -> String {
        if minutes <= 0 { return "0 min" }
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) hr" }
        return "\(hours) hr \(rest) min"
    }
}
