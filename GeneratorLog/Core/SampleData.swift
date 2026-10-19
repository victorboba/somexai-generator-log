import Foundation
import SwiftData

#if DEBUG
/// Debug-only sample data for screenshots and manual testing: two generators with enough history
/// to show every state the board cares about — a set overdue and out of AUTO, and one current.
/// Launch with `-sampleData` to insert it on first run, or use Settings → Debug → Insert sample data.
enum SampleData {
    static func insert(into context: ModelContext) {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: .now) ?? .now }

        // EG-1: current on everything, controller in AUTO. The quiet, healthy machine.
        let eg1 = Generator(unitID: "EG-1", location: "Basement mechanical room", nameplateKW: 500)
        eg1.make = "Cummins"; eg1.model = "C500D6"; eg1.serialNumber = "CU-88213"
        eg1.nameplateVolts = 480
        eg1.level = .level1; eg1.systemClass = .class6; eg1.systemType = .type10
        eg1.atsName = "ATS-1"; eg1.atsLocation = "Electrical room B1"; eg1.atsIntervalMonths = 1
        eg1.requiredMonthlyMinutes = 30; eg1.requiredLoadPercent = 30; eg1.requiredAnnualMinutes = 240
        eg1.inAuto = true
        context.insert(eg1)

        let eg1Weekly = GenTest(date: daysAgo(2), tier: .weekly)
        eg1Weekly.technicianName = "R. Alvarez"
        eg1Weekly.generator = eg1
        for item in WeeklyItem.items(for: eg1.fuelType) { eg1Weekly.set(.ok, for: item) }
        context.insert(eg1Weekly)

        let eg1Monthly = GenTest(date: daysAgo(10), tier: .monthly)
        eg1Monthly.technicianName = "R. Alvarez"
        eg1Monthly.generator = eg1
        eg1Monthly.runStart = daysAgo(10)
        eg1Monthly.runEnd = cal.date(byAdding: .minute, value: 35, to: eg1Monthly.runStart!)
        eg1Monthly.loadKW = 190
        eg1Monthly.voltsL1 = 479; eg1Monthly.voltsL2 = 481; eg1Monthly.voltsL3 = 480
        eg1Monthly.ampsL1 = 228; eg1Monthly.ampsL2 = 230; eg1Monthly.ampsL3 = 227
        eg1Monthly.frequencyHz = 60; eg1Monthly.oilPressurePSI = 52; eg1Monthly.coolantTempF = 185
        eg1Monthly.batteryVolts = 13.6; eg1Monthly.leftInAuto = true
        context.insert(eg1Monthly)

        let eg1Ats = GenTest(date: daysAgo(40), tier: .ats)
        eg1Ats.generator = eg1
        eg1Ats.transferSeconds = 8; eg1Ats.retransferSeconds = 12
        eg1Ats.loadTransferred = true; eg1Ats.returnedToNormal = true; eg1Ats.leftInAuto = true
        context.insert(eg1Ats)

        // EG-2: overdue on its monthly test and left in MANUAL after the last one — the row that
        // has to sort to the top of the board.
        let eg2 = Generator(unitID: "EG-2", location: "Roof penthouse", nameplateKW: 250)
        eg2.make = "Generac"; eg2.model = "SG250"; eg2.serialNumber = "GN-40217"
        eg2.nameplateVolts = 480
        eg2.level = .level2; eg2.systemClass = .class2; eg2.systemType = .type60
        eg2.atsName = "ATS-2"; eg2.atsLocation = "Roof penthouse"; eg2.atsIntervalMonths = 6
        eg2.requiredMonthlyMinutes = 30; eg2.requiredLoadPercent = 30; eg2.requiredAnnualMinutes = 240
        eg2.takeOutOfAuto(reason: "Left in MANUAL after the load bank test; the electrician has not signed off yet.",
                          on: daysAgo(6))
        context.insert(eg2)

        let eg2Weekly = GenTest(date: daysAgo(14), tier: .weekly)
        eg2Weekly.technicianName = "T. Nguyen"
        eg2Weekly.generator = eg2
        for item in WeeklyItem.items(for: eg2.fuelType) {
            eg2Weekly.set(item == .controllerInAuto ? .attention : .ok, for: item)
        }
        eg2Weekly.setNote("Selector left in MANUAL after the contractor's load bank test.", for: .controllerInAuto)
        context.insert(eg2Weekly)

        let eg2Monthly = GenTest(date: daysAgo(48), tier: .monthly)
        eg2Monthly.technicianName = "T. Nguyen"
        eg2Monthly.generator = eg2
        eg2Monthly.runMinutesEntered = 22
        eg2Monthly.loadKW = 55
        eg2Monthly.frequencyHz = 60; eg2Monthly.oilPressurePSI = 48; eg2Monthly.coolantTempF = 178
        eg2Monthly.batteryVolts = 13.2; eg2Monthly.leftInAuto = true
        context.insert(eg2Monthly)
    }
}
#endif
