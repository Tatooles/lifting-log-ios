# Baros Authentication Domain Migration Runbook

Status: Planned. Do not change the production Clerk domain until the server and client migrations described here are implemented and tested.

This is the operator source of truth for moving production authentication from the Lifting Log Clerk domain to the Baros domain without losing beta tester data.

## Decision

- Use a coordinated hard cutover, not a permanent old/new issuer compatibility layer.
- Preserve existing Clerk users and all local and Convex workout data.
- Keep the Apple bundle identifiers and existing persistence key names unchanged.
- Keep `issuer|subject` as the ownership key for this release. Do not re-key ownership on bare Clerk `subject` immediately before App Store submission; consider that broader identity refactor after launch.

The current production issuer is:

```text
https://clerk.auth.liftinglog.app
```

The new issuer must be copied exactly from the new production Clerk publishable key and a token minted after the domain change. Do not assume its hostname in advance.

## Why A Migration Is Required

Convex and the iOS app currently identify an owner as the JWT issuer and subject joined by `|`:

```text
https://clerk.auth.liftinglog.app|user_123
```

Changing the Clerk production domain changes the issuer portion while the user's Clerk subject remains the same. Without a rewrite, the records still exist but the new build queries under a different owner key and they appear missing.

The migration replaces only the exact old issuer prefix. It must preserve the separator and subject byte-for-byte.

## Cutover Behavior

No tester-by-tester coordination or compatibility window is required. During the cutover:

- The Clerk domain flip automatically prevents old builds from minting or refreshing old-domain tokens. Testers do not need to coordinate a manual sync shutdown.
- Once production Convex accepts only the new issuer, old builds cannot authenticate to Convex and are local-only.
- Work recorded in an old build during that window remains in its local SwiftData store and sync outbox.
- The new build rewrites those local owner values before its first sync, then uploads the preserved outbox entries normally.
- Old and new builds do not need to sync simultaneously. The strict ordering constraint is: **finish and verify the server owner migration before any tester installs the new build**.

Fable's automatic cutoff is the expected behavior for minting new tokens. This runbook intentionally adds the Convex issuer deployment as the definitive write gate because an installation may still hold a previously minted token until it expires. That safeguard does not require tester coordination or an old/new compatibility layer.

## Affected Ownership State

The production Convex migration must cover all six owner-scoped tables:

- `accountDeletionMarkers`
- `userSettings`
- `exercises`
- `workoutSessions`
- `loggedExercises`
- `loggedSets`

The iOS migration must cover all local state that contains or is keyed by an owner token identifier, including:

- `UserSettings.syncOwnerTokenIdentifier`
- `Exercise.syncOwnerTokenIdentifier`
- `WorkoutSession.syncOwnerTokenIdentifier`
- `SyncOutboxEntry.ownerTokenIdentifier`, without discarding pending operations
- `SyncCursorState.ownerTokenIdentifier`
- `LastKnownSyncOwnerTokenStore`
- owner-scoped account-deletion cancellation-token storage

Logged exercises and sets inherit local ownership through their workout session, so their relationships must remain intact rather than being recreated.

## Required Implementation Before The Cutover

Codex prepares both migrations and their tests before Kevin changes anything in Clerk.

### Server migration

Create a private, batched, resumable Convex migration plus verification queries that:

1. Accept or embed the exact old and new issuer values.
2. Reject empty values, equal issuers, and malformed owner identifiers.
3. Rewrite only rows whose owner starts with the exact old issuer plus `|`.
4. Leave already-migrated rows unchanged so reruns are idempotent.
5. Stop and report a conflict if both old-issuer and new-issuer records would occupy the same logical owner/client key.
6. Report per-owner and per-table before, migrated, already-migrated, skipped, and conflict counts.
7. Support a production dry run before any writes.

Use the existing `convex/sync.test.ts` owner fixtures to cover the server rewrite, authorization boundary, idempotency, conflicts, and verification counts.

### Client migration

Add a one-time, atomic local migration that runs after a new Clerk identity is available but before owner activation or the first sync. It must:

1. Confirm that the old and new owner identifiers have the same Clerk subject.
2. Rewrite only state owned by that subject under the exact old issuer.
3. Rewrite active outbox entries and return failed or in-flight entries to pending without deleting them.
4. Recreate or reset the new owner's sync cursors so the first new-build sync performs a full reconciliation against the migrated server rows.
5. Rewrite the last-known owner and any owner-scoped account-deletion key.
6. Save the local changes as one transaction and be safe to run again.
7. Refuse to guess when multiple local subjects are present or the active subject does not match.

Add focused unit tests for every owner-bearing local model, preserved outbox operations, cursor reset, unrelated-owner isolation, idempotency, and rollback on failure.

## Production Runbook

### 1. Prepare And Rehearse

Owner: Codex

- [ ] Implement both migrations and all focused tests.
- [ ] Run the complete Convex test suite and typecheck.
- [ ] Run the affected iOS unit tests and the complete iOS unit target.
- [ ] Rehearse the entire sequence against development data using two test users.
- [ ] Build the Release configuration containing the client migration, but do not upload it to TestFlight yet.
- [ ] Confirm the old TestFlight build, the migration build, and the current production backend versions are recorded.

Stop if the client migration cannot preserve pending outbox entries or if the server migration is not idempotent.

### 2. Capture The Pre-Flip Baseline

Owners: Kevin and Codex

