# Codex brief: E2E simulator verification of PR #112 (issue #93 account deletion)

You are doing MANUAL E2E VERIFICATION of the account-deletion flow on the iOS simulator for the LiftingLog app (repo is checked out on branch codex/issue-93-account-deletion-marker, PR #112). Your job is to execute two scenarios end-to-end against the REAL dev Convex deployment and write a detailed report to docs/superpowers/plans/issue-93-e2e-report.md.

Rules: NEVER commit or push anything; NEVER touch a production Convex deployment (verify you are using the dev deployment from .env/.env.local/convex config before deploying); NEVER run the full LiftingLogUITests suite (it is known to hang — this is a hard rule); temporary local code edits for failure injection are allowed but MUST be reverted at the end (finish with `git status` clean except docs/superpowers/plans/). Take simulator screenshots at key checkpoints and reference them in the report.

## Setup

1. Run `npx convex dev --once` (or the project's deploy-to-dev command) to push this branch's functions/schema/cron to the dev deployment; note in the report whether the hourly cron "clear expired account deletion markers" registers and the new indexes build.
2. Build the app for an iPhone simulator (find the scheme via `xcodebuild -list`; there may be notes in CLAUDE.md or docs/ about manual pbxproj registration and seed data).
3. FIRST investigate how auth works (Clerk — check for email/password vs Sign in with Apple, and any debug/test auth hooks or launch arguments used by UI tests). IF sign-in cannot be automated (e.g. SIWA-only requiring an Apple ID in Settings), STOP EARLY and write the report explaining exactly what manual step a human must do first — do not burn an hour fighting it.

## Scenario 2 first (cancel restores data)

Sign in, create a workout with an exercise and a couple of sets, wait for sync, and record baseline row counts in dev Convex (use `npx convex data <table>` or `npx convex run`). Then temporarily inject a failure so the CLERK ACCOUNT DELETION step throws (find the AccountDeleting conformer used by AccountDeletionCoordinator — e.g. make its delete() throw) while everything else works. Rebuild, tap Delete Account in Settings.

Expected: cloud data wiped, Clerk step fails, coordinator calls cancelAccountDeletion and recoverAfterFailedAccountDeletion; the app shows the failure message BUT sync re-pushes all local data. Verify in Convex: the accountDeletionMarkers row is GONE and the workout/exercise/set rows are RESTORED (compare counts). Record pass/fail with evidence.

## Scenario 1 (issue #93 core regression — lost token retry)

With the Clerk failure injection still in place, ALSO inject a failure in the coordinator's cancelAccountDeletion call (make the sync client's cancel throw, or block it). Tap Delete Account again (re-create a workout first if needed).

Expected: cloud wiped, Clerk fails, cancel fails, app shows terminal failure, and dev Convex retains an accountDeletionMarkers row with phaseRaw "cloudDataDeleted".

Now simulate reinstall: uninstall the app from the simulator (this wipes the UserDefaults cancellation token). REVERT ALL injections, rebuild clean, reinstall, sign in as the SAME account. Tap Delete Account.

Expected: deletion resumes the post-wipe marker with a fresh token, completes, and the Clerk account is deleted. Verify the marker row's final state in Convex. Finally, sign in with a DIFFERENT/fresh account, create a workout, and verify it syncs (rows appear in Convex for the new owner). Record pass/fail with evidence.

## Cleanup

Revert injections, confirm `git status` is clean (except docs/superpowers/plans/), and leave the dev deployment as-is. The report must include: what was executed, pass/fail per scenario with the Convex row evidence, any deviations from expected behavior (treat ANY deviation as a finding, do not rationalize it away), and anything you could not test and why.
