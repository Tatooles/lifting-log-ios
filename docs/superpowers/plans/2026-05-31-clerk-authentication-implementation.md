# Clerk Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional Clerk authentication to Profile using Clerk's prebuilt iOS views while preserving signed-out local workout logging.

**Architecture:** Keep Clerk at the app boundary and Profile account surface. `LiftingLogApp` configures Clerk through a small local configuration type, `ProfileView` renders a focused account card, and workout/history/settings flows remain independent from authentication state. Automated tests cover local display logic and signed-out UI behavior; live Clerk sign-in is verified manually on a physical device.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, ClerkKit, ClerkKitUI, XcodeGen, XCTest, XCUITest, XcodeBuildMCP.

---

## File Structure

- Create `LiftingLog/Core/Auth/ClerkConfiguration.swift`
  - Owns the current Clerk publishable key and associated-domain host constants.
  - Provides a single switch point for later `pk_live_...` production configuration.
- Create `LiftingLog/Features/Profile/AccountDisplayState.swift`
  - Pure display model for signed-out and signed-in account copy.
  - Keeps string fallbacks testable without importing Clerk into unit tests.
- Create `LiftingLog/Features/Profile/ProfileAccountCard.swift`
  - SwiftUI account card that reads `@Environment(Clerk.self)`, presents `AuthView`, and shows `UserButton`.
  - Keeps Clerk UI imports out of `ProfileView`.
- Modify `LiftingLog/App/LiftingLogApp.swift`
  - Replace the hardcoded publishable key with `ClerkConfiguration.publishableKey`.
- Modify `LiftingLog/Features/Profile/ProfileView.swift`
  - Replace the hardcoded "Kevin" profile block with `ProfileAccountCard`.
- Modify `LiftingLogUITests/LiftingLogUITests.swift`
  - Add a signed-out auth smoke test that verifies Profile shows optional auth and local workout logging still works.
- Create `LiftingLogTests/ClerkConfigurationTests.swift`
  - Unit tests for publishable-key and associated-domain formatting.
- Create `LiftingLogTests/AccountDisplayStateTests.swift`
  - Unit tests for signed-out and signed-in account display fallback behavior.
- Modify generated project files with `xcodegen generate`
  - Picks up the new app and test source files from `project.yml` source directories.

---

### Task 1: Clerk Configuration Boundary

**Files:**
- Create: `LiftingLog/Core/Auth/ClerkConfiguration.swift`
- Create: `LiftingLogTests/ClerkConfigurationTests.swift`
- Modify: `LiftingLog/App/LiftingLogApp.swift`
- Regenerate: `LiftingLog.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing configuration tests**

Create `LiftingLogTests/ClerkConfigurationTests.swift`:

```swift
import XCTest
@testable import LiftingLog

final class ClerkConfigurationTests: XCTestCase {
    func testDevelopmentPublishableKeyUsesTestPrefix() {
        XCTAssertTrue(ClerkConfiguration.publishableKey.hasPrefix("pk_test_"))
    }

