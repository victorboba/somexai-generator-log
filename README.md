# Generator Test Log

A log for the weekly inspection, monthly load test, annual test and transfer switch test that NFPA 110 Chapter 8 runs on an emergency generator, with signed PDF records. It is for facility engineers and generator service technicians.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the rest of the collection is in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- Each generator shows its clocks (weekly, monthly, annual, transfer switch) at once, sorted worst first, and leads with any set that is not in AUTO.
- Generator setup: unit ID, nameplate kW and voltage, fuel, NFPA 110 Level, Class and Type, the transfer switch it feeds, and your own required duration and load percentage.
- Weekly inspection: a checklist (fuel, engine, batteries, the room, then the controller) answered OK, Needs Attention or N/A. Controller in AUTO is last on purpose.
- Monthly load test: enter start and stop times (or minutes off the controller) and the load in kW. The app computes run time and load as a percentage of nameplate against the target you set.
- Annual test: a longer run plus the fuel quality check. Transfer switch test: time to transfer and retransfer.
- Tests are signed with a finger. Export a signed PDF per test, a whole generator history PDF, or every test as one CSV.
- Home Screen widget, a Siri/Shortcuts action, and a How do I use guide.

## The boundary

The thresholds are yours. The exact load percentage and run time depend on the edition of NFPA 110 your jurisdiction has adopted and on the system's Level and Class, so each generator carries the targets its owner configured (defaulting to 30 minutes at 30% of nameplate kW and a 4-hour annual run). The app reports arithmetic against those targets. It does not declare a generator compliant.

## Privacy

Everything is stored on the device in SwiftData. There is no account, no analytics and no network access, and iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the phone only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), iOS 17+ (iPhone).

```bash
xcodegen generate
open GeneratorLog.xcodeproj
```

Pick the `GeneratorLog` scheme and an iPhone simulator, then Run.

- Tests: `xcodebuild -scheme GeneratorLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test`. The alternative is `scripts/ci.sh GeneratorLog`.
- Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.
- To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

`Generator` computes its clocks from the test history; each test record keeps the target it was measured against.

## Project layout

- `GeneratorLog/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, then the app).
- `GeneratorLog/Core/`: StoreKit entitlement, CSV and PDF export, review prompt, and the App Shortcut.
- `GeneratorLog/Features/`: the screens.
- `GeneratorLog/Models/`: SwiftData models and the logic on them.
- `GeneratorLogWidget/`: the Home Screen widget.
- `GeneratorLogTests/`, `GeneratorLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, how-to guide).

## License

MIT. See [LICENSE](LICENSE).
