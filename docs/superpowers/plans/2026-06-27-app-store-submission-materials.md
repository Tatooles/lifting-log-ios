# App Store Submission Materials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the issue 14 App Store submission package: a static support/privacy site, in-app release URL wiring, App Store submission documentation, and release-readiness verification.

**Architecture:** Keep App Store-critical web pages in a small static `SupportSite/` folder that can deploy as an independent Vercel project rooted at that folder. Keep iOS changes narrow by adding a release link configuration and pointing Settings at it. Keep operator-facing App Store material in `docs/release/app-store-submission-pack.md` so App Store Connect answers stay versioned with the app behavior.

**Tech Stack:** Plain HTML/CSS, Swift/SwiftUI, XCTest, XcodeGen/Xcode project, Vercel static hosting.

---

## File Structure

- Create `SupportSite/index.html`: public support page for `https://support.liftinglog.app/`.
- Create `SupportSite/privacy/index.html`: public privacy policy for `https://support.liftinglog.app/privacy`.
- Create `SupportSite/styles.css`: shared static styling for both support pages.
- Create `SupportSite/vercel.json`: static deployment configuration with clean URLs.
- Modify `LiftingLog/Core/Privacy/PrivacySupportConfiguration.swift`: add the release URL configuration while preserving the issue 13 placeholder configuration for tests.
- Modify `LiftingLog/Features/Profile/SettingsView.swift`: use the release link configuration in Settings.
- Modify `LiftingLogTests/PrivacySupportConfigurationTests.swift`: cover release URLs and retained placeholder behavior.
- Create `docs/release/app-store-submission-pack.md`: operator-facing App Store Connect copy, App Privacy worksheet, review notes, screenshot plan, and verification checklist.

## Task 1: Static Support Site

**Files:**
- Create: `SupportSite/index.html`
- Create: `SupportSite/privacy/index.html`
- Create: `SupportSite/styles.css`
- Create: `SupportSite/vercel.json`

- [ ] **Step 1: Verify the support site does not exist yet**

Run:

```bash
test -f SupportSite/index.html
```

Expected: command exits non-zero because the file does not exist yet.

- [ ] **Step 2: Create `SupportSite/styles.css`**

Create `SupportSite/styles.css` with:

```css
:root {
  color-scheme: light dark;
  --background: #f8f6f2;
  --surface: #ffffff;
  --text: #20252b;
  --muted: #5c6670;
  --line: #dde2e8;
  --accent: #256d85;
  --accent-soft: #e1f1f5;
}

@media (prefers-color-scheme: dark) {
  :root {
    --background: #101418;
    --surface: #181f25;
    --text: #f3f7fa;
    --muted: #aeb8c2;
    --line: #2d3640;
    --accent: #7ec8d8;
    --accent-soft: #17313a;
  }
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.6;
  color: var(--text);
  background: var(--background);
}

main {
  width: min(860px, calc(100% - 32px));
  margin: 0 auto;
  padding: 32px 0 56px;
}

header,
section {
  margin-bottom: 18px;
  padding: 24px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--surface);
}

h1,
h2 {
  margin: 0;
  line-height: 1.15;
}

h1 {
  font-size: clamp(2rem, 7vw, 3.4rem);
}

h2 {
  margin-bottom: 10px;
  font-size: 1.35rem;
}

p {
  margin: 0;
  color: var(--muted);
}

p + p,
ul + p,
p + ul {
  margin-top: 12px;
}

ul {
  margin: 0;
  padding-left: 1.2rem;
  color: var(--muted);
}

li + li {
  margin-top: 8px;
}

a {
  color: var(--accent);
  font-weight: 700;
}

.eyebrow {
  margin-bottom: 14px;
  color: var(--accent);
  font-size: 0.8rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.lede {
  max-width: 650px;
  margin-top: 16px;
  font-size: 1.08rem;
}

.callout {
  border-color: color-mix(in srgb, var(--accent) 45%, var(--line));
  background: color-mix(in srgb, var(--accent-soft) 55%, var(--surface));
}

.footer {
  padding: 8px 0 0;
  color: var(--muted);
  font-size: 0.92rem;
}
```

- [ ] **Step 3: Create `SupportSite/index.html`**