- [ ] Pause account deletion operations for the cutover window.
- [ ] Export or otherwise capture a restorable production Convex backup.
- [ ] Record `authSmoke:me` for at least one existing tester, including `issuer`, `subject`, and `tokenIdentifier`.
- [ ] Capture per-owner record counts for every affected Convex table.
- [ ] Confirm there are no unexpected owners and no pre-existing rows under the proposed new issuer.
- [ ] On the physical test phone, create one completed workout plus one deliberately un-synced local change for the post-update check.

Stop if the backup is unavailable, counts cannot be reconciled, or an account-deletion marker is actively progressing.

### 3. Flip Clerk To The Baros Domain

Owner: Kevin, with Codex verifying values

- [ ] Change the production primary domain in Clerk.
- [ ] Add the exact DNS records Clerk provides and wait for Clerk to confirm the domain and certificate.
- [ ] Copy the new production publishable key and decode or inspect its exact frontend host.
- [ ] Mint a token and confirm its `iss` value. Record that exact value as the new issuer.
- [ ] Confirm the test user's Clerk `sub` is unchanged from the pre-flip baseline.
- [ ] Update Sign in with Apple, social-login redirect URLs, native application settings, and associated-domain configuration as required by Clerk.
- [ ] Treat old builds as unable to mint or refresh production tokens from this point; no tester action is required to stop new authenticated sessions.

Stop if the test user's subject changed. The automatic prefix rewrite is safe only when the same Clerk users are retained.

### 4. Close Old-Build Sync

Owner: Codex

- [ ] Set production `CLERK_JWT_ISSUER_DOMAIN` to the exact new issuer.
- [ ] Update the Release publishable key and associated-domain value in `project.yml`.
- [ ] Deploy Convex auth configuration that accepts only the new issuer.
- [ ] Confirm an old-issuer token is rejected by production Convex.
- [ ] Confirm a new-issuer token can call `authSmoke:me` and returns the expected unchanged subject.

At this point, old builds are intentionally local-only. Their unsynced local changes remain available for the client migration.

### 5. Migrate And Verify Production Owners

Owner: Codex

- [ ] Deploy the production migration and verification functions.
- [ ] Run the migration in dry-run mode and compare its proposed counts with the pre-flip baseline.
- [ ] Stop if any malformed identifier, unexpected owner, or logical-key conflict is reported.
- [ ] Run the production migration and monitor every batch to completion.
- [ ] Verify every old-issuer row was migrated and no old-issuer rows remain.
- [ ] Verify per-owner record counts match the pre-flip baseline in all six tables.
- [ ] Verify account-deletion marker counts and phases separately.
- [ ] Save the migration output and verification evidence with the release record.

Do not upload the new TestFlight build until every server verification passes.

### 6. Ship The Client Migration

Owners: Codex uploads; Kevin releases to testers

- [ ] Regenerate the Xcode project if configuration changed.
- [ ] Archive and upload the Release build containing the client migration.
- [ ] Confirm the archive contains the new Clerk publishable key and associated domain.
- [ ] Release the build to the beta group only after server migration verification is complete.
- [ ] Tell testers the old build is temporarily local-only and that they should update before expecting sync to resume. Do not tell them to delete the app.

### 7. Validate On An Existing Installation

Owners: Kevin and Codex

- [ ] Update the physical test phone over the existing TestFlight installation; do not reinstall.
- [ ] Reauthenticate if Clerk requires it.
- [ ] Confirm the pre-flip workout remains visible.
- [ ] Confirm the deliberately un-synced local change uploads after the update.
- [ ] Confirm Sync Status reaches Up to date.
- [ ] Compare the test owner's post-sync server counts with the pre-flip baseline plus the deliberate local change.
- [ ] Complete and sync a new workout.
- [ ] Sign out, sign back in, and confirm all workouts remain visible.
- [ ] Cold-launch once online and once offline.
- [ ] Verify account deletion can start and be cancelled or completed using the correctly migrated owner scope.
- [ ] Confirm a newly created account syncs normally under the new issuer.

Stop the rollout if any existing data appears missing, duplicates are created, another owner's data is visible, or an outbox entry is discarded.

### 8. Close The Migration

Owner: Codex

- [ ] Confirm all active testers have moved to the new build or understand that old builds are local-only.
- [ ] Update the README and App Store submission pack with the final Baros Clerk values.
- [ ] Remove production migration entry points after the evidence and rollback window are complete.
- [ ] Keep the local migration idempotent for upgrades from any remaining old beta installation.
- [ ] Record the final production issuer, TestFlight build, Convex deployment, counts, and QA evidence.

## Rollback Boundaries

- Before the server owner migration runs, restore the old Clerk/Convex configuration and investigate. No data rewrite needs reversing.
- After the server owner migration but before TestFlight release, either fix forward or run a tested reverse migration from the new issuer back to the old issuer. Restore the backup only if count verification cannot establish a safe reverse migration.
- After testers install the new build, pause distribution and fix forward. Do not alternate issuers repeatedly or rerun migrations without first reconciling current per-owner counts.

Never delete beta data as part of rollback unless Kevin explicitly chooses a beta reset after the backup and impact are reviewed.

## Completion Criteria

The migration is complete only when:

- Production accepts only the new Baros Clerk issuer.
- No production row remains under the old issuer.
- Every pre-flip per-owner/table count is reconciled.
- Existing installations preserve synced and previously un-synced workouts.
- Sign-in, sync, offline launch, and account deletion pass on a physical TestFlight installation.
- The final production values are reflected in repository documentation and release configuration.