    func testAssociatedDomainUsesWebCredentialsWithoutScheme() {
        XCTAssertEqual(
            ClerkConfiguration.associatedDomain,
            "webcredentials:glad-krill-22.clerk.accounts.dev"
        )
        XCTAssertFalse(ClerkConfiguration.associatedDomain.contains("https://"))
    }
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests/ClerkConfigurationTests
```

Expected: FAIL because `ClerkConfiguration` is not defined.

- [ ] **Step 3: Add the configuration type**

Create `LiftingLog/Core/Auth/ClerkConfiguration.swift`:

```swift
enum ClerkConfiguration {
    static let publishableKey = "pk_test_Z2xhZC1rcmlsbC0yMi5jbGVyay5hY2NvdW50cy5kZXYk"
    static let associatedDomain = "webcredentials:glad-krill-22.clerk.accounts.dev"
}
```

- [ ] **Step 4: Replace the hardcoded app configuration**

Modify `LiftingLog/App/LiftingLogApp.swift` so the initializer uses the configuration type:

```swift
init() {
    Clerk.configure(publishableKey: ClerkConfiguration.publishableKey)

    do {
        let arguments = ProcessInfo.processInfo.arguments
        let useInMemoryStore = arguments.contains("--uitest-in-memory-store")
        if arguments.contains("--uitest-reset-persistent-store") {
            try ModelContainerFactory.resetPersistentStoreFiles()
        }
        let container = try ModelContainerFactory.makeModelContainer(isStoredInMemoryOnly: useInMemoryStore)
        try SeedDataService.seedIfNeeded(context: container.mainContext)
        modelContainer = container
    } catch {
        fatalError("Unable to initialize Lifting Log persistence: \(error)")
    }
}
```

- [ ] **Step 5: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `LiftingLog.xcodeproj/project.pbxproj` includes `ClerkConfiguration.swift` and `ClerkConfigurationTests.swift`.

- [ ] **Step 6: Run the focused test to verify it passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests/ClerkConfigurationTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add LiftingLog/Core/Auth/ClerkConfiguration.swift LiftingLog/App/LiftingLogApp.swift LiftingLogTests/ClerkConfigurationTests.swift LiftingLog.xcodeproj/project.pbxproj
git commit -m "Add Clerk configuration boundary"
```

---

### Task 2: Account Display State

**Files:**
- Create: `LiftingLog/Features/Profile/AccountDisplayState.swift`
- Create: `LiftingLogTests/AccountDisplayStateTests.swift`
- Regenerate: `LiftingLog.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write the failing display-state tests**

Create `LiftingLogTests/AccountDisplayStateTests.swift`:

```swift
import XCTest
@testable import LiftingLog

final class AccountDisplayStateTests: XCTestCase {
    func testSignedOutStateUsesLocalModeCopy() {
        let state = AccountDisplayState.signedOut

        XCTAssertEqual(state.title, "Local lifting log")
        XCTAssertEqual(state.subtitle, "Sign in to back up and sync your workouts later.")
        XCTAssertEqual(state.actionTitle, "Sign in")
        XCTAssertFalse(state.isSignedIn)
    }

    func testSignedInStatePrefersFullNameOverEmail() {
        let state = AccountDisplayState.signedIn(fullName: "Kevin Tatooles", email: "kevin@example.com")

        XCTAssertEqual(state.title, "Kevin Tatooles")
        XCTAssertEqual(state.subtitle, "kevin@example.com")
        XCTAssertEqual(state.actionTitle, "Manage account")
        XCTAssertTrue(state.isSignedIn)
    }

    func testSignedInStateFallsBackToEmail() {
        let state = AccountDisplayState.signedIn(fullName: "  ", email: "kevin@example.com")

        XCTAssertEqual(state.title, "kevin@example.com")
        XCTAssertEqual(state.subtitle, "Signed in")
        XCTAssertEqual(state.actionTitle, "Manage account")
        XCTAssertTrue(state.isSignedIn)
    }

    func testSignedInStateFallsBackToGenericAccountName() {
        let state = AccountDisplayState.signedIn(fullName: nil, email: nil)

        XCTAssertEqual(state.title, "Signed in")
        XCTAssertEqual(state.subtitle, "Account connected")
        XCTAssertEqual(state.actionTitle, "Manage account")
        XCTAssertTrue(state.isSignedIn)
    }
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests/AccountDisplayStateTests
```

Expected: FAIL because `AccountDisplayState` is not defined.

- [ ] **Step 3: Add the display state**

Create `LiftingLog/Features/Profile/AccountDisplayState.swift`:

```swift
struct AccountDisplayState: Equatable {
    let title: String
    let subtitle: String
    let actionTitle: String
    let isSignedIn: Bool

    static let signedOut = AccountDisplayState(
        title: "Local lifting log",
        subtitle: "Sign in to back up and sync your workouts later.",
        actionTitle: "Sign in",
        isSignedIn: false
    )

