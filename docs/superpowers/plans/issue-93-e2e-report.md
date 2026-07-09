# Issue #93 E2E Verification Report

Date: 2026-07-06 17:52 CDT
Branch: `codex/issue-93-account-deletion-marker`
PR: #112
Target deployment: dev Convex `dev:glad-cow-603`
Simulator: iPhone 17 `366709E7-17FB-4C56-81BE-4DF67A9D090F`

## Summary

Result:

- Scenario 2: PASS.
- Scenario 1 through retained post-wipe marker: PASS.
- Scenario 1 reinstall/lost-token chokepoint block: PASS, based on the human-provided same-account reinstall state plus local/Convex evidence below.
- Scenario 1 app-driven retry completion: BLOCKER / NOT VERIFIED. The clean reinstalled app did not complete deletion from this sandbox because the required coordinate automation command (`axe`) is sandbox-blocked, and the previous human coordinate taps did not reach the confirmation flow. Evidence points to a UI navigation/tap-position issue rather than Convex rejecting the retained `cloudDataDeleted` marker, but the app-level retry did not complete, so this is not a pass.

Remaining action needed next:

1. On the already reinstalled clean app, navigate Profile -> Settings -> Delete Account.
2. Confirm the app shows `DeleteDataConfirmationView`; this is a pushed navigation screen, not a system alert.
3. Type `DELETE`, tap the destructive confirm button, and verify Clerk sign-out plus final Convex marker state.
4. If the app again jumps to Start without showing the confirmation screen, treat that as a UI/navigation bug separate from the Convex marker chokepoint.

No production Convex deployment was touched. The full `LiftingLogUITests` suite was not run.

## Setup Evidence

The signed-in Clerk session was provided externally by the user. I verified it in app-owned UI:

- Profile title: `e2e-issue93+clerk_test@example.com`
- Profile subtitle: `Signed in`
- Screenshot: `/var/folders/0b/qtw7v97n21v4h2hvyp7yrb2m0000gn/T/screenshot_optimized_7004530d-774f-4c2a-aa14-ef22a225b348.jpg`

Dev Convex was already targeted by `.env.local`; I also ran `npx convex dev --once` earlier in the E2E attempts against:

- Deployment: `kevin-tatooles:lifting-log-ios:dev/kevin-tatooles`
- URL: `https://glad-cow-603.convex.cloud`

## Scenario 2: Cancel Restores Data

Result: PASS.

### Workout Created

Created a workout in the signed-in app:

- Workout title: `Issue93 S2 1721`
- Exercise: `Bench Press`
- Sets:
  - 135 lb x 8
  - 145 lb x 6
- Saved workout UI showed `1 exercises` and `2 sets`.
- Screenshot after rebuild/relaunch with saved workout visible: `/var/folders/0b/qtw7v97n21v4h2hvyp7yrb2m0000gn/T/screenshot_optimized_fc103181-7946-4e27-9721-a07e146da8aa.jpg`

### Baseline Convex Rows

The synced workout identified this owner:

`https://glad-krill-22.clerk.accounts.dev|user_3G9HIjGpybMbLGU32oTbO9okqab`

Baseline owner counts:

```json
{
  "accountDeletionMarkers": 0,
  "exercises": 20,
  "loggedExercises": 1,
  "loggedSets": 2,
  "userSettings": 1,
  "workoutSessions": 1
}
```

Baseline graph:

```json
{
  "session": {
    "_id": "jn762c7ytyp0s9krvaqfg2v4x58a1sy3",
    "clientId": "57c51e27-b271-45e4-8806-093a691d7149",
    "deletedAt": null,
    "title": "Issue93 S2 1721"
  },
  "loggedExercise": {
    "_id": "j97espnfdkns0r0vbc2zknq8yx8a1ddh",
    "clientId": "4dc1f42e-971c-44c1-bb44-82021a1cf8ec",
    "deletedAt": null,
    "exerciseSnapshotName": "Bench Press"
  },
  "loggedSets": [
    {
      "_id": "jd70g25c42ekj4tt7rs962m0dd8a1t5e",
      "clientId": "542a457d-412f-43e2-be4d-d33fdb5e38c9",
      "weight": 135,
      "reps": 8,
      "isCompleted": true,
      "deletedAt": null
    },
    {
      "_id": "jd71pzx30vkz3gpwpm0y99y5h58a06cn",
      "clientId": "baf127b2-2d67-4ab4-a92b-6dbe4378052f",
      "weight": 145,
      "reps": 6,
      "isCompleted": true,
      "deletedAt": null
    }
  ]
}
```

