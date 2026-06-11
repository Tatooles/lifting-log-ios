# Sync Status and Recovery UI Manual QA

Date: 2026-06-10

Issue: #12 Add sync status, retry, and error recovery UI

## Scenarios

- Signed out:
  - Settings Account section shows `Sync Status`, `Local only`, and `Cloud sync starts after you sign in.`
  - Workout logging remains available.
  - No global sync failure banner appears.

- Signed in and healthy:
  - Settings can show `Syncing` during an active run.
  - Settings shows `Up to date` after a successful run.
  - No global sync failure banner appears.

- Signed in with pending work:
  - Settings shows `Waiting to sync`.
  - Retry is available if sync is not already active.
  - No global failure banner appears until a failure occurs.

- Failed sync:
  - Global banner says `Cloud sync failed`.
  - Banner message says `Your data is saved on this iPhone.`
  - `Retry` requests sync without blocking app interaction.
  - `Details` opens Settings.
  - Settings shows `Cloud sync could not finish. Your data is saved on this iPhone.`

- Connectivity recovery:
  - Create or finish a workout while the network is unavailable.
  - Restore connectivity.
  - Tap Retry.
  - Failed state clears after a successful sync.

## Test Hook Coverage

- `--uitest-sync-owner issuer|ui_owner --uitest-show-sync-failure` displays the failure banner.
- Tapping `GlobalSyncRetryButton` increments `UITestSyncRequestCount`.
