# Account Deletion and Privacy Controls Design

## Context

GitHub issue 13 covers Phase 6 of `docs/initial-release-roadmap.md`: complete the account lifecycle and App Store privacy requirements for a v1 app with account creation.

The app is currently developed against development Clerk and development Convex. Implementation should stay in development environments, while keeping the code environment-neutral so the same flow works against production once the app is configured for release. Production verification with disposable test accounts belongs to the later App Store submission and release-candidate phases.

The current Settings screen has account sync status, a placeholder Delete Account row, and a Data section with workout export. ClerkKit already supports deleting the current user with `User.delete()`. Convex currently stores only sync data keyed by `ownerTokenIdentifier`, with no separate user profile table.

## Goals

- Replace the delete-account placeholder with a real signed-in account deletion flow.
- Delete the authenticated user's Convex sync data before deleting the Clerk account.
- Delete local SwiftData records on the device after cloud account deletion succeeds.
- Provide a signed-out local data deletion path for local-only privacy cleanup.
- Show exactly one destructive deletion action in Settings based on sign-in state.
- Add Privacy Policy and Support rows through configuration that issue 14 can finalize with live URLs.
- Keep the deletion flow retryable and conservative if any step fails.

## Non-Goals

- Do not implement production Clerk or Convex configuration in this issue.
- Do not create final privacy policy or support pages; issue 14 owns live URLs and App Store metadata.
- Do not introduce a server-side Clerk secret or Convex-owned Clerk deletion unless the ClerkKit current-user deletion API proves unusable.
- Do not delete remote data for signed-out local-only users, because there is no authenticated cloud account to authorize.

## Recommended Approach

Use an app-orchestrated deletion flow:

1. The iOS app calls a new authenticated Convex deletion mutation through `SyncClient`.
2. The app calls ClerkKit `user.delete()` for the current user.
3. The app clears local SwiftData and reseeds local defaults.

This matches the existing architecture because Convex already authorizes user-scoped sync data from `ctx.auth.getUserIdentity()` and ClerkKit already exposes current-user deletion through the frontend session.

## Alternatives Considered

### Backend-Owned Deletion

Convex could call Clerk's Backend API and delete both Convex and Clerk data from the server. This centralizes the workflow but requires storing Clerk secrets, adding a new backend integration, and expanding operational risk for v1. It is more complexity than the current product needs.

### Clerk UI Only

The app could rely on ClerkKitUI's built-in delete account screen. That would delete the Clerk account, but it would not delete Convex sync data or local SwiftData. This would leave issue 13 incomplete.

## Settings UI

Create a single Settings section named `Privacy & Data`.

The section should include export and privacy/support access, plus exactly one deletion action:

- Signed in: show `Delete Account`.
- Signed out: show `Delete Local Data`.

Do not show both destructive actions at the same time. Signed-out users do not have an account to delete, so the UI should avoid presenting account deletion as available.

`Export Workout History` should remain near these controls because export is the recovery path before destructive deletion.

Privacy Policy and Support rows should be backed by a small config surface with optional URLs. In issue 13, if a URL is not configured, the row should remain visible but disabled with secondary copy such as `Available before release`. Issue 14 must replace those missing URLs with live production URLs before App Store submission.

## Delete Account Flow

The signed-in delete account screen should:

- State that deletion permanently removes the cloud account, cloud workout data, and local data on this iPhone.
- Require the user to type `DELETE` before enabling the destructive button.
- Disable navigation and buttons while deletion is in progress.
- Show progress states for cloud data deletion, account deletion, and local cleanup.
- Return the app to a fresh signed-out local state after success.
- Keep the user on the screen with a retry path after failure.

The operation order is:

1. Resolve the current Clerk user and `syncScheduler.currentOwnerTokenIdentifier`.
2. Pause or suppress sync scheduling during deletion.
3. Call `SyncClient.deleteAccountData()`.
4. Call `clerk.user.delete()`.
5. Clear local SwiftData and reseed local defaults.
6. Reset sync scheduler state, including current owner, last sync, last failure, and pending request state.

