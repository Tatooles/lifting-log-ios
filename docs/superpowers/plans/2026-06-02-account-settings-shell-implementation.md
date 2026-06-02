# Account Settings Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the issue 7 Settings account lifecycle shell with informational sync status and delete-account placeholders.

**Architecture:** Keep Profile as the only account identity/sign-in surface. Add a small SwiftUI Settings account shell under `LiftingLog/Features/Profile/` and wire it into `SettingsView` without importing Clerk or Convex. Cover the shell with a focused UI test that verifies the local-only sync row and delete-account placeholder.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest, XCUITest, XcodeGen, Xcode 26.

---

## File Structure

- Create `LiftingLog/Features/Profile/SettingsAccountSection.swift`
  - Owns the new Settings `Account` section.
  - Renders read-only sync status copy.
  - Renders a destructive-looking `Delete Account` navigation row.
  - Renders the informational delete-account placeholder destination.
  - Does not import Clerk or Convex.
- Modify `LiftingLog/Features/Profile/SettingsView.swift`
  - Inserts `SettingsAccountSection()` between `Rest Timer` and `Data`.
  - Keeps existing units, rest timer, export, alerts, and export sheet behavior unchanged.
- Modify `LiftingLogUITests/LiftingLogUITests.swift`
  - Adds a focused UI test for the Settings account shell and delete-account placeholder.
- Regenerate `LiftingLog.xcodeproj/project.pbxproj`
  - Required because the app uses XcodeGen and the new Swift source file must be included in the generated Xcode project.

---

### Task 1: Settings Account Shell

**Files:**
- Create: `LiftingLog/Features/Profile/SettingsAccountSection.swift`
- Modify: `LiftingLog/Features/Profile/SettingsView.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`
- Regenerate: `LiftingLog.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the failing UI test**

In `LiftingLogUITests/LiftingLogUITests.swift`, insert this test after `testSettingsWeightUnitConversionRoundsDisplayedWorkoutValues()` and before `testSignedOutProfileShowsOptionalAuthAndWorkoutStillWorks()`:

```swift
    @MainActor
    func testSettingsShowsAccountShellAndDeleteAccountPlaceholder() {
        let app = makeApp()
        app.launchArguments.append("--uitest-force-signed-out-auth")
        app.launch()

        app.buttons["ProfileTab"].tap()
        XCTAssertTrue(app.staticTexts["ProfileTitle"].waitForExistence(timeout: 3))
        app.buttons["ProfileSettingsLink"].tap()

        XCTAssertTrue(app.staticTexts["Account"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Sync Status"].exists)
        XCTAssertTrue(app.staticTexts["Local only"].exists)
        XCTAssertTrue(app.staticTexts["Cloud sync is not configured yet."].exists)
        XCTAssertTrue(app.buttons["SettingsDeleteAccountRow"].exists)

        app.buttons["SettingsDeleteAccountRow"].tap()

        XCTAssertTrue(app.staticTexts["SettingsDeleteAccountPlaceholder"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Account deletion is not available yet."].exists)
        XCTAssertTrue(app.staticTexts["This release still stores your workouts locally. Account deletion will be available before release after cloud data deletion is connected."].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
    }
```

- [ ] **Step 2: Run the focused UI test and verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /private/tmp/codex-ios-app-derived-data -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsShowsAccountShellAndDeleteAccountPlaceholder
```

Expected: FAIL because Settings does not yet render `Account`, `Sync Status`, `Local only`, or `SettingsDeleteAccountRow`.

- [ ] **Step 3: Create the Settings account shell component**

Create `LiftingLog/Features/Profile/SettingsAccountSection.swift`:

```swift
import SwiftUI

struct SettingsAccountSection: View {
    var body: some View {
        Section("Account") {
            syncStatusRow

            NavigationLink {
                DeleteAccountPlaceholderView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete Account")
                            .foregroundStyle(.red)
                        Text("Available before release.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .foregroundStyle(.red)
                }
            }
            .accessibilityIdentifier("SettingsDeleteAccountRow")
        }
        .accessibilityIdentifier("SettingsAccountSection")
    }

    private var syncStatusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sync Status")
                Text("Cloud sync is not configured yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Local only")
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("SettingsSyncStatusRow")
    }
}

private struct DeleteAccountPlaceholderView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.red)

                    Text("Account deletion is not available yet.")
                        .font(.headline)
                        .accessibilityIdentifier("SettingsDeleteAccountPlaceholder")

                    Text("This release still stores your workouts locally. Account deletion will be available before release after cloud data deletion is connected.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 4: Insert the Account section into Settings**

In `LiftingLog/Features/Profile/SettingsView.swift`, update the `Form` content to place the new section between `Rest Timer` and `Data`:

```swift
        Form {
            Section("Units") {
                Picker("Weight Unit", selection: weightUnitBinding) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("WeightUnitPicker")
            }

            Section("Rest Timer") {
                Stepper(value: restTimerBinding, in: 30...300, step: 15) {
                    Text("\(settings.defaultRestTimerSeconds) seconds")
                }
            }

            SettingsAccountSection()

            Section("Data") {
                Button(action: exportWorkoutHistory) {
                    Label("Export Workout History", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("ExportWorkoutHistoryButton")
            }
        }
```

- [ ] **Step 5: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `LiftingLog.xcodeproj/project.pbxproj` includes `SettingsAccountSection.swift`.

- [ ] **Step 6: Run the focused UI test and verify it passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /private/tmp/codex-ios-app-derived-data -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsShowsAccountShellAndDeleteAccountPlaceholder
```

Expected: PASS.

- [ ] **Step 7: Run the existing Settings/Profile UI tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /private/tmp/codex-ios-app-derived-data -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsWeightUnitConversionRoundsDisplayedWorkoutValues -only-testing:LiftingLogUITests/LiftingLogUITests/testSignedOutProfileShowsOptionalAuthAndWorkoutStillWorks
```

Expected: PASS.

- [ ] **Step 8: Run the app unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /private/tmp/codex-ios-app-derived-data -only-testing:LiftingLogTests
```

Expected: PASS.

- [ ] **Step 9: Self-review the diff**

Run:

```bash
git diff -- LiftingLog/Features/Profile/SettingsAccountSection.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLogUITests/LiftingLogUITests.swift LiftingLog.xcodeproj/project.pbxproj
```

Confirm:

- Settings has `Sync Status` and `Delete Account`.
- Settings does not duplicate `ProfileAccountCard`.
- The new Swift file does not import Clerk or Convex.
- There is no local, Clerk, Convex, or cloud deletion behavior.
- The delete-account destination has no destructive confirmation button.

- [ ] **Step 10: Commit**

Run:

```bash
git add LiftingLog/Features/Profile/SettingsAccountSection.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLogUITests/LiftingLogUITests.swift LiftingLog.xcodeproj/project.pbxproj
git commit -m "Add settings account shell"
```

Expected: Commit succeeds with only the implementation files staged.
