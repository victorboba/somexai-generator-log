import Testing
import Foundation
@testable import GeneratorLog

/// The checklist has to fit the fuel type. A set fed from the gas main is never asked for a tank
/// level, and never short a record for it.
struct WeeklyItemTests {
    @Test func aGasFedSetIsNeverAskedForFuelLevel() {
        #expect(!WeeklyItem.items(for: .naturalGas).contains(.fuelLevel))
        #expect(WeeklyItem.items(for: .diesel).contains(.fuelLevel))
        #expect(WeeklyItem.items(for: .propane).contains(.fuelLevel))
    }

    @Test func controllerInAutoIsOnEveryFuelType() {
        for fuel in FuelType.allCases {
            #expect(WeeklyItem.items(for: fuel).contains(.controllerInAuto), "\(fuel) must still check AUTO")
        }
    }

    @Test func resultsAreStoredByNameSoAddingAnItemCannotRewriteHistory() {
        let t = GenTest(tier: .weekly)
        t.set(.attention, for: .noLeaks)
        #expect(t.resultsRaw["noLeaks"] == "attention")
        #expect(t.result(.batteryCondition) == .notChecked)
    }

    @Test func markingControllerAttentionSetsLeftInAutoFalse() {
        let t = GenTest(tier: .weekly)
        #expect(t.leftInAuto)
        t.set(.attention, for: .controllerInAuto)
        #expect(!t.leftInAuto)
        t.set(.ok, for: .controllerInAuto)
        #expect(t.leftInAuto)
    }
}

/// The run's arithmetic: duration and load percentage against the generator's own configured
/// targets. Every property here is arithmetic on numbers the user entered — never a verdict.
struct RunOutcomeTests {
    private func generator(kW: Double = 400, minutes: Int = 30, loadPercent: Double = 30) -> Generator {
        let g = Generator(unitID: "EG-1", nameplateKW: kW)
        g.requiredMonthlyMinutes = minutes
        g.requiredLoadPercent = loadPercent
        return g
    }

    @Test func aRunThatMeetsBothTargetsReportsMetEverything() {
        let g = generator()
        let t = GenTest(tier: .monthly)
        t.generator = g
        t.runMinutesEntered = 35
        t.loadKW = 140 // 35% of 400
        let outcome = t.outcome(for: g)!
        #expect(outcome.metDuration)
        #expect(outcome.metLoad == true)
        #expect(outcome.metEverything)
    }

    @Test func aShortRunFallsBelowTarget() {
        let g = generator()
        let t = GenTest(tier: .monthly)
        t.generator = g
        t.runMinutesEntered = 12
        t.loadKW = 140
        let outcome = t.outcome(for: g)!
        #expect(!outcome.metDuration)
        #expect(outcome.shortfallMinutes == 18)
    }

    @Test func loadPercentIsNilWithoutANameplateEnteredNotZero() {
        let g = generator(kW: 0)
        let t = GenTest(tier: .monthly)
        t.generator = g
        t.runMinutesEntered = 30
        t.loadKW = 100
        let outcome = t.outcome(for: g)!
        #expect(outcome.loadPercent == nil, "no nameplate means nothing to compare against, not a 0% load")
    }

    @Test func loadPercentIsNilWithoutALoadReadingEntered() {
        let g = generator()
        let t = GenTest(tier: .monthly)
        t.generator = g
        t.runMinutesEntered = 30
        let outcome = t.outcome(for: g)!
        #expect(outcome.loadPercent == nil)
    }

    @Test func clockTimesWinOverATypedMinutesFigure() {
        let t = GenTest(tier: .monthly)
        t.runMinutesEntered = 999
        t.runStart = Date(timeIntervalSince1970: 0)
        t.runEnd = Date(timeIntervalSince1970: 60 * 40)
        #expect(t.runMinutes == 40)
    }

    @Test func anEndBeforeItsStartIsTreatedAsNothingRecorded() {
        let t = GenTest(tier: .monthly)
        t.runStart = Date(timeIntervalSince1970: 1000)
        t.runEnd = Date(timeIntervalSince1970: 0)
        #expect(t.runMinutes == 0)
    }

    @Test func aRunTierWithNoGeneratorStillReturnsAnOutcomeAtZero() {
        let t = GenTest(tier: .annual)
        let outcome = t.outcome(for: nil)!
        #expect(outcome.targetMinutes == 0)
        #expect(outcome.nameplateKW == 0)
    }

    @Test func weeklyAndAtsTiersHaveNoRunOutcome() {
        #expect(GenTest(tier: .weekly).outcome(for: nil) == nil)
        #expect(GenTest(tier: .ats).outcome(for: nil) == nil)
    }
}

/// The transfer switch measurement, against the system's own Type.
struct TransferOutcomeTests {
    @Test func aTransferWithinType10IsWithinWindow() {
        let g = Generator(); g.systemType = .type10
        let t = GenTest(tier: .ats)
        t.generator = g
        t.transferSeconds = 8
        #expect(t.transfer(for: g)!.withinTypeWindow == true)
    }