Create `SupportSite/index.html` with:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Lifting Log Support</title>
  <meta name="description" content="Support information for Lifting Log, a private workout logging app for iPhone.">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <main>
    <header>
      <p class="eyebrow">Lifting Log Support</p>
      <h1>Support for Lifting Log</h1>
      <p class="lede">Lifting Log is a native iPhone workout logger for recording exercises, sets, workout history, and optional account-backed sync.</p>
    </header>

    <section>
      <h2>Contact</h2>
      <p>For support, email <a href="mailto:support@liftinglog.app">support@liftinglog.app</a>.</p>
      <p>Include the device model, iOS version, what you were trying to do, and whether you were signed in when the issue happened.</p>
    </section>

    <section>
      <h2>Sign-in and Sync</h2>
      <ul>
        <li>You can log workouts locally without signing in.</li>
        <li>Signing in enables account-backed sync through Lifting Log's production backend.</li>
        <li>If sync appears stuck, check your network connection, reopen the app, and confirm you are still signed in.</li>
      </ul>
    </section>

    <section>
      <h2>Export and Local Data</h2>
      <p>Workout history export is available from Settings. Export before deleting data if you want a personal copy of your workout history.</p>
    </section>

    <section>
      <h2>Account Deletion</h2>
      <p>Signed-in users can delete their account in the app from Settings under Privacy &amp; Data. Signed-out users can delete local data from the same area.</p>
    </section>

    <section class="callout">
      <h2>Privacy Policy</h2>
      <p>Read the <a href="/privacy/">Lifting Log Privacy Policy</a> for details about local data, account data, sync, export, and deletion.</p>
    </section>

    <p class="footer">Lifting Log support page. Last updated June 27, 2026.</p>
  </main>
</body>
</html>
```

- [ ] **Step 4: Create `SupportSite/privacy/index.html`**

Create `SupportSite/privacy/index.html` with:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Lifting Log Privacy Policy</title>
  <meta name="description" content="Privacy Policy for Lifting Log.">
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <main>
    <header>
      <p class="eyebrow">Privacy Policy</p>
      <h1>Lifting Log Privacy Policy</h1>
      <p class="lede">Effective date: June 27, 2026. This policy explains how Lifting Log handles workout data, account data, sync, export, and deletion.</p>
    </header>

    <section>
      <h2>Data You Save in the App</h2>
      <p>Lifting Log stores workout-related data such as exercises, sets, workout sessions, notes, settings, and workout history. You can use the app locally on your iPhone without creating an account.</p>
    </section>

    <section>
      <h2>Accounts and Authentication</h2>
      <p>If you create an account, Lifting Log uses Clerk for authentication. Clerk may process account information such as your email address, authentication identifiers, session information, and Sign in with Apple details.</p>
      <p>If you use Sign in with Apple and choose Hide My Email, Apple may provide a private relay email address instead of your personal email address.</p>
    </section>

    <section>
      <h2>Cloud Sync</h2>
      <p>When you sign in, Lifting Log uses Convex to sync supported workout, exercise, settings, and history data for your account. Sync data is scoped to your authenticated account.</p>
    </section>

    <section>
      <h2>Export and Deletion</h2>
      <ul>
        <li>You can export workout history from Settings.</li>
        <li>Signed-in users can delete their account and account-backed data from Settings under Privacy &amp; Data.</li>
        <li>Signed-out users can delete local data stored on the device from Settings under Privacy &amp; Data.</li>
      </ul>
    </section>

    <section>
      <h2>Analytics, Advertising, and Tracking</h2>
      <p>Lifting Log does not use third-party advertising, cross-app tracking, or product analytics in the v1 release. Standard platform and provider diagnostics may be processed by Apple, Clerk, Convex, or hosting providers to keep their services reliable and secure.</p>
    </section>

    <section>
      <h2>Support</h2>
      <p>For privacy questions or support, email <a href="mailto:support@liftinglog.app">support@liftinglog.app</a>.</p>
    </section>

    <p class="footer"><a href="/">Back to support</a></p>
  </main>
</body>
</html>
```

- [ ] **Step 5: Create `SupportSite/vercel.json`**

Create `SupportSite/vercel.json` with:

