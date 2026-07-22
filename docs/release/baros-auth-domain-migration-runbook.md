# Baros Authentication Domain Migration Record

Status: Completed. This document is a historical record, not an operator runbook. Do not use it to repeat or reverse the migration.

The production authentication cutover moved Baros from the legacy Clerk issuer `https://clerk.auth.liftinglog.app` to `https://clerk.baros.fit` while preserving the existing iOS bundle identifiers and production Convex deployment.

## Final Production State

- Clerk issuer: `https://clerk.baros.fit`
- Clerk publishable key: `pk_live_Y2xlcmsuYmFyb3MuZml0JA`
- Release associated domain: `webcredentials:clerk.baros.fit`
- Convex deployment: `https://sensible-reindeer-16.convex.cloud`
- Release bundle identifier: `com.kevintatooles.LiftingLog`
- Debug bundle identifier: `com.kevintatooles.LiftingLog.dev`

The production owner migration completed and its results were verified. The temporary migration function was then removed from the repository and undeployed from production. No migration function or supported legacy-issuer path remains.

## Historical Migration Design

The cutover used a temporary internal Convex mutation to rewrite owner identifiers one Clerk subject and one table at a time. It covered retained data in `userSettings`, `exercises`, `workoutSessions`, `loggedExercises`, and `loggedSets`.

The migration did not move account-deletion markers. It refused to move retained data when either owner identifier had a deletion marker, when destination rows already existed for the subject and table, or when a subject/table pair reached the mutation's safety limit. Dry runs and baseline counts were used before writes, and post-migration counts were checked before the temporary function was removed.

These details are retained only to explain how the completed production rewrite was bounded and verified. The source file, tests, invocation commands, cutover checklist, and rollback commands were deliberately removed from this record so they cannot be rerun accidentally.

## Current Operational Guidance

Treat `https://clerk.baros.fit` as the only production issuer. Release configuration changes must keep the publishable key and associated domain above aligned, and production auth checks must continue to use the `convex` JWT audience.

If a future identity incident requires repair, design and review a new one-off procedure against current production state. Do not restore the legacy issuer or reconstruct the removed mutation from this historical record.