    @Test func aTransferOverTypeIsOutsideTheWindow() {
        let g = Generator(); g.systemType = .type10
        let t = GenTest(tier: .ats)
        t.generator = g
        t.transferSeconds = 14
        #expect(t.transfer(for: g)!.withinTypeWindow == false)
    }

    @Test func typeUAndTypeMCarryNoWindowToCompareAgainst() {
        for type in [SystemType.typeU, .typeM] {
            let g = Generator(); g.systemType = type
            let t = GenTest(tier: .ats)
            t.generator = g
            t.transferSeconds = 5
            #expect(t.transfer(for: g)!.withinTypeWindow == nil)
        }
    }

    @Test func noTransferRecordedIsNilNotZeroSeconds() {
        let g = Generator(); g.systemType = .type10
        let t = GenTest(tier: .ats)
        t.generator = g
        #expect(t.transfer(for: g)!.withinTypeWindow == nil)
    }
}

/// Four clocks at once, sorted worst first, with AUTO outranking every one of them.
struct ClockAndBoardTests {
    private func generator(weekly: Int? = nil, monthly: Int? = nil, annual: Int? = nil) -> Generator {
        let g = Generator(unitID: "EG-4")
        var tests: [GenTest] = []
        for (tier, days) in [(TestTier.weekly, weekly), (.monthly, monthly), (.annual, annual)] {
            guard let days else { continue }
            let t = GenTest(date: Calendar.current.date(byAdding: .day, value: -days, to: .now)!, tier: tier)
            t.generator = g
            tests.append(t)
        }
        g.tests = tests
        return g
    }

    @Test func aNeverTestedClockIsNeverTested() {
        #expect(generator().clock(.weekly).state == .neverTested)
    }

    @Test func withinTheIntervalIsNotOverdue() {
        let g = generator(weekly: 3, monthly: 10, annual: 100)
        if case .dueIn = g.clock(.weekly).state {} else { Issue.record("a weekly test 3 days old should still be current") }
    }

    @Test func pastTheIntervalIsOverdue() {
        let g = generator(weekly: 10, monthly: 50, annual: 400)
        guard case .overdue = g.clock(.monthly).state else { Issue.record("monthly should be overdue"); return }
        guard case .overdue = g.clock(.annual).state else { Issue.record("annual should be overdue"); return }
    }

    @Test func clocksComeBackWorstFirst() {
        let g = generator(weekly: 1, monthly: 50, annual: 10)
        #expect(g.clocks(tiers: TestTier.scheduled).first?.tier == .monthly, "the overdue one leads")
    }

    @Test func aSetOutOfAutoOutranksAnyOverdueClock() {
        let onTime = generator(weekly: 1, monthly: 1, annual: 1)
        let overdue = generator(weekly: 90, monthly: 90, annual: 900)
        onTime.takeOutOfAuto(reason: "Left in MANUAL.")
        #expect(onTime.boardUrgency() > overdue.boardUrgency(), "AUTO comes before any late record")
    }

    @Test func confirmingBackInAutoClearsTheReasonAndDate() {
        let g = generator()
        g.takeOutOfAuto(reason: "Selector in OFF.")
        #expect(!g.inAuto)
        g.confirmBackInAuto()
        #expect(g.inAuto)
        #expect(g.notInAutoReason.isEmpty)
        #expect(g.notInAutoSince == nil)
    }

    @Test func takingOutOfAutoTwiceKeepsTheOriginalSince() {
        let g = generator()
        let first = Date(timeIntervalSince1970: 1_000_000)
        g.takeOutOfAuto(reason: "First finding.", on: first)
        g.takeOutOfAuto(reason: "Second finding.", on: Date(timeIntervalSince1970: 2_000_000))
        #expect(g.notInAutoSince == first, "already out of AUTO, so a second report should not reset the clock")
    }
}

/// The twelve-month picture a surveyor asks for.
struct AnnualSummaryTests {
    @Test func onlyMonthlyTestsThatMetTheirOwnTargetCountAsMeetingIt() {
        let g = Generator(unitID: "EG-5", nameplateKW: 100)
        g.requiredMonthlyMinutes = 30; g.requiredLoadPercent = 30

        let met = GenTest(date: Calendar.current.date(byAdding: .day, value: -10, to: .now)!, tier: .monthly)
        met.generator = g; met.runMinutesEntered = 35; met.loadKW = 40

        let missed = GenTest(date: Calendar.current.date(byAdding: .day, value: -40, to: .now)!, tier: .monthly)
        missed.generator = g; missed.runMinutesEntered = 10; missed.loadKW = 40

        g.tests = [met, missed]
        let summary = g.annualSummary()
        #expect(summary.monthlyCount == 2)
        #expect(summary.monthlyMeetingTarget == 1)
    }

    @Test func testsOutsideTheTwelveMonthWindowAreNotCounted() {
        let g = Generator(unitID: "EG-6")
        let old = GenTest(date: Calendar.current.date(byAdding: .month, value: -14, to: .now)!, tier: .weekly)
        old.generator = g
        g.tests = [old]
        #expect(g.annualSummary().weeklyCount == 0)
    }
}