### Failure Injection

Temporary edit applied to `ClerkAccountDeleter.deleteCurrentAccount()`:

- Injected an unconditional throw before `clerk.user.delete()`.
- Rebuilt/reinstalled with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.
- Build succeeded with the expected unreachable-code warning.
- Verified the app remained signed in after reinstall:
  - `e2e-issue93+clerk_test@example.com`
  - `Signed in`

### Delete Result

Tapped Delete Account in Settings, typed `DELETE`, and confirmed deletion.

Observed app result:

- Error text: `Account deletion could not finish. Your local data is still saved on this iPhone.`
- Screenshot: `/var/folders/0b/qtw7v97n21v4h2hvyp7yrb2m0000gn/T/screenshot_optimized_02fc7390-1837-4d0f-8df4-175837316f3a.jpg`

Post-delete Convex evidence:

```json
{
  "counts": {
    "accountDeletionMarkers": 0,
    "exercises": 20,
    "loggedExercises": 1,
    "loggedSets": 2,
    "userSettings": 1,
    "workoutSessions": 1
  },
  "session": {
    "_id": "jn724epfxqcw8hgkwdjpm6r9v98a14ar",
    "clientId": "57c51e27-b271-45e4-8806-093a691d7149",
    "deletedAt": null,
    "title": "Issue93 S2 1721"
  },
  "loggedExercise": {
    "_id": "j97dpy52mj6rq9awmkw1s4pdgs8a07rd",
    "clientId": "4dc1f42e-971c-44c1-bb44-82021a1cf8ec",
    "deletedAt": null,
    "exerciseSnapshotName": "Bench Press"
  },
  "loggedSets": [
    {
      "_id": "jd7d9s0q1p6xgak78n6kyestk98a10rc",
      "clientId": "542a457d-412f-43e2-be4d-d33fdb5e38c9",
      "weight": 135,
      "reps": 8,
      "isCompleted": true,
      "deletedAt": null
    },
    {
      "_id": "jd71gzmys99tsxx7njr5wb398h8a1zr9",
      "clientId": "baf127b2-2d67-4ab4-a92b-6dbe4378052f",
      "weight": 145,
      "reps": 6,
      "isCompleted": true,
      "deletedAt": null
    }
  ],
  "markers": []
}
```

Scenario 2 pass rationale:

- Cloud rows were deleted then restored/re-pushed.
- `accountDeletionMarkers` ended at 0 for this owner.
- The workout graph was present after the failed Clerk step.
- The app showed the expected failure message while retaining local data.

## Scenario 1: Lost Token Retry, Pre-Reinstall Portion

Result through retained post-wipe marker: PASS.

### Failure Injection

Kept the Clerk deletion failure injection and added a second temporary edit in `ConvexSyncClient.cancelAccountDeletion(cancellationToken:)`:

- Injected an unconditional throw before `sync:cancelAccountDeletion`.
- Rebuilt/reinstalled with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.
- Build succeeded with the expected unreachable-code warning.
- Verified signed-in state after reinstall:
  - `e2e-issue93+clerk_test@example.com`
  - `Signed in`

### Delete Result

Tapped Delete Account again, typed `DELETE`, and confirmed deletion.

Observed app result:

- Error text: `Account deletion could not finish. Your local data is still saved on this iPhone.`
- Screenshot: `/var/folders/0b/qtw7v97n21v4h2hvyp7yrb2m0000gn/T/screenshot_optimized_1bfd0e2f-2c8c-4138-b4b3-c88c85b21291.jpg`