The app should not wipe local data until both Convex deletion and Clerk deletion have succeeded.

## Delete Local Data Flow

The signed-out delete local data screen should:

- State that it deletes only local data on this device.
- State that it does not delete a cloud account or cloud data.
- Require typing `DELETE` before enabling the destructive button.
- Clear local SwiftData, reseed defaults, and stay in local mode.
- Show a retryable error if local cleanup fails.

This path skips Convex and Clerk entirely.

## Convex Design

Add an authenticated Convex mutation for account data deletion. The mutation must derive the owner from `ctx.auth.getUserIdentity()` and use `identity.tokenIdentifier` through the existing auth helper pattern. It must never accept a user id or owner token from the client for authorization.

The mutation should delete all sync rows for the authenticated owner from:

- `loggedSets`
- `loggedExercises`
- `workoutSessions`
- `exercises`
- `userSettings`

Deletion should be idempotent. Running it again after partial success should succeed and leave no rows for that owner.

If one mutation cannot safely delete all rows within Convex transaction limits, implement bounded batch deletion and continuation scheduling. The first implementation can be direct if bounded tests and current expected data volumes justify it, but the implementation plan should call out the transaction-limit risk explicitly.

The mutation must not delete another user's rows.

## iOS Design

Add a focused account deletion coordinator or service. It should be testable without SwiftUI and should depend on protocols for:

- Convex account data deletion through `SyncClient`.
- Clerk user deletion through a small current-user deletion adapter.
- Local persistence reset.
- Sync scheduler state reset or deletion-mode control.

The coordinator should expose enough state for SwiftUI to render:

- idle
- deleting cloud data
- deleting account
- clearing local data
- completed
- failed with user-visible message

Local persistence cleanup should be a separate service rather than inline view code because it touches every SwiftData model and should be reusable by both account deletion and local-only deletion.

## Error Handling

Error handling should be conservative:

- If Convex deletion fails, stop before Clerk deletion. Keep local data and let the user retry.
- If Clerk deletion fails after Convex deletion succeeds, keep local data and let the user retry. Convex deletion must be safe to call again.
- If local reset fails after both cloud steps succeed, show recovery copy and provide a local cleanup retry. Do not report full completion until local cleanup succeeds.
- If signed-out local deletion fails, keep existing local data and show a retryable error.

User-facing errors should avoid backend details such as Convex function names, tokens, or Clerk identifiers.

## Tests

Convex tests should cover:

- The deletion mutation rejects unauthenticated callers.
- The deletion mutation deletes only the authenticated owner's rows across all sync tables.
- The deletion mutation leaves other owners' rows intact.
- The deletion mutation is idempotent when called repeatedly.

iOS unit tests should cover:

- The account deletion coordinator stops before Clerk deletion if Convex deletion fails.
- The coordinator does not wipe local data unless Convex and Clerk deletion both succeed.
- The coordinator can retry after Convex data was already deleted.
- Local reset clears user data and sync metadata, then reseeds local defaults.
- Sync scheduler state is reset after successful account deletion.

UI tests should cover:

- Signed-in Settings shows `Delete Account` and not `Delete Local Data`.
- Signed-out Settings shows `Delete Local Data` and not `Delete Account`.
- Confirmation requires typing `DELETE`.
- The old placeholder copy is gone.
- Privacy Policy and Support rows are present through the configured issue 13 surface.

Manual QA should cover:

- Development Clerk plus development Convex account deletion with a disposable account.
- Retry after simulated Convex failure.
- Retry after simulated Clerk failure.
- Signed-out local data deletion.
- Export remains available before destructive deletion.

## Issue 14 Dependency

Issue 14 owns final App Store submission materials. Before submission, it must replace any issue 13 placeholder URLs with live Privacy Policy and Support URLs, confirm App Privacy details for Clerk and Convex, and verify the production backend with a disposable production test account.
