# Account Settings Shell Design

## Context

Issue 7, "Add account settings shell," is part of Phase 3 in `docs/initial-release-roadmap.md`. PR #35 already implemented most of the account identity surface:

- Clerk configuration and session restoration at app launch.
- Signed-out Profile account state.
- Sign-in entry point from Profile.
- Signed-in display state from Clerk user data.
- Clerk `UserButton` for account management and sign-out.
- UI coverage that signed-out local workout logging still works.

This issue should not duplicate that Profile account surface in Settings. The remaining value is to visually reserve the Settings area where future cloud sync status and account deletion controls will live.

## Goal

Add a small Settings account lifecycle shell that makes the v1 roadmap destination clear without implementing cloud sync or account deletion behavior.

## Non-Goals

- Do not add a second sign-in or manage-account card to Settings.
- Do not implement Convex sync status, retries, or backend calls.
- Do not delete local workout data.
- Do not delete Clerk accounts.
- Do not implement cloud account deletion or Convex data deletion.
- Do not add privacy policy, support, app version, HealthKit, notification, subscription, or advanced data settings in this issue.

## Recommended Approach

Use visible informational placeholders in Settings.

This gives the app a clear account lifecycle area for Phase 5 and Phase 6 work while avoiding fake functionality. Disabled rows would look unfinished, and leaving Settings unchanged would not add much beyond the already-merged Profile account card.

## User Experience

Profile remains the primary account identity surface. It shows whether the user is local-only or signed in, and it continues to provide sign-in and account management through Clerk UI.

Settings gains a new `Account` section near the existing settings sections. The section has two entries:

1. `Sync Status`
   - Read-only.
   - Shows the current release truth as `Local only`.
   - Uses supporting copy such as `Cloud sync is not configured yet.`
   - Does not expose a retry button, sync toggle, or sync settings.

2. `Delete Account`
   - Visible as an account lifecycle entry.
   - Uses destructive visual treatment appropriate to the existing SwiftUI settings style.
   - Opens an informational placeholder screen or sheet.
   - The placeholder explains that account deletion will be available before release after cloud data deletion is connected.
   - The placeholder does not perform destructive local, Clerk, or cloud work.

The existing Settings sections for units, rest timer, and workout history export remain available and understandable for signed-out users.

## Architecture

Keep the implementation local to the Profile/Settings feature area because `SettingsView` already lives under `LiftingLog/Features/Profile/`.

Expected structure:

- Add a small Settings account shell component or private Settings subview for the new `Account` section.
- Keep Clerk imports out of the new placeholder UI unless a future issue needs live auth state.
- Keep Convex and sync implementation details out of this issue.
- Use existing SwiftUI `Form` sections instead of introducing a new Settings layout system.
- Add stable accessibility identifiers for UI tests:
  - `SettingsAccountSection`, if practical for the container.
  - `SettingsSyncStatusRow`.
  - `SettingsDeleteAccountRow`.
  - `SettingsDeleteAccountPlaceholder`.

Future sync work can replace the read-only sync row with real sync state. Future account deletion work can replace the placeholder destination with a real confirmation and deletion flow.

## Error Handling

This issue introduces no network operations and no destructive mutations, so runtime error handling should stay minimal.

The delete-account placeholder should be dismissible and should not expose a confirmation button that implies deletion is available. If implemented as navigation, the standard back button is sufficient. If implemented as a sheet, provide a normal dismiss action.

## Testing

Add focused UI test coverage for the Settings shell:

- Open Profile, navigate to Settings, and verify the Account section content is visible.
- Verify `Sync Status` shows the local-only state.
- Tap `Delete Account` and verify the placeholder explanation appears.
- Verify no deletion confirmation or destructive action is available.

Unit tests are optional. Add them only if the implementation introduces a pure display-state helper for sync/delete copy.

## Manual Verification

Run the app and verify:

- Profile still shows the existing account card.
- Settings does not duplicate the Profile account card.
- Settings shows Units, Rest Timer, Account, and Data sections.
- `Sync Status` communicates local-only/no-cloud-sync behavior.
- `Delete Account` opens only informational placeholder content.
- Starting a workout remains available while signed out.

## Acceptance Criteria

- Settings includes a visible account lifecycle area for sync status and account deletion.
- The new UI is informational only.
- No sync, Convex, Clerk deletion, cloud deletion, or local data deletion behavior is introduced.
- Profile remains the only account identity/sign-in surface.
- Existing settings and export behavior continue to work.
- Focused UI coverage verifies the visible shell and delete-account placeholder.