    static func signedIn(fullName: String?, email: String?) -> AccountDisplayState {
        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trimmedName.isEmpty {
            return AccountDisplayState(
                title: trimmedName,
                subtitle: trimmedEmail.isEmpty ? "Signed in" : trimmedEmail,
                actionTitle: "Manage account",
                isSignedIn: true
            )
        }

        if !trimmedEmail.isEmpty {
            return AccountDisplayState(
                title: trimmedEmail,
                subtitle: "Signed in",
                actionTitle: "Manage account",
                isSignedIn: true
            )
        }

        return AccountDisplayState(
            title: "Signed in",
            subtitle: "Account connected",
            actionTitle: "Manage account",
            isSignedIn: true
        )
    }
}
```

- [ ] **Step 4: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `LiftingLog.xcodeproj/project.pbxproj` includes `AccountDisplayState.swift` and `AccountDisplayStateTests.swift`.

- [ ] **Step 5: Run the focused test to verify it passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests/AccountDisplayStateTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Features/Profile/AccountDisplayState.swift LiftingLogTests/AccountDisplayStateTests.swift LiftingLog.xcodeproj/project.pbxproj
git commit -m "Add account display state"
```

---

### Task 3: Profile Account Card

**Files:**
- Create: `LiftingLog/Features/Profile/ProfileAccountCard.swift`
- Regenerate: `LiftingLog.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the account card view**

Create `LiftingLog/Features/Profile/ProfileAccountCard.swift`:

```swift
import ClerkKit
import ClerkKitUI
import SwiftUI

struct ProfileAccountCard: View {
    @Environment(Clerk.self) private var clerk
    @State private var authIsPresented = false

    private var displayState: AccountDisplayState {
        guard let user = clerk.user else {
            return .signedOut
        }

        return .signedIn(
            fullName: Self.fullName(firstName: user.firstName, lastName: user.lastName),
            email: user.primaryEmailAddress?.emailAddress
        )
    }

    var body: some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: 14) {
                accountIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayState.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityIdentifier("ProfileAccountTitle")

                    Text(displayState.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ProfileAccountSubtitle")
                }

                Spacer(minLength: 10)

                UserButton(signedOutContent: {
                    Button {
                        authIsPresented = true
                    } label: {
                        Text(displayState.actionTitle)
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppTheme.accentGradient)
                            .foregroundStyle(AppTheme.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ProfileSignInButton")
                })
                .frame(minWidth: 36, minHeight: 36)
                .accessibilityIdentifier("ProfileUserButton")
            }
        }
        .prefetchClerkImages()
        .sheet(isPresented: $authIsPresented) {
            AuthView()
                .presentationDragIndicator(.visible)
        }
    }

