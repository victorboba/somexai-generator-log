import Testing
import Foundation
import PDFKit
@testable import GeneratorLog

/// Rule 7: PDFDocument collapses whitespace and returns columns out of order, so every assertion
/// here normalises whitespace first and checks pieces independently rather than adjacency.
struct ExportTests {
    private func generator() -> Generator {
        let g = Generator(unitID: "EG-9", location: "Basement", nameplateKW: 400)
        g.make = "Kohler"; g.model = "400REZXB"; g.serialNumber = "KH-771"
        g.nameplateVolts = 480
        g.level = .level1; g.systemClass = .class6; g.systemType = .type10
        g.atsName = "ATS-9"
        g.requiredMonthlyMinutes = 30; g.requiredLoadPercent = 30; g.requiredAnnualMinutes = 240
        return g
    }

    private func monthlyTest(for g: Generator, minutes: Int = 35, loadKW: Double = 140) -> GenTest {
        let t = GenTest(date: Date(timeIntervalSince1970: 1_700_000_000), tier: .monthly)
        t.generator = g
        t.technicianName = "D. Castellanos"
        t.runMinutesEntered = minutes
        t.loadKW = loadKW
        t.leftInAuto = true
        g.tests = [t]
        return t
    }

    // MARK: CSV

    @Test func csvHasAHeaderAndOneRowPerTest() throws {
        let g = generator()
        _ = monthlyTest(for: g)
        let text = try String(contentsOf: try CSVExporter.export([g]), encoding: .utf8)
        let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: true))
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("unit,location,make,model,serial"))
        #expect(lines[1].contains("EG-9"))
    }

    @Test func csvRecordsLoadPercentAgainstNameplate() throws {
        let g = generator()
        _ = monthlyTest(for: g, minutes: 35, loadKW: 140) // 140 / 400 = 35%
        let text = try String(contentsOf: try CSVExporter.export([g]), encoding: .utf8)
        #expect(text.contains(",35,"), "140 kW of a 400 kW nameplate should read as 35%")
    }

    @Test func csvOmitsAnnualOnlyColumnsForAMonthlyTest() throws {
        let g = generator()
        _ = monthlyTest(for: g)
        let lines = Array(try String(contentsOf: try CSVExporter.export([g]), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true))
        // omittingEmptySubsequences defaults to true, which silently drops every empty column and
        // leaves the row shorter than the header — so indexing the row by a header position runs off
        // the end and traps. An empty field is exactly what this test is checking for, so the split
        // has to keep them.
        let header = lines[0].split(separator: ",", omittingEmptySubsequences: false)
        let row = lines[1].split(separator: ",", omittingEmptySubsequences: false)
        let loadBankIndex = header.firstIndex(of: "load_bank_used")!
        #expect(row[loadBankIndex] == "")
    }

    // MARK: PDF — single test

    @Test func thePdfNamesTheGeneratorAndTheRule() throws {
        let g = generator()
        let t = monthlyTest(for: g)
        let doc = try #require(PDFDocument(url: try PDFExporter.export(t, generator: g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Monthly Load Test") || text.contains("Monthly load test"))
        #expect(text.contains("NFPA 110"))
        #expect(text.contains("EG-9"))
    }

    @Test func thePdfReportsTheRunAgainstTheConfiguredTarget() throws {
        let g = generator()
        let t = monthlyTest(for: g, minutes: 35, loadKW: 140)
        let doc = try #require(PDFDocument(url: try PDFExporter.export(t, generator: g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("35 min"))
        #expect(text.contains("35%"))
        #expect(text.contains("400"))
    }

    @Test func thePdfSaysWhenARunRecordIsUnsigned() throws {
        let g = generator()
        let t = monthlyTest(for: g)
        let doc = try #require(PDFDocument(url: try PDFExporter.export(t, generator: g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Not signed"))
    }

    @Test func thePdfNeverClaimsToCertifyTheSystem() throws {
        let g = generator()
        let t = monthlyTest(for: g)
        let doc = try #require(PDFDocument(url: try PDFExporter.export(t, generator: g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("does not certify"))
        #expect(!text.contains("§"))
    }

    @Test func theWeeklyPdfListsTheAutoState() throws {
        let g = generator()
        let t = GenTest(tier: .weekly)
        t.generator = g
        for item in WeeklyItem.items(for: g.fuelType) { t.set(.ok, for: item) }
        t.set(.attention, for: .controllerInAuto)
        t.setNote("Selector in MANUAL.", for: .controllerInAuto)
        g.tests = [t]
        let doc = try #require(PDFDocument(url: try PDFExporter.export(t, generator: g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("flagged for attention"))
        #expect(text.contains("Selector in MANUAL"))
    }

    // MARK: PDF — history packet

    @Test func theHistoryPacketShowsTheAutoStateAndEveryTest() throws {
        let g = generator()
        g.takeOutOfAuto(reason: "Left in MANUAL by the contractor.", on: Date(timeIntervalSince1970: 1_699_000_000))
        _ = monthlyTest(for: g)
        let doc = try #require(PDFDocument(url: try PDFExporter.exportHistory(g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("NOT IN AUTO"))
        #expect(text.contains("Left in MANUAL by the contractor"))
        #expect(text.contains("Monthly"))
    }

    @Test func anUntestedGeneratorSaysSo() throws {
        let g = Generator(unitID: "NEW-1")
        let doc = try #require(PDFDocument(url: try PDFExporter.exportHistory(g)))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("No tests have been recorded"))
    }
}
