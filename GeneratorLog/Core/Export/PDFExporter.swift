import Foundation
import PDFKit
import UIKit

/// The documented record: one test, or a generator's whole retained history.
///
/// NFPA 110 Chapter 8 is the reason this app exists, but the exact numeric thresholds vary by the
/// edition a jurisdiction has adopted and by the system's own Level and Class, so this report
/// never prints a clause number and never declares a generator compliant. It states what was
/// recorded and what that measured against the target the generator's owner configured — the
/// arithmetic is the app's job, the judgement is the reader's.
enum PDFExporter {
    /// One documented test — the page handed to whoever asked for it.
    static func export(_ test: GenTest, generator: Generator?) throws -> URL {
        try render(named: "\(AppConfig.exportFileStem)-\(test.tier.rawValue)-\(ISO8601DateFormatter.day.string(from: test.date))") { draw in
            draw.title(test.tier.name)
            draw.line("NFPA 110, Chapter 8 — \(test.tier.whatItIs)", size: 10, colour: .secondaryLabel)
            draw.rule()

            draw.line(generator?.title ?? "Unassigned generator", size: 13, weight: .semibold, gapAfter: 2)
            var identity: [String] = []
            if let g = generator {
                identity.append(g.classification)
                if !g.location.isEmpty { identity.append(g.location) }
                if g.nameplateKW > 0 { identity.append("\(Format.number(g.nameplateKW)) kW nameplate") }
            }
            if !identity.isEmpty { draw.line(identity.joined(separator: "  ·  "), size: 10, colour: .secondaryLabel) }
            draw.line("Tested \(test.date.formatted(date: .long, time: .omitted))", size: 10, colour: .secondaryLabel)
            draw.rule()

            switch test.tier {
            case .weekly:
                draw.line("Controller in AUTO", size: 12, weight: .semibold, gapAfter: 2)
                draw.line(test.leftInAuto ? "Yes" : "No — flagged for attention", size: 11,
                          weight: test.leftInAuto ? .regular : .bold,
                          colour: test.leftInAuto ? .label : .systemRed, gapAfter: 8)
                draw.line("Items checked", size: 12, weight: .semibold, gapAfter: 6)
                for section in WeeklySection.allCases {
                    let items = WeeklyItem.items(in: section, for: generator?.fuelType ?? .diesel)
                    guard !items.isEmpty else { continue }
                    for item in items {
                        let state = test.result(item)
                        let mark = switch state {
                        case .ok: "OK"
                        case .attention: "ATTN"
                        case .notApplicable: "N/A"
                        case .notChecked: "—"
                        }
                        let tint: UIColor = state == .attention ? .systemOrange : (state == .notChecked ? .secondaryLabel : .label)
                        draw.line("\(mark.padding(toLength: 6, withPad: " ", startingAt: 0))\(item.name)",
                                  size: 9, weight: state == .attention ? .semibold : .regular, colour: tint, gapAfter: 1)
                        let note = test.note(item)
                        if !note.isEmpty { draw.line(note, size: 9, colour: .secondaryLabel, indent: 48, gapAfter: 3) }
                    }
                }

            case .monthly, .annual:
                if let outcome = test.outcome(for: generator) {
                    draw.line(outcome.durationText, size: 12, weight: .semibold, colour: outcome.metDuration ? .systemGreen : .systemOrange, gapAfter: 2)
                    draw.line(outcome.loadText, size: 11, gapAfter: 8)
                } else {
                    draw.line("No run recorded.", size: 11, colour: .secondaryLabel, gapAfter: 8)
                }
                draw.line("Controller left in AUTO after the test", size: 10, weight: .semibold, gapAfter: 2)
                draw.line(test.leftInAuto ? "Yes" : "No — flagged for attention", size: 10,
                          colour: test.leftInAuto ? .label : .systemRed, gapAfter: 8)

                draw.line("Readings", size: 12, weight: .semibold, gapAfter: 6)
                var readings: [(String, String)] = [
                    ("Frequency", test.frequencyHz > 0 ? "\(Format.number(test.frequencyHz)) Hz" : "—"),
                    ("Oil pressure", test.oilPressurePSI > 0 ? "\(Format.number(test.oilPressurePSI)) psi" : "—"),
                    ("Coolant temperature", test.coolantTempF > 0 ? "\(Format.number(test.coolantTempF)) °F" : "—"),
                    ("Battery voltage", test.batteryVolts > 0 ? "\(Format.number(test.batteryVolts)) V" : "—"),
                ]
                if test.voltsL1 + test.voltsL2 + test.voltsL3 > 0 {
                    readings.append(("Voltage L1/L2/L3", "\(Format.number(test.voltsL1)) / \(Format.number(test.voltsL2)) / \(Format.number(test.voltsL3))"))
                }
                if test.ampsL1 + test.ampsL2 + test.ampsL3 > 0 {
                    readings.append(("Amperage L1/L2/L3", "\(Format.number(test.ampsL1)) / \(Format.number(test.ampsL2)) / \(Format.number(test.ampsL3))"))
                }
                for (label, value) in readings {
                    draw.line("\(label.padding(toLength: 22, withPad: " ", startingAt: 0))\(value)", size: 9, gapAfter: 2)
                }
                if test.tier == .annual {
                    draw.rule()
                    draw.line("Load bank used: \(test.loadBankUsed ? "Yes" : "No")", size: 10, gapAfter: 2)
                    draw.line("Fuel quality: \(test.fuelQuality.name)", size: 10, gapAfter: 2)
                    if !test.fuelQualityNote.isEmpty { draw.line(test.fuelQualityNote, size: 9, colour: .secondaryLabel) }
                }

            case .ats:
                if let transfer = test.transfer(for: generator) {
                    draw.line(transfer.summaryLong, size: 11, gapAfter: 8)
                    if let within = transfer.withinTypeWindow {
                        draw.line(within ? "Within the Type window" : "Outside the Type window", size: 10,
                                  weight: .semibold, colour: within ? .systemGreen : .systemOrange)
                    }
                } else {
                    draw.line("No transfer recorded.", size: 11, colour: .secondaryLabel)
                }
            }

            if !test.correctiveAction.isEmpty {
                draw.rule()
                draw.line("Corrective action", size: 12, weight: .semibold, gapAfter: 4)
                draw.line(test.correctiveAction, size: 10)
            }
            if !test.notes.isEmpty {
                draw.rule()
                draw.line("Notes", size: 12, weight: .semibold, gapAfter: 4)
                draw.line(test.notes, size: 10)
            }

            draw.rule()
            draw.line(test.technicianName.isEmpty ? "Technician not named" : test.technicianName,
                      size: 11, weight: .semibold, gapAfter: 2)
            if test.tier.requiresSignature {
                if let signature = test.signature, let image = UIImage(data: signature) {
                    draw.image(image, maxHeight: 70)
                } else {
                    draw.line("Not signed. \(test.tier.name) records are meant to carry the signature "
                              + "of the person who conducted them.", size: 9, colour: .systemRed)
                }
            }

            draw.rule()
            draw.line("Values above are as entered for this generator's own configured targets. "
                      + "\(AppConfig.appName) reports what was recorded; it does not certify this "
                      + "system, does not determine compliance with any edition of NFPA 110, and "
                      + "does not replace the record your AHJ or insurer requires you to keep.",
                      size: 8, colour: .secondaryLabel)
        }
    }