```json
{
  "cleanUrls": true,
  "trailingSlash": false
}
```

- [ ] **Step 6: Verify the static site files exist and contain required release language**

Run:

```bash
test -f SupportSite/index.html
test -f SupportSite/privacy/index.html
test -f SupportSite/styles.css
test -f SupportSite/vercel.json
rg -n "support@liftinglog.app|Privacy Policy|Account Deletion|Clerk|Convex|does not use third-party advertising" SupportSite
```

Expected: all `test` commands pass and `rg` prints matches from the support and privacy pages.

- [ ] **Step 7: Commit Task 1**

Run:

```bash
git add SupportSite
git commit -m "Add static support site"
```

Expected: commit succeeds with only `SupportSite` files staged.

## Task 2: In-App Release URL Wiring

**Files:**
- Modify: `LiftingLog/Core/Privacy/PrivacySupportConfiguration.swift`
- Modify: `LiftingLog/Features/Profile/SettingsView.swift`
- Modify: `LiftingLogTests/PrivacySupportConfigurationTests.swift`

- [ ] **Step 1: Write failing release URL tests**

Replace `LiftingLogTests/PrivacySupportConfigurationTests.swift` with:

```swift
import XCTest
@testable import LiftingLog

final class PrivacySupportConfigurationTests: XCTestCase {
    func testReleaseLinksUseSupportSubdomain() throws {
        let configuration = PrivacySupportConfiguration.release

        let privacyPolicyURL = try XCTUnwrap(configuration.privacyPolicyURL)
        let supportURL = try XCTUnwrap(configuration.supportURL)

        XCTAssertEqual(privacyPolicyURL.scheme, "https")
        XCTAssertEqual(privacyPolicyURL.host, "support.liftinglog.app")
        XCTAssertEqual(privacyPolicyURL.path, "/privacy")
        XCTAssertEqual(privacyPolicyURL.absoluteString, "https://support.liftinglog.app/privacy")

        XCTAssertEqual(supportURL.scheme, "https")
        XCTAssertEqual(supportURL.host, "support.liftinglog.app")
        XCTAssertEqual(supportURL.path, "")
        XCTAssertEqual(supportURL.absoluteString, "https://support.liftinglog.app/")
    }

    func testUnavailableLinksRemainAvailableForPlaceholderStates() {
        let configuration = PrivacySupportConfiguration.issue13Development

        XCTAssertNil(configuration.privacyPolicyURL)
        XCTAssertNil(configuration.supportURL)
        XCTAssertEqual(configuration.unavailableDetailText, "Available before release")
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:LiftingLogTests/PrivacySupportConfigurationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: FAIL because `PrivacySupportConfiguration.release` does not exist yet.

- [ ] **Step 3: Add the release configuration**

Replace `LiftingLog/Core/Privacy/PrivacySupportConfiguration.swift` with:

```swift
import Foundation

struct PrivacySupportConfiguration: Equatable {
    let privacyPolicyURL: URL?
    let supportURL: URL?
    let unavailableDetailText: String

    static let release = PrivacySupportConfiguration(
        privacyPolicyURL: URL(string: "https://support.liftinglog.app/privacy"),
        supportURL: URL(string: "https://support.liftinglog.app/"),
        unavailableDetailText: "Available before release"
    )