Post-delete Convex evidence:

```json
{
  "counts": {
    "accountDeletionMarkers": 1,
    "exercises": 0,
    "loggedExercises": 0,
    "loggedSets": 0,
    "userSettings": 0,
    "workoutSessions": 0
  },
  "markers": [
    {
      "_id": "js7fer9d1rehmvqt7qdtadvp0x8a0xwr",
      "cancellationToken": "76d97035-5fd1-4e8d-a081-7bb5a2f5ad53",
      "cloudDataDeletedAt": 1783377124933,
      "createdAt": 1783377124933,
      "phaseRaw": "cloudDataDeleted"
    }
  ],
  "sessions": []
}
```

Final read after reverting injections and reinstalling clean code over the existing bundle still showed:

```json
{
  "counts": {
    "accountDeletionMarkers": 1,
    "exercises": 0,
    "loggedExercises": 0,
    "loggedSets": 0,
    "userSettings": 0,
    "workoutSessions": 0
  },
  "markers": [
    {
      "_id": "js7fer9d1rehmvqt7qdtadvp0x8a0xwr",
      "cancellationToken": "76d97035-5fd1-4e8d-a081-7bb5a2f5ad53",
      "cloudDataDeletedAt": 1783377124933,
      "createdAt": 1783377124933,
      "phaseRaw": "cloudDataDeleted"
    }
  ]
}
```

Scenario 1 pre-reinstall pass rationale:

- Cloud data was wiped.
- Cancel failed due to the injected error.
- The dev Convex deployment retained one `accountDeletionMarkers` row for this owner.
- The marker phase is exactly `cloudDataDeleted`.

## Reinstall Stop Point

The brief requested uninstalling the app to wipe the persisted UserDefaults cancellation token, then reverting injections, rebuilding clean, reinstalling, and stopping because same-account Clerk sign-in requires human input.

What happened:

- XcodeBuildMCP has no uninstall-app simulator tool exposed.
- Shell `xcrun simctl uninstall 366709E7-17FB-4C56-81BE-4DF67A9D090F com.kevintatooles.LiftingLog.dev` was attempted once and failed because shell `simctl` is sandbox-blocked:
  - `CoreSimulatorService connection became invalid`
  - `Operation not permitted`
  - `Connection refused`
  - `Failed to initialize simulator device set`
- I stopped the injected app.
- I reverted all temporary edits.
- I verified no source diff remained in:
  - `LiftingLog/Core/AccountDeletion/ClerkAccountDeleter.swift`
  - `LiftingLog/Core/Sync/ConvexSyncClient.swift`
- I rebuilt/reinstalled clean code over the existing bundle with `build_run_sim`.
- Clean rebuild succeeded with no warnings.
- I stopped the clean app.

Because uninstall could not be performed from this sandbox, I could not create the exact signed-out post-reinstall state requested by the brief. Same-account sign-in is still needed before continuing the rest of Scenario 1.

## Scenario 1: Human Reinstall Continuation

Result through chokepoint block: PASS.

The human completed the blocked uninstall/reinstall/sign-in step outside this sandbox:

- Clean build with both injections reverted.
- Same Clerk account signed in: `e2e-issue93+clerk_test@example.com`.
- Same owner token: `https://glad-krill-22.clerk.accounts.dev|user_3G9HIjGpybMbLGU32oTbO9okqab`.
- Dev Convex still had one retained marker with `phaseRaw: "cloudDataDeleted"` and zero rows in all five owner data tables.
- App Settings > Sync Status showed `1 failed, 20 waiting` plus `Cloud sync failed`.

I verified the same Convex state:

```json
{
  "counts": {
    "accountDeletionMarkers": 1,
    "exercises": 0,
    "loggedExercises": 0,
    "loggedSets": 0,
    "userSettings": 0,
    "workoutSessions": 0
  },
  "markers": [
    {
      "_id": "js7fer9d1rehmvqt7qdtadvp0x8a0xwr",
      "cancellationToken": "76d97035-5fd1-4e8d-a081-7bb5a2f5ad53",
      "cloudDataDeletedAt": 1783377124933,
      "createdAt": 1783377124933,
      "phaseRaw": "cloudDataDeleted"
    }
  ]
}
```

I also inspected the current app container directly:

- Current container: `/Users/kevintatooles/Library/Developer/CoreSimulator/Devices/366709E7-17FB-4C56-81BE-4DF67A9D090F/data/Containers/Data/Application/924BD3D0-1225-4F8F-BAC1-43B8078078BA`
- No `AccountDeletionCoordinator.persistedCancellationToken` key was found in app preferences or container grep output.
- Local SwiftData counts: `ZUSERSETTINGS=1`, `ZEXERCISE=20`, `ZWORKOUTSESSION=0`, `ZLOGGEDEXERCISE=0`, `ZLOGGEDSET=0`, `ZSYNCOUTBOXENTRY=21`, `ZSYNCCURSORSTATE=1`.
- Outbox included 20 pending exercise creates and one failed userSettings create.
- Failed outbox error:

```text
Uncaught Error: Account deletion is in progress
    at assertAccountDeletionNotStarted (../convex/sync.ts:436:51)
    at async handler (../convex/sync.ts:1200:6)
```

This confirms the important issue #93 chokepoint behavior on the reinstalled/lost-token device: ordinary sync writes are blocked while the retained post-wipe marker exists.

## Scenario 1: Retry Completion

Result: BLOCKER / NOT VERIFIED.

What I could verify:

- Current app screenshot after relaunch shows Start tab, no confirmation dialog/sheet, and a `Cloud sync failed` toast.
- Screenshot: `/var/folders/0b/qtw7v97n21v4h2hvyp7yrb2m0000gn/T/screenshot_optimized_87a21bad-4171-4297-bcba-479186dbb3f6.jpg`
- The app runtime log captured after relaunch did not contain account-deletion/coordinator events.
- Available XcodeBuildMCP logs did not contain `deleteAccount`, `deleteAccountData`, `cancelAccountDeletion`, or account-deletion failure entries from the human's previous retry taps.
- `AccountDeletionCoordinator.phase` is not persisted; it is a `@StateObject` inside `DeleteDataConfirmationView`, and a fresh confirmation screen starts at `.idle`.
- `PrivacyDataSection` uses a `NavigationLink` to `DeleteDataConfirmationView`; there is no `confirmationDialog` or system alert for Delete Account.
- The destructive action only runs from `DeleteDataConfirmationView` after `confirmationText == "DELETE"` and tapping `DeleteDataConfirmButton`.

Tooling blocker:

- The requested bundled axe command could not access the simulator from this sandbox:

```text
CoreSimulatorService connection became invalid
Operation not permitted
Connection refused
Error: Failed to initialize simulator device set.
```

- This happened with `axe describe-ui --udid 366709E7-17FB-4C56-81BE-4DF67A9D090F`, both before and after an MCP relaunch.
- Shell `simctl` screenshot/uninstall access is also blocked here with the same CoreSimulatorService family of errors.
- I did not use MCP element-ref UI automation because the task explicitly requested the bundled `axe` CLI instead.

Backend diagnostic:

I ran a narrowly scoped Convex diagnostic with the same owner identity and a fresh cancellation token:

```json
{
  "deletedCounts": {
    "exercises": 0,
    "loggedExercises": 0,
    "loggedSets": 0,
    "userSettings": 0,
    "workoutSessions": 0
  },
  "status": "deleted"
}
```

The marker remained unchanged afterward:

```json
{
  "counts": {
    "accountDeletionMarkers": 1,
    "exercises": 0,
    "loggedExercises": 0,
    "loggedSets": 0,
    "userSettings": 0,
    "workoutSessions": 0
  },
  "markers": [
    {
      "_id": "js7fer9d1rehmvqt7qdtadvp0x8a0xwr",
      "cancellationToken": "76d97035-5fd1-4e8d-a081-7bb5a2f5ad53",
      "cloudDataDeletedAt": 1783377124933,
      "createdAt": 1783377124933,
      "phaseRaw": "cloudDataDeleted"
    }
  ]
}
```

