import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Generator Test Log"
    static let bundleID = "com.example.generator-log"
    static let appGroupID = "group.com.example.generator-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/generator-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls the thing the user adds first. Every test belongs to one of these.
    static let entryNoun = "Generator"
    static let entryNounPlural = "Generators"
    /// File name stem for exports: "generator-log-2026-09-14.csv".
    static let exportFileStem = "generator-log"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "bolt.square", title: "The three clocks NFPA 110 runs",
                       body: "Weekly inspection, monthly load test and annual test, tracked per generator and sorted worst-first."),
        OnboardingPage(symbol: "switch.2", title: "AUTO comes first",
                       body: "A set left in OFF or MANUAL after a test will not start when the power fails. The board leads with that."),
        OnboardingPage(symbol: "square.and.arrow.up", title: "The packet a surveyor accepts",
                       body: "Export a signed PDF per test or a whole generator's history. Your records stay on your phone."),
    ]

    static let paywallSymbol = "bolt.badge.checkmark"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited generators and tests",
        "Signed PDF and CSV export",
        "Home Screen widget and Siri Shortcut",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "From the first generator to a signed export, in the order you'll actually do it."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "plus.circle", title: "Add a generator",
                  body: "Tap Add a Generator, then fill in the unit ID, nameplate kW and voltage, its NFPA 110 Level, Class and Type, the ATS it feeds, and your own required duration and load percentage.",
                  tip: "Nameplate kW is the one number every load test is measured against, so set it first."),
        HowToStep(symbol: "figure.walk", title: "Run the weekly inspection",
                  body: "Open the generator and tap Weekly Inspection. Work down the list — fuel, engine, batteries, the room, then the controller — and answer OK, Needs Attention or N/A for each item. Controller in AUTO is the last one for a reason."),
        HowToStep(symbol: "bolt.fill", title: "Run the monthly load test",
                  body: "Tap Monthly Load Test, enter the run's start and stop times (or the minutes off the controller) and the load in kW. The app works out the run time and the load as a percentage of nameplate for you, against the target you set."),
        HowToStep(symbol: "arrow.left.arrow.right.square", title: "Run the annual and ATS tests",
                  body: "Annual Test adds the longer run and the fuel quality check. Transfer Switch Test records how long the ATS took to transfer and retransfer. Both are signed with a finger the same way the monthly test is."),
        HowToStep(symbol: "square.and.arrow.up", title: "Export a report",
                  body: "From any completed test, tap Export PDF for that one record. From the generator screen, tap Generator History (PDF) for the whole packet, or CSV from the fleet board for every test at once."),
        HowToStep(symbol: "rectangle.on.rectangle", title: "Add the widget",
                  body: "Long-press your Home Screen, tap +, search \"\(appName)\", and add the small or medium widget. It leads with anything out of AUTO."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$12.99", lifetime: "$29.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