    static let issue13Development = PrivacySupportConfiguration(
        privacyPolicyURL: nil,
        supportURL: nil,
        unavailableDetailText: "Available before release"
    )
}
```

- [ ] **Step 4: Wire Settings to the release links**

In `LiftingLog/Features/Profile/SettingsView.swift`, change the `PrivacyDataSection` call from:

```swift
PrivacyDataSection(
    exportWorkoutHistory: exportWorkoutHistory,
    links: .issue13Development,
    onDeletionCompleted: onDataDeletionCompleted
)
```

to:

```swift
PrivacyDataSection(
    exportWorkoutHistory: exportWorkoutHistory,
    links: .release,
    onDeletionCompleted: onDataDeletionCompleted
)
```

- [ ] **Step 5: Run the focused tests and verify they pass**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:LiftingLogTests/PrivacySupportConfigurationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS for `PrivacySupportConfigurationTests`.

- [ ] **Step 6: Run the existing UI test that covers privacy/support row presence**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:LiftingLogUITests/LiftingLogUITests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS or a documented pre-existing UI-runner issue. Do not treat a partial timeout as full coverage.

- [ ] **Step 7: Commit Task 2**

Run:

```bash
git add LiftingLog/Core/Privacy/PrivacySupportConfiguration.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLogTests/PrivacySupportConfigurationTests.swift
git commit -m "Wire release privacy and support links"
```

Expected: commit succeeds with only the URL wiring and tests staged.

## Task 3: App Store Submission Pack

**Files:**
- Create: `docs/release/app-store-submission-pack.md`

- [ ] **Step 1: Verify release docs folder state**

Run:

```bash
test -f docs/release/app-store-submission-pack.md
```

Expected: command exits non-zero because the submission pack does not exist yet.

- [ ] **Step 2: Create the submission pack**

Create `docs/release/app-store-submission-pack.md` with:

```markdown
# App Store Submission Pack

This document is the operator source of truth for submitting Lifting Log 1.0 to App Store Connect.

## App Metadata

- App name: Lifting Log
- Subtitle: Simple workout logging
- Primary category: Health & Fitness
- Pricing: Free
- Support URL: https://support.liftinglog.app/
- Privacy Policy URL: https://support.liftinglog.app/privacy
- Support contact: support@liftinglog.app
- Copyright: 2026 Kevin Tatooles

## Description Draft

Lifting Log is a private workout logger for iPhone. Record exercises, sets, weights, reps, notes, and completed workouts without needing an account. Sign in when you want account-backed sync across devices.

The app focuses on fast workout entry, offline-first local logging, workout history, exercise management, data export, and clear privacy controls.

## Keywords Draft

workout, lifting, gym, strength, log, tracker, fitness, exercise, sets, reps

## Age Rating Notes

Lifting Log does not include user-generated public content, commerce, gambling, medical diagnosis, or regulated medical-device functionality. It is a workout logging utility and does not provide medical advice.

## App Privacy Worksheet

### Data Not Linked to an Account

Local workout data can remain only on the user's device when the user is signed out. This includes exercises, sets, workout sessions, notes, settings, and workout history stored locally by the app.

### Data Linked to an Account

When a user signs in, Lifting Log uses Clerk for authentication and Convex for account-scoped sync. Account-linked data can include:

- Email address or Apple private relay email used for authentication.
- Authentication identifiers and session data processed by Clerk.
- Synced exercises, workout sessions, logged exercises, logged sets, and user settings stored in Convex.

### Tracking

Lifting Log does not use third-party advertising, cross-app tracking, or product analytics in the v1 release.

### Diagnostics

Apple, Clerk, Convex, Vercel, and platform providers may process standard service diagnostics needed to operate, secure, and troubleshoot their services. Lifting Log does not add a custom analytics SDK in v1.

## Review Notes Draft

Lifting Log supports signed-out local workout logging. Account creation is optional and enables account-backed sync.

Reviewers can test the app by creating an account with email/password or Sign in with Apple. A disposable reviewer account can be created in production before submission; do not commit that password to the repo.

Important review paths:

1. Open the app and start a local workout.
2. Add exercises, sets, weights, and reps.
3. Finish the workout and view it in History.
4. Open Settings and confirm Export Workout History is present.
5. Sign in and confirm sync status is visible.
6. Open Settings > Privacy & Data and confirm account deletion is available for signed-in users.
7. Open Privacy Policy and Support links from Settings.

Production services:

- Clerk production associated domain: clerk.auth.liftinglog.app
- Convex production deployment URL: https://sensible-reindeer-16.convex.cloud

## Screenshot Plan

Capture final screenshots after UI stabilizes:

- Start workout screen.
- Active workout with exercises and sets.
- Workout history.
- Exercise library.
- Profile or Settings showing sync/export/privacy controls.

## Release Checklist