This diagnostic does not count as app E2E completion because it did not invoke the iOS coordinator, delete the Clerk account, clear local data, or verify sign-out. It does show that Convex is not rejecting `sync:deleteAccountData` for the retained `cloudDataDeleted` marker.

Verdict:

- The retry-completion path remains a BLOCKER / NOT VERIFIED at the app E2E level.
- I do not have evidence of an issue #93 backend regression: the marker blocks normal writes, and the delete action accepts the retained marker.
- I also do not have evidence that `AccountDeletionCoordinator.phase.isRunning` caused a no-op; the phase is view-local and no deletion logs appeared.
- The most likely explanation for the prior "tap Delete Account -> Start tab" observation is a UI navigation/tap-position problem: Delete Account is not a system confirmation alert, and a tap near the bottom of the screen can hit the tab bar rather than the Settings row.
- Until the confirmation screen is reached and `DELETE` is submitted in the clean app, Scenario 1 final retry completion must stay blocked rather than passing.

## Cleanup

- Both failure injections were reverted.
- Clean app build/reinstall over the existing bundle succeeded.
- App process was stopped with `stop_app_sim()`.
- During the continuation, the clean app was relaunched once with XcodeBuildMCP to capture logs.
- No production Convex deployment was touched.
- Full `LiftingLogUITests` suite was not run.
- Final intended worktree state: clean except files under `docs/superpowers/plans/`.

---

## FINAL RESULT — retry completion verified (driven manually via axe CLI)

Date: 2026-07-06, completed by the human's Claude driving the simulator directly
with the bundled `axe` coordinate-tap CLI (codex was sandbox-blocked from axe;
axe works when run outside the codex sandbox).

Root cause of the earlier "Delete Account tap does nothing" observation: the
Delete Account button in Settings sits at y=769–837, underneath the tab bar
(y=791+), and x≈201 is the Start-tab center — every tap was hitting the Start
tab. Scrolling the Settings form up first, then tapping the button, correctly
pushes `DeleteDataConfirmationView` (type-"DELETE"-to-confirm sheet).

Retry flow executed on the reinstalled / lost-token device (same e2e account,
owner `...|user_3G9HIjGpybMbLGU32oTbO9okqab`, clean build, no injections):

1. Confirmed pre-state: marker `phaseRaw=cloudDataDeleted` retained, Sync Status
   "1 failed, 20 waiting" — writes correctly BLOCKED on the reinstalled device.
2. Settings → Delete Account → typed `DELETE` → Delete Account button enabled →
   tapped it.
3. OBSERVED: confirmation sheet dismissed and the app transitioned to the
   SIGNED-OUT Profile ("Local lifting log / Sign in to keep your workouts
   backed up"). Because the sheet only dismisses on `coordinator.phase ==
   .completed` (which requires the Clerk account-deletion step to succeed),
   sign-out is direct proof the full deletion completed.
4. Backend after: owner has 0 rows across all 5 tables; marker retained as
   `cloudDataDeleted` (the designed terminal state — Clerk account is gone so
   owner-scoped cancel can't run; the 30-day purge cron removes it later).

Verdict: **Retry completion = PASS.** The issue #93 core regression
(reinstall + lost token → retry deletion completes; account no longer bricked)
is verified end-to-end against real Convex + real Clerk.

Not separately driven: "fresh different account syncs" — covered by the unit
test "account deletion marker does not block other owners" and unchanged by this
PR (markers are owner-scoped; a new account has no marker). Left as
verified-by-unit-test rather than a second full Clerk signup cycle.

Overall E2E verdict: Scenario 2 PASS, Scenario 1 (pre-reinstall + retry
completion) PASS, chokepoint block on reinstall PASS. No deviations found.
