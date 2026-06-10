# Sync Status and Recovery UI Design

Issue: [#12 Add sync status, retry, and error recovery UI](https://github.com/Tatooles/lifting-log-ios/issues/12)

Date: 2026-06-10

## Decision

Add a lightweight user-facing sync trust layer for v1. The app should communicate sync status clearly, make failed sync recoverable, and avoid blocking workout logging.

Use a failure-only global notice plus a fuller sync status surface in Settings. The global notice appears only when signed-in sync needs attention and local data may still need cloud backup. Settings replaces the current placeholder sync row with real state, last sync information, pending or failed work summary, and retry.

`SyncScheduler` should own the user-facing sync state. The outbox remains the source of sync intent and can be summarized by the UI, but views should not infer all sync state from outbox rows alone.

## Goals

- Communicate basic sync states: local only, syncing, waiting to sync, up to date, and needs attention.
- Show last successful sync time when available.
- Let users retry failed sync from the global notice and Settings.
- Keep offline workout logging non-blocking and trustworthy.
- Explain failures in user-safe language without backend jargon.
- Preserve best-effort automatic retry behavior without adding an aggressive retry loop.
- Avoid a diagnostics-heavy sync center for v1.
- Cover airplane mode, bad network, sign out/sign in, app relaunch, and offline workout completion in QA.

## Non-Goals

- No persistent app-wide sync indicator while everything is healthy.
- No admin-style diagnostics, per-entity repair UI, or raw outbox browser.
- No new sync conflict-resolution UI.
- No new cloud backup behavior for active in-progress workouts.
- No replacement of the existing sync coordinator or outbox architecture.
- No durable sync-status SwiftData table unless implementation proves the scheduler cannot represent the required states.

## Architecture

`SyncScheduler` should become the observable source for user-facing sync status. It already coordinates sync runs, knows the current owner, and serializes overlapping requests. Extend it with a small status model rather than adding a separate sync-state service.

The scheduler should expose enough state for UI:

- current signed-in owner token identifier, already present
- whether a sync run is active
- whether another sync has been queued while a run is active
- last successful sync timestamp for the current app session
- last failure timestamp and a normalized failure category or message
- a retry method that reuses `requestSync()`

The outbox remains responsible for durable local sync intent. SwiftUI views can query `SyncOutboxEntry` to summarize pending, in-flight, and failed entries for the current owner, but the outbox should not become the full display state machine. Pull failures, authentication state, local-only mode, and active syncing can exist even when there are no outbox rows.

Avoid a new persistent sync-status model for v1. On app relaunch, the scheduler can start neutral and the UI can derive durable waiting or failed work from the outbox. If there is unsynced work, the app can request sync after sign-in as it already does.

## User Experience

The app should use two surfaces.

### Global Failure Notice

Show a non-blocking notice when signed-in sync has failed and local work may still need cloud backup. The notice should not appear for healthy idle sync, normal syncing, or signed-out local-only use.

The notice should emphasize local data safety first:

- title: "Cloud sync failed" or equivalent
- message: "Your data is saved on this iPhone."
- actions: `Retry` and `Details`

`Retry` calls the existing sync request path. `Details` takes the user to the Settings sync status surface. If retry fails again, the notice may remain, but it should not stack alerts or block interaction.

This notice can be visually modest. It is an unhappy-path recovery affordance, not a frequent core workflow.

### Settings Sync Status

Replace the current Account section placeholder that says cloud sync is not configured yet. The Settings row should show real sync state:

- `Local only`: user is signed out, data remains on device.
- `Syncing`: a sync run is active.
- `Waiting to sync`: signed in with pending queued work.
- `Up to date`: last sync completed successfully, with relative last synced time when available.
- `Needs attention`: failed entries exist or the last sync run failed.

Settings should offer `Retry` when the user is signed in, sync is not already running, and there is failed or waiting work. It may also show a compact details row or expanded text with:

- pending change count
- failed change count
- last synced time
- short user-safe failure explanation when relevant

Do not expose token identifiers, Convex function names, stack traces, raw entity IDs, or low-level transport messages in the user-facing UI.

## Data Flow

The existing sync flow remains intact:

1. A local mutation records outbox intent and calls `requestSync()`.
2. `SyncScheduler` marks a run as syncing and starts `SyncCoordinator`.
3. `SyncCoordinator` prepares local state, pushes pending entries, pulls remote changes, and marks entries completed or failed.
4. If the coordinator completes successfully, `SyncScheduler` records `lastSyncedAt` and clears scheduler-level failure state.
5. If the coordinator throws or exits without completing a push pass, `SyncScheduler` records a user-facing failure state and leaves outbox entries available for retry.
6. Automatic retry remains best-effort through normal app triggers: sign-in, app relaunch, future local mutations that request sync, and queued requests that arrive while a run is active.
7. Manual retry is an immediate user-triggered request through the same path.

The design should treat "offline" carefully. Signed-out local logging is not a failure. Signed-in cloud sync problems become visible only when there is failed or waiting work that affects cloud backup confidence.

## Error Handling

`SyncCoordinator` already marks failed outbox entries with the thrown error's localized description. That can remain useful internally and in tests.

For UI, add a normalization boundary before displaying failure text. The default public message should be:

"Cloud sync could not finish. Your data is saved on this iPhone."

Settings can include a short reason when it is helpful, such as:

- "The network appears to be offline."
- "The service could not be reached."
- "Sign in again to continue syncing."

Unknown errors should use the default safe message. Raw backend details should stay out of the production UI.

Retry should be idempotent from the user's perspective. Pressing `Retry` while a run is already active should not start overlapping syncs. The scheduler can keep its current queued-request behavior.

Do not add an aggressive background retry timer for v1. If implementation adds a short delayed retry after failure, it should be conservative, coalesced, and should stop surfacing repeated failures as new interruptions.

## Components

Expected implementation units:

- `SyncScheduler` status state: observable properties for active run, queued work, last success, and last failure.
- Sync display model helper: maps scheduler state plus outbox counts into labels, icon style, message, and available actions.
- Global sync failure banner: hosted near `AppShellView`, visible only for signed-in failure states.
- Settings sync status row/detail: replaces `SettingsAccountSection.syncStatusRow`.
- Tests for scheduler state transitions and display model mapping.

Keep UI components small and specific. Do not add a broad diagnostics feature as part of this issue.

## Testing

Unit tests should cover:

- `SyncScheduler` reports syncing while work is active.
- Successful sync records a last synced timestamp and clears failure.
- A thrown coordinator error records a failed scheduler state.
- An incomplete push that leaves failed outbox work produces a needs-attention state.
- Manual retry uses the existing request path and does not create overlapping runs.
- Display mapping returns the correct state for signed out, syncing, waiting, up to date, and needs attention.
- User-facing error normalization hides backend-specific details.

UI tests should cover:

- Settings no longer says cloud sync is not configured once the real status row exists.
- A failed-sync test hook can show the global failure notice.
- Tapping `Retry` from the failure notice or Settings increments the sync request path.
- The notice does not block navigation or workout logging.

Manual QA should cover:

- Airplane mode while signed in with pending changes.
- Bad network or unreachable Convex deployment.
- Sign out and sign back in.
- App relaunch with pending or failed outbox entries.
- Completing a workout while offline.
- Retry succeeding after connectivity returns.

## Acceptance Criteria

- Users can understand whether data is local-only, syncing, waiting, up to date, or needs attention.
- A failed signed-in sync produces a non-blocking global notice with `Retry` and `Details`.
- Settings provides the full v1 sync status and retry surface.
- Workout logging remains usable while offline or while sync has failed.
- User-facing errors are clear and do not expose backend internals.
- Existing sync correctness tests continue to pass.