- Support site is deployed at https://support.liftinglog.app/.
- Privacy policy is deployed at https://support.liftinglog.app/privacy.
- App Settings opens both URLs.
- Release bundle identifier is com.kevintatooles.LiftingLog.
- Release display name is Lifting Log.
- Release build uses production Clerk publishable key.
- Release build uses webcredentials:clerk.auth.liftinglog.app.
- Release build uses https://sensible-reindeer-16.convex.cloud.
- Final app icon ticket is complete before submission.
- App Store screenshots are final.
- Export compliance answer is ready for standard HTTPS encryption use.
- Pricing and availability are set to Free and the intended launch regions.

## Production Smoke Test

Before submitting to App Review:

1. Install a Release or TestFlight-style build.
2. Create or sign into a disposable production account.
3. Complete one workout.
4. Confirm sync reaches production Convex.
5. Sign out and sign back in.
6. Confirm the completed workout is visible.
7. Export workout history.
8. Confirm account deletion is present in Settings.

If any step fails, document the blocker in issue 14 and do not submit to App Review.
```

- [ ] **Step 3: Verify the submission pack contains required App Store sections**

Run:

```bash
rg -n "App Metadata|App Privacy Worksheet|Review Notes|Screenshot Plan|Release Checklist|Production Smoke Test|support.liftinglog.app|sensible-reindeer-16" docs/release/app-store-submission-pack.md
```

Expected: `rg` prints matches for every required section and production URL.

- [ ] **Step 4: Commit Task 3**

Run:

```bash
git add docs/release/app-store-submission-pack.md
git commit -m "Add App Store submission pack"
```

Expected: commit succeeds with only the release document staged.

## Task 4: Verification and Deployment Closeout

**Files:**
- Modify only if verification reveals an issue in files from Tasks 1-3.

- [ ] **Step 1: Run focused unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:LiftingLogTests/PrivacySupportConfigurationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 2: Run release configuration unit tests**

Run:

```bash
xcodebuild test -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:LiftingLogTests/ClerkConfigurationTests -only-testing:LiftingLogTests/ConvexConfigurationTests -derivedDataPath /private/tmp/codex-ios-app-derived-data
```

Expected: PASS.

- [ ] **Step 3: Run static content checks**

Run:

```bash
rg -n "support@liftinglog.app|Clerk|Convex|Hide My Email|Account Deletion|does not use third-party advertising" SupportSite docs/release/app-store-submission-pack.md
```

Expected: `rg` prints matches in `SupportSite` and `docs/release/app-store-submission-pack.md`.

- [ ] **Step 4: Deploy the support site to Vercel**

Use the Vercel project rooted at `SupportSite/`, attach `support.liftinglog.app`, and deploy the current branch. If using the Vercel app tool, deploy the current project only after confirming the project root is `SupportSite/`. If using Vercel dashboard, set:

```text
Project root directory: SupportSite
Framework preset: Other
Build command: none
Output directory: .
Production domain: support.liftinglog.app
```

Expected: deployment succeeds and Vercel reports `support.liftinglog.app` as assigned to this project.

- [ ] **Step 5: Verify live URLs**

Run:

```bash
curl -I https://support.liftinglog.app/
curl -I https://support.liftinglog.app/privacy
```

Expected: each command returns HTTP 200 or a redirect that resolves to HTTP 200.

- [ ] **Step 6: Verify no local work is left unstaged**

Run:

```bash
git status --short
```

Expected: no output.

- [ ] **Step 7: If verification required follow-up edits, commit them**

If Step 6 shows changed files from verification fixes, run:

```bash
git add SupportSite docs/release/app-store-submission-pack.md LiftingLog/Core/Privacy/PrivacySupportConfiguration.swift LiftingLog/Features/Profile/SettingsView.swift LiftingLogTests/PrivacySupportConfigurationTests.swift
git commit -m "Verify App Store submission materials"
```

Expected: commit succeeds only when there are actual verification fixes. If Step 6 is clean, skip this commit step.

---

## Self-Review

- Spec coverage: Tasks cover the support site, live URL wiring, App Store submission pack, production verification, placeholder audit, and the separate app-icon dependency.
- Placeholder scan: This plan intentionally avoids unfinished-work placeholders. Demo account credentials are not committed; the release notes instruct the operator to create disposable credentials in App Store Connect at submission time.
- Type consistency: `PrivacySupportConfiguration.release` is defined before use by `SettingsView`, and tests reference the same static property name.