    private var accountIcon: some View {
        Image(systemName: displayState.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle.badge.plus")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(displayState.isSignedIn ? AppTheme.accentBright : AppTheme.textSecondary)
            .frame(width: 42, height: 42)
            .background(AppTheme.surfaceMuted)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private static func fullName(firstName: String?, lastName: String?) -> String? {
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return name.isEmpty ? nil : name
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `LiftingLog.xcodeproj/project.pbxproj` includes `ProfileAccountCard.swift`.

- [ ] **Step 3: Build to catch Clerk UI API mistakes**

Run:

```bash
xcodebuild build -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: PASS. If this fails on `UserButton` generic inference, replace `UserButton(signedOutContent: { ... })` with `UserButton<Never, Button<Text>, EmptyView>(signedOutContent: { ... })` and rebuild.

- [ ] **Step 4: Commit**

```bash
git add LiftingLog/Features/Profile/ProfileAccountCard.swift LiftingLog.xcodeproj/project.pbxproj
git commit -m "Add Profile account card"
```

---

### Task 4: Integrate Account Card In Profile

**Files:**
- Modify: `LiftingLog/Features/Profile/ProfileView.swift`
- Modify: `LiftingLogUITests/LiftingLogUITests.swift`

- [ ] **Step 1: Add the signed-out Profile UI test**

Add this test method to `LiftingLogUITests/LiftingLogUITests.swift` near the other Profile tests:

```swift
@MainActor
func testSignedOutProfileShowsOptionalAuthAndWorkoutStillWorks() {
    let app = makeApp()
    app.launch()

    app.buttons["ProfileTab"].tap()
    XCTAssertTrue(app.staticTexts["ProfileTitle"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["ProfileAccountTitle"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["ProfileAccountTitle"].label, "Local lifting log")
    XCTAssertTrue(app.staticTexts["ProfileAccountSubtitle"].label.contains("back up and sync"))
    XCTAssertTrue(app.buttons["ProfileSignInButton"].exists)

    app.buttons["WorkoutTab"].tap()
    XCTAssertTrue(app.buttons["StartBlankWorkoutButton"].waitForExistence(timeout: 3))
    app.buttons["StartBlankWorkoutButton"].tap()
    XCTAssertTrue(app.textFields["WorkoutTitle"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Run the focused UI test to verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogUITests/LiftingLogUITests/testSignedOutProfileShowsOptionalAuthAndWorkoutStillWorks
```

Expected: FAIL because `ProfileAccountTitle`, `ProfileAccountSubtitle`, and `ProfileSignInButton` do not exist in `ProfileView` yet.

- [ ] **Step 3: Replace the hardcoded Profile identity block**

In `LiftingLog/Features/Profile/ProfileView.swift`, replace this block:

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("Kevin")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
    Text("Offline lifting log")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)
}
```

with:

```swift
ProfileAccountCard()
```

- [ ] **Step 4: Run the focused UI test to verify it passes**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogUITests/LiftingLogUITests/testSignedOutProfileShowsOptionalAuthAndWorkoutStillWorks
```

Expected: PASS.

- [ ] **Step 5: Run the Profile-adjacent existing UI tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogUITests/LiftingLogUITests/testTabNavigationAndFinishSheetSmoke -only-testing:LiftingLogUITests/LiftingLogUITests/testSettingsWeightUnitConversionRoundsDisplayedWorkoutValues -only-testing:LiftingLogUITests/LiftingLogUITests/testExerciseLibraryCreateEditAndRemoveCustomExercise
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add LiftingLog/Features/Profile/ProfileView.swift LiftingLogUITests/LiftingLogUITests.swift
git commit -m "Add optional auth entry to Profile"
```

---

### Task 5: Verification And Manual Auth Pass

**Files:**
- No source files expected unless verification finds a concrete issue.

- [ ] **Step 1: Run unit tests for new local logic**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests/ClerkConfigurationTests -only-testing:LiftingLogTests/AccountDisplayStateTests
```

Expected: PASS.

- [ ] **Step 2: Run full unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogTests
```

Expected: PASS.

- [ ] **Step 3: Run full UI tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:LiftingLogUITests
```

Expected: PASS.

- [ ] **Step 4: Build and launch on the connected iPhone**

Use XcodeBuildMCP:

```text
session_show_defaults
list_devices
session_set_defaults with deviceId for Kevin's iPhone 17
build_run_device(platform: iOS)
```

Expected: app installs and launches on device.

- [ ] **Step 5: Manually verify signed-out local behavior**

On device:

```text
1. Launch the app with no Clerk session.
2. Open Profile.
3. Confirm the account card reads "Local lifting log".
4. Confirm the sign-in action is visible.
5. Return to Workout.
6. Start a blank workout.
7. Add Bench Press.
8. Enter a set.
9. Finish the workout.
10. Confirm the workout appears in History.
```

Expected: local workout logging works without signing in.

- [ ] **Step 6: Manually verify Clerk auth sheet**

On device:

```text
1. Open Profile.
2. Tap Sign in.
3. Confirm Clerk AuthView appears.
4. Dismiss the sheet.
5. Confirm Profile returns to local mode.
6. Tap Sign in again.
7. Sign in or sign up with email/password in the Clerk development instance.
8. Confirm the sheet dismisses after successful auth.
9. Confirm Profile shows signed-in account state.
10. Tap the UserButton.
11. Confirm Clerk account/profile controls open.
12. Sign out.
13. Confirm Profile returns to local mode and History still shows local workouts.
```

Expected: Clerk prebuilt auth works, sign-out does not delete local data, and session state updates Profile.

- [ ] **Step 7: Manually verify session restoration**

On device:

```text
1. Sign in with email/password.
2. Force quit the app.
3. Relaunch the app.
4. Open Profile.
```

Expected: Profile shows signed-in account state without another sign-in.

- [ ] **Step 8: Commit verification fixes or finish cleanly**

If source changes were made during verification:

```bash
git add LiftingLog LiftingLogTests LiftingLogUITests LiftingLog.xcodeproj project.yml
git commit -m "Stabilize Clerk auth integration"
```

If no source changes were made during verification:

```bash
git status --short
```

Expected: no uncommitted changes except user-owned work that predates implementation.