    /// A generator's whole retained history — the packet handed to a surveyor.
    static func exportHistory(_ generator: Generator, asOf today: Date = .now) throws -> URL {
        try render(named: "\(AppConfig.exportFileStem)-history-\(ISO8601DateFormatter.day.string(from: today))") { draw in
            draw.title("Generator test history")
            draw.line(generator.title, size: 13, colour: .secondaryLabel, gapAfter: 2)
            draw.line(generator.classification, size: 10, colour: .secondaryLabel)
            if !generator.location.isEmpty { draw.line(generator.location, size: 10, colour: .secondaryLabel) }
            draw.rule()

            draw.line("Controller state", size: 12, weight: .semibold, gapAfter: 4)
            if generator.inAuto {
                draw.line("In AUTO", size: 11, weight: .semibold, colour: .systemGreen)
            } else {
                draw.line("NOT IN AUTO", size: 13, weight: .bold, colour: .systemRed, gapAfter: 2)
                if !generator.notInAutoReason.isEmpty { draw.line(generator.notInAutoReason, size: 10) }
                if let since = generator.notInAutoSince {
                    draw.line("Since \(since.formatted(date: .long, time: .omitted))", size: 9, colour: .secondaryLabel)
                }
            }
            draw.rule()

            draw.line("The three scheduled clocks", size: 12, weight: .semibold, gapAfter: 6)
            for clock in generator.clocks(asOf: today, tiers: TestTier.scheduled) {
                var text = "\(clock.tier.name.padding(toLength: 20, withPad: " ", startingAt: 0))\(clock.state.headline)"
                if let last = clock.last { text += "  (last \(ISO8601DateFormatter.day.string(from: last)))" }
                draw.line(text, size: 10, weight: clock.state.needsAttention ? .semibold : .regular,
                          colour: clock.state.isOverdue ? .systemRed : (clock.state.needsAttention ? .systemOrange : .label), gapAfter: 2)
            }
            let ats = generator.clock(.ats, asOf: today)
            var atsText = "\(TestTier.ats.name.padding(toLength: 20, withPad: " ", startingAt: 0))\(ats.state.headline)"
            if let last = ats.last { atsText += "  (last \(ISO8601DateFormatter.day.string(from: last)))" }
            draw.line(atsText, size: 10, colour: ats.state.needsAttention ? .systemOrange : .label)
            draw.rule()

            let summary = generator.annualSummary(asOf: today)
            draw.line("Last twelve months", size: 12, weight: .semibold, gapAfter: 4)
            draw.line("\(summary.weeklyCount) weekly inspections, \(summary.monthlyCount) monthly tests "
                      + "(\(summary.monthlyMeetingTarget) met this generator's configured target), "
                      + "\(summary.annualCount) annual tests, \(summary.atsCount) transfer switch tests.",
                      size: 9, colour: .secondaryLabel)
            draw.rule()

            draw.line("Every test", size: 12, weight: .semibold, gapAfter: 6)
            if generator.sortedTests.isEmpty {
                draw.line("No tests have been recorded for this generator.", size: 10, colour: .secondaryLabel)
            }
            for test in generator.sortedTests {
                var parts = [test.headline(for: generator)]
                if !test.technicianName.isEmpty { parts.append(test.technicianName) }
                if test.tier.requiresSignature { parts.append(test.signature == nil ? "unsigned" : "signed") }
                if !test.leftInAuto { parts.append("left out of AUTO") }
                draw.line("\(ISO8601DateFormatter.day.string(from: test.date))   \(test.tier.shortName) — \(parts.joined(separator: "  ·  "))",
                          size: 9, weight: test.leftInAuto ? .regular : .semibold,
                          colour: test.leftInAuto ? .label : .systemRed, gapAfter: 2)
            }

            draw.rule()
            draw.line("This packet reports what was entered for this generator's own configured "
                      + "targets. \(AppConfig.appName) does not certify this system and does not "
                      + "determine compliance with any edition of NFPA 110 — confirm the edition and "
                      + "thresholds your jurisdiction and insurer apply.", size: 8, colour: .secondaryLabel)
        }
    }

    // MARK: - Page plumbing

    private final class Draw {
        let ctx: UIGraphicsPDFRendererContext
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792, margin: CGFloat = 48
        var y: CGFloat = 48

        init(_ ctx: UIGraphicsPDFRendererContext) { self.ctx = ctx }

        func title(_ text: String) { line(text, size: 20, weight: .semibold) }

        func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                  colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
            let width = pageWidth - margin * 2 - indent
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
            (text as NSString).draw(
                with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            y += bounding.height + gapAfter
        }

        func image(_ image: UIImage, maxHeight: CGFloat) {
            let scale = min(maxHeight / image.size.height, (pageWidth - margin * 2) / image.size.width, 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if y + size.height > pageHeight - margin { ctx.beginPage(); y = margin }
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
            y += size.height + 6
        }

        func rule(gap: CGFloat = 10) {
            y += gap / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
            y += gap / 2
        }
    }

    private static func render(named name: String, _ body: (Draw) -> Void) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            body(Draw(ctx))
        }
        return url
    }
}
