# Issue #93 Account-Deletion Marker: Chokepoint Expiry + GC Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the existing `codex/issue-93-account-deletion-marker` branch so write-unblocking never depends on the background cron, partial deletions are eventually completed server-side, post-wipe markers are purged (privacy), and the review findings on that branch are fixed.

**Architecture:** Expiry of stale `started` markers is enforced lazily at the single write chokepoint (`assertAccountDeletionNotStarted`) so recovery is instant. Resuming a partial deletion never flattens destructive phases back to `started` (the invariant becomes: `started` ⇒ no destructive batch has ever run, so expired `started` markers are always safe to delete). The hourly cron shrinks to pure garbage collection: one phase-looped sweep that self-reschedules on backlog, purges aged `cloudDataDeleted` rows, and schedules a server-side `internalAction` that finishes parked partial deletions.

**Tech Stack:** Convex (mutations/actions/crons/scheduler), convex-test + vitest, TypeScript. No Swift changes — the iOS side of the branch is accepted as-is.

**Base branch:** All work happens ON TOP of `codex/issue-93-account-deletion-marker` (commit `d4ae276`). Do not start from `main`. All file paths are repo-relative. Locate code by symbol name, not line number — line numbers below are approximate.

**Verification command used throughout:** `npx vitest run convex/sync.test.ts` (run from repo root). Do NOT run iOS simulator tests or the Swift test suite; the Swift code is untouched.

---

## Background you need (read once)

The `accountDeletionMarkers` table (see `convex/schema.ts`) has one row per owner mid-deletion, with `phaseRaw`:

- `"started"` — deletion requested, no destructive batch has run yet
- `"deleting"` — destructive batches have begun (data may be partially wiped)
- `"deletionIncomplete"` — an expired partial deletion, parked
- `"cloudDataDeleted"` — cloud wipe finished; blocks writes until owner-scoped cancellation or Clerk account removal
- `undefined` (legacy) — rows created before phases existed; destructive work may or may not have run, so treat like `deleting`

`assertAccountDeletionNotStarted(ctx, owner)` in `convex/sync.ts` (~line 416) is called by every upsert/tombstone mutation (6 call sites, ~lines 1232–1298) and currently throws on ANY marker. `accountDeletionMarkerExpired(marker)` returns true when `createdAt < Date.now() - 24h`. `accountDeletionTableOrder` (~line 80) is the canonical list of the 5 synced tables; every one has a `by_ownerTokenIdentifier_and_serverUpdatedAt` index. `deleteAccountDataWithBatches(runBatch)` (~line 196) loops tables×passes and THROWS if data remains after 100 passes — so code after it only runs on a verified-empty wipe.

Key invariant this plan establishes and relies on: **`markAccountDeletionDeleting` runs inside the same mutation as the first destructive batch delete (`deleteAccountDataBatch`), so `phaseRaw === "started"` atomically guarantees zero rows were deleted.** That is what makes deleting expired `started` markers at the chokepoint safe.

---

### Task 0: Setup and baseline

**Files:** none modified.

- [ ] **Step 1: Check out the branch and confirm clean state**

```bash
git checkout codex/issue-93-account-deletion-marker
git status --short   # expect empty
```

- [ ] **Step 2: Install deps and run the baseline suite**

```bash
npm install
npx vitest run convex/sync.test.ts
```

Expected: all tests PASS. If anything fails at baseline, stop and report — do not proceed.

---

### Task 1: Chokepoint expiry in `assertAccountDeletionNotStarted`

**Files:**
- Modify: `convex/sync.ts` (function `assertAccountDeletionNotStarted`, ~line 416)
- Test: `convex/sync.test.ts` (inside `describe("account data deletion")`, near the other marker tests)

- [ ] **Step 1: Write the failing tests**

Add to `convex/sync.test.ts` (the helpers `seedAccountDeletionMarker`, `accountDeletionMarkersForOwner`, `exerciseRecord`, `userA` already exist in this describe block):

```ts
test("expired started marker no longer blocks writes and is cleared inline", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "lost-device-token", 1_000);

  await expect(
    t.withIdentity(userA).mutation(api.sync.upsertExercise, {
      record: exerciseRecord({ clientId: "post-expiry-exercise" }),
    }),
  ).resolves.toMatchObject({ status: "inserted" });

  await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toEqual([]);
});

test("expired partial-deletion marker still blocks writes", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "lost-device-token", 1_000, "deleting");

  await expect(
    t.withIdentity(userA).mutation(api.sync.upsertExercise, {
      record: exerciseRecord({ clientId: "blocked-exercise" }),
    }),
  ).rejects.toThrow("Account deletion is in progress");
});
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
npx vitest run convex/sync.test.ts -t "expired started marker no longer blocks"
```

Expected: FAIL — upsert rejects with "Account deletion is in progress" instead of inserting. (The second test passes already; that's fine, it's a regression guard.)

- [ ] **Step 3: Implement the chokepoint check**

Replace the body of `assertAccountDeletionNotStarted` in `convex/sync.ts`:

```ts
async function assertAccountDeletionNotStarted(
  ctx: MutationCtx,
  ownerTokenIdentifier: string,
): Promise<void> {
  const marker = await accountDeletionMarkerForOwner(ctx, ownerTokenIdentifier);
  if (marker === null) {
    return;
  }

  // "started" guarantees no destructive batch has run (deleteAccountDataBatch
  // advances the phase in the same mutation as the first delete), so an
  // expired started marker is inert and can be resolved right here instead of
  // waiting for the cleanup cron.
  if (marker.phaseRaw === "started" && accountDeletionMarkerExpired(marker)) {
    await ctx.db.delete(marker._id);
    return;
  }

  throw new Error("Account deletion is in progress");
}
```

Note: `accountDeletionMarkerExpired` is declared later in the file than this function — hoisted function declarations make that fine; do not reorder.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
npx vitest run convex/sync.test.ts
```

Expected: both new tests PASS; whole file still green.

- [ ] **Step 5: Commit**

```bash
git add convex/sync.ts convex/sync.test.ts
git commit -m "Resolve expired started deletion markers at the write chokepoint"
```

---

### Task 2: Takeover semantics — never flatten destructive phases; tighten cancel rules

**Files:**
- Modify: `convex/sync.ts` (functions `markAccountDeletionStarted` ~line 426 and `clearAccountDeletionMarker` ~line 496; add helper `canTakeOverAccountDeletionMarker` next to `accountDeletionMarkerExpired`)
- Test: `convex/sync.test.ts`

- [ ] **Step 1: Write the failing tests**

```ts
test("resuming an expired partial deletion keeps the destructive phase", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "lost-device-token", 1_000, "deleting");

  await t.mutation(internal.sync.startAccountDeletion, {
    ownerTokenIdentifier: userA.tokenIdentifier,
    cancellationToken: "fresh-install-token",
  });

  await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toMatchObject([
    {
      cancellationToken: "fresh-install-token",
      phaseRaw: "deleting",
    },
  ]);
});

test("cancelAccountDeletion rejects a new token for an expired partial marker", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "lost-device-token", 1_000, "deleting");

  await expect(
    t.withIdentity(userA).action(api.sync.cancelAccountDeletion, {
      cancellationToken: "fresh-install-token",
    }),
  ).rejects.toThrow("Account deletion is already in progress on another client");
});
```

- [ ] **Step 2: Run them to verify they fail**

```bash
npx vitest run convex/sync.test.ts -t "expired partial"
```

Expected: FAIL — the first shows `phaseRaw: "started"` (flattened), the second resolves `{ status: "cancelled" }` instead of throwing.

- [ ] **Step 3: Implement**

Add the shared predicate next to `accountDeletionMarkerExpired` in `convex/sync.ts`:

```ts
function canTakeOverAccountDeletionMarker(
  marker: Doc<"accountDeletionMarkers">,
  cancellationToken: string,
): boolean {
  return (
    marker.cancellationToken === cancellationToken ||
    accountDeletionMarkerExpired(marker)
  );
}
```

Replace `markAccountDeletionStarted` entirely (flattens the nesting and preserves destructive phases; legacy phase-less markers resume as `"deleting"` because destructive work may have run):

```ts
async function markAccountDeletionStarted(
  ctx: MutationCtx,
  ownerTokenIdentifier: string,
  cancellationToken: string,
): Promise<void> {
  const existing = await accountDeletionMarkerForOwner(ctx, ownerTokenIdentifier);
  if (existing === null) {
    await ctx.db.insert("accountDeletionMarkers", {
      ownerTokenIdentifier,
      cancellationToken,
      createdAt: Date.now(),
      phaseRaw: "started",
    });
    return;
  }

  if (existing.phaseRaw === "cloudDataDeleted") {
    return;
  }

  if (!canTakeOverAccountDeletionMarker(existing, cancellationToken)) {
    throw new Error("Account deletion is already in progress on another client");
  }

  await ctx.db.patch(existing._id, {
    cancellationToken,
    createdAt: Date.now(),
    phaseRaw: existing.phaseRaw === "started" ? "started" : "deleting",
  });
}
```

Replace `clearAccountDeletionMarker` (mismatched tokens may only clear post-wipe markers or expired `started` markers — per issue #93's task list; expired partial deletions must be resumed, not cancelled, because cancelling would resume sync over a half-wiped dataset):

```ts
async function clearAccountDeletionMarker(
  ctx: MutationCtx,
  ownerTokenIdentifier: string,
  cancellationToken: string,
): Promise<void> {
  const existing = await accountDeletionMarkerForOwner(ctx, ownerTokenIdentifier);
  if (existing === null) {
    return;
  }

  const ownerRecoverable =
    existing.phaseRaw === "cloudDataDeleted" ||
    (existing.phaseRaw === "started" && accountDeletionMarkerExpired(existing));

  if (existing.cancellationToken !== cancellationToken && !ownerRecoverable) {
    throw new Error("Account deletion is already in progress on another client");
  }

  await ctx.db.delete(existing._id);
}
```

- [ ] **Step 4: Run the full file**

```bash
npx vitest run convex/sync.test.ts
```

Expected: PASS. The existing tests "startAccountDeletion refreshes a resumed stale pre-wipe marker", "cancelAccountDeletion lets the authenticated owner recover with a new token", and "deleteAccountData resumes an owner marker created with a lost token" all still pass (they seed `started` markers, whose behavior is unchanged).

- [ ] **Step 5: Commit**

```bash
git add convex/sync.ts convex/sync.test.ts
git commit -m "Preserve destructive marker phases on resume and tighten cancel rules"
```

---

### Task 3: Batch safety guard, merged phase advance, token-checked completion

**Files:**
- Modify: `convex/sync.ts` — `deleteAccountDataBatch` (~line 1425), `markAccountDeletionDataDeleted` (~line 1417), `deleteAccountData` action (~line 1490); DELETE functions `markAccountDeletionDeleting` and `markAccountDeletionCloudDataDeleted` (their logic is inlined below)
- Test: `convex/sync.test.ts`

- [ ] **Step 1: Write the failing tests**

```ts
test("deleteAccountDataBatch is a no-op when no marker exists", async () => {
  const t = testDb();
  await seedFullSyncGraphForOwner(t, userA, "A");

  await expect(
    t.mutation(internal.sync.deleteAccountDataBatch, {
      ownerTokenIdentifier: userA.tokenIdentifier,
      tableName: "loggedSets",
    }),
  ).resolves.toEqual({ tableName: "loggedSets", deletedCount: 0, hasMore: false });
});

test("markAccountDeletionDataDeleted ignores a stale attempt's token", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "current-token");

  await t.mutation(internal.sync.markAccountDeletionDataDeleted, {
    ownerTokenIdentifier: userA.tokenIdentifier,
    cancellationToken: "previous-attempt-token",
  });

  await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toMatchObject([
    { phaseRaw: "started" },
  ]);
});
```

- [ ] **Step 2: Run them to verify they fail**

```bash
npx vitest run convex/sync.test.ts -t "no-op when no marker"
npx vitest run convex/sync.test.ts -t "stale attempt"
```

Expected: first FAILS with `deletedCount: 1`; second FAILS (mutation rejects — `cancellationToken` is not yet an accepted arg).

- [ ] **Step 3: Implement**

(a) Delete the standalone functions `markAccountDeletionDeleting` and `markAccountDeletionCloudDataDeleted` from `convex/sync.ts` (both currently exist near `accountDeletionMarkerExpired`; Task 5 replaces the only other caller of the cloudDataDeleted transition).

(b) In `deleteAccountDataBatch`, replace the current first line of the handler (`await markAccountDeletionDeleting(ctx, args.ownerTokenIdentifier);`) with a guard that (1) refuses to run destructive batches with no marker present — which also makes the server-side resume in Task 5 race-safe against cancellation, since Convex serializes mutations — and (2) advances the phase only when it actually changes, eliminating the up-to-500 redundant patches per deletion:

```ts
  handler: async (ctx, args): Promise<AccountDataDeletionTableBatchResult> => {
    const marker = await accountDeletionMarkerForOwner(ctx, args.ownerTokenIdentifier);
    if (marker === null) {
      return { tableName: args.tableName, deletedCount: 0, hasMore: false };
    }
    if (marker.phaseRaw !== "deleting" && marker.phaseRaw !== "cloudDataDeleted") {
      await ctx.db.patch(marker._id, { phaseRaw: "deleting" });
    }

    switch (args.tableName) {
      // ... existing switch body unchanged ...
```

(c) Replace `markAccountDeletionDataDeleted` with a token-checked version (fixes the race where a stale attempt's final mutation could mark a NEWER attempt's marker as `cloudDataDeleted` before that attempt wiped anything):

```ts
export const markAccountDeletionDataDeleted = internalMutation({
  args: {
    ownerTokenIdentifier: v.string(),
    cancellationToken: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await accountDeletionMarkerForOwner(ctx, args.ownerTokenIdentifier);
    if (
      existing === null ||
      existing.phaseRaw === "cloudDataDeleted" ||
      existing.cancellationToken !== args.cancellationToken
    ) {
      return;
    }

    await ctx.db.patch(existing._id, {
      phaseRaw: "cloudDataDeleted",
      cloudDataDeletedAt: Date.now(),
    });
  },
});
```

(d) In the `deleteAccountData` action, update the final `runMutation` call to pass the token:

```ts
    await ctx.runMutation(internal.sync.markAccountDeletionDataDeleted, {
      ownerTokenIdentifier,
      cancellationToken: args.cancellationToken,
    });
```

- [ ] **Step 4: Run the full file**

```bash
npx vitest run convex/sync.test.ts
```

Expected: PASS, including the existing "deleteAccountDataBatch marks the marker once destructive deletion begins" test (the guard still advances `started` → `deleting`).

- [ ] **Step 5: Commit**

```bash
git add convex/sync.ts convex/sync.test.ts
git commit -m "Guard destructive batches on marker presence and token-check completion"
```

---

### Task 4: Cleanups — table-list reuse, dead index

**Files:**
- Modify: `convex/sync.ts` (function `ownerHasAccountData`, ~line 514; function `accountDeletionMarkerForOwner`, ~line 402)
- Modify: `convex/schema.ts` (accountDeletionMarkers indexes, ~line 30)

No new tests — this is behavior-preserving refactoring covered by the existing suite.

- [ ] **Step 1: Replace `ownerHasAccountData` with a loop over `accountDeletionTableOrder`**

The current version hand-writes five identical queries; a future sixth synced table would silently break the "no data remains" check. Replace the whole function:

```ts
async function ownerHasAccountData(
  ctx: MutationCtx,
  ownerTokenIdentifier: string,
): Promise<boolean> {
  const results = await Promise.all(
    accountDeletionTableOrder.map((tableName) =>
      ctx.db
        .query(tableName)
        .withIndex("by_ownerTokenIdentifier_and_serverUpdatedAt", (q) =>
          q.eq("ownerTokenIdentifier", ownerTokenIdentifier),
        )
        .take(1),
    ),
  );

  return results.some((records) => records.length > 0);
}
```

If TypeScript rejects `ctx.db.query(tableName)` because `accountDeletionTableOrder`'s element type is too wide, tighten the constant's declaration to `as const satisfies readonly AccountDeletionTable[]` where it is defined (~line 80) rather than casting at the call site.

- [ ] **Step 2: Drop the unused `by_createdAt` index**

In `convex/schema.ts`, delete the line `.index("by_createdAt", ["createdAt"])` from the `accountDeletionMarkers` table. Keep `by_ownerTokenIdentifier` and `by_phaseRaw_and_createdAt`. Nothing queries `by_createdAt`; it is pure write amplification.

- [ ] **Step 3: Widen `accountDeletionMarkerForOwner` to `QueryCtx`**

Task 5 needs to read the marker from an `internalQuery`. Change only the parameter type (the function only reads; `MutationCtx` callers still typecheck because `MutationCtx` is assignable to `QueryCtx`):

```ts
async function accountDeletionMarkerForOwner(
  ctx: QueryCtx,
  ownerTokenIdentifier: string,
): Promise<Doc<"accountDeletionMarkers"> | null> {
```

`QueryCtx` is already imported at the top of `convex/sync.ts`.

- [ ] **Step 4: Run the suite**

```bash
npx vitest run convex/sync.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add convex/sync.ts convex/schema.ts
git commit -m "Reuse deletion table order, widen marker read ctx, drop dead index"
```

---### Task 5: GC rewrite — phase loop, post-wipe purge, self-reschedule, server-side resume

**Files:**
- Modify: `convex/sync.ts` — rewrite `resolveExpiredAccountDeletionMarker` (~line 570) and `clearExpiredAccountDeletionMarkers` (~line 1367); add `accountDeletionMarkerForOwnerInternal` (internalQuery) and `resumeIncompleteAccountDeletion` (internalAction); add constant `accountDeletionMarkerPurgeMs`; extend imports
- Test: `convex/sync.test.ts` (new tests + updates to four existing GC tests)
- Not modified: `convex/crons.ts` (the hourly registration stays exactly as-is; `{}` args mean production runs use the default cutoffs)

- [ ] **Step 1: Update imports and constants in `convex/sync.ts`**

Extend the `./_generated/server` import (top of file) to:

```ts
import {
  action,
  internalAction,
  internalMutation,
  internalQuery,
  mutation,
  query,
  type MutationCtx,
  type QueryCtx,
} from "./_generated/server";
```

Next to `accountDeletionMarkerExpiryMs` (~line 108), add:

```ts
const accountDeletionMarkerPurgeMs = 30 * 24 * 60 * 60 * 1000;
```

- [ ] **Step 2: Write the failing tests**

Add `vi` to the vitest import at the top of `convex/sync.test.ts` (`import { describe, expect, test, vi } from "vitest";` — adjust to whatever is currently imported). Then add:

```ts
test("clearExpiredAccountDeletionMarkers purges aged post-wipe markers", async () => {
  const t = testDb();
  await seedAccountDeletionMarker(t, userA, "old-post-wipe", 1_000, "cloudDataDeleted");
  await seedAccountDeletionMarker(t, userB, "fresh-post-wipe", 5_000, "cloudDataDeleted");

  await expect(
    t.mutation(internal.sync.clearExpiredAccountDeletionMarkers, {
      expiresBefore: 0,
      purgeBefore: 2_000,
    }),
  ).resolves.toEqual({ deletedCount: 1, hasMore: false });

  await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toEqual([]);
  await expect(accountDeletionMarkersForOwner(t, userB)).resolves.toMatchObject([
    { phaseRaw: "cloudDataDeleted" },
  ]);
});

test("expired partial deletion is parked and then finished server-side", async () => {
  vi.useFakeTimers();
  try {
    const t = testDb();
    await seedFullSyncGraphForOwner(t, userA, "A");
    await seedAccountDeletionMarker(t, userA, "partial-token", 1_000, "deleting");

    await expect(
      t.mutation(internal.sync.clearExpiredAccountDeletionMarkers, {
        expiresBefore: 1_500,
        purgeBefore: 0,
      }),
    ).resolves.toEqual({ deletedCount: 0, hasMore: false });
    await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toMatchObject([
      { phaseRaw: "deletionIncomplete", cancellationToken: "partial-token" },
    ]);

    await t.finishAllScheduledFunctions(vi.runAllTimers);

    await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toMatchObject([
      { phaseRaw: "cloudDataDeleted", cancellationToken: "partial-token" },
    ]);
    const remaining = await t.run(async (ctx) => {
      return await ctx.db
        .query("exercises")
        .withIndex("by_ownerTokenIdentifier_and_serverUpdatedAt", (q) =>
          q.eq("ownerTokenIdentifier", userA.tokenIdentifier),
        )
        .collect();
    });
    expect(remaining).toEqual([]);
  } finally {
    vi.useRealTimers();
  }
});

test("clearExpiredAccountDeletionMarkers self-reschedules through a backlog", async () => {
  vi.useFakeTimers();
  try {
    const t = testDb();
    await t.run(async (ctx) => {
      for (let i = 0; i <= 100; i++) {
        await ctx.db.insert("accountDeletionMarkers", {
          ownerTokenIdentifier: `backlog-owner-${i}`,
          cancellationToken: `backlog-token-${i}`,
          createdAt: 1_000 + i,
          phaseRaw: "started",
        });
      }
    });

    await expect(
      t.mutation(internal.sync.clearExpiredAccountDeletionMarkers, {
        expiresBefore: 3_000,
        purgeBefore: 0,
      }),
    ).resolves.toEqual({ deletedCount: 100, hasMore: true });

    await t.finishAllScheduledFunctions(vi.runAllTimers);

    const leftover = await t.run(async (ctx) => {
      return await ctx.db.query("accountDeletionMarkers").collect();
    });
    expect(leftover).toEqual([]);
  } finally {
    vi.useRealTimers();
  }
});
```

- [ ] **Step 3: Run them to verify they fail**

```bash
npx vitest run convex/sync.test.ts -t "purges aged post-wipe"
```

Expected: FAIL (`purgeBefore` is not an accepted arg yet; the other two fail on missing scheduling/self-reschedule).

- [ ] **Step 4: Implement the resume plumbing**

Add near the other internal functions in `convex/sync.ts`:

```ts
export const accountDeletionMarkerForOwnerInternal = internalQuery({
  args: {
    ownerTokenIdentifier: v.string(),
  },
  handler: async (ctx, args): Promise<Doc<"accountDeletionMarkers"> | null> => {
    return await accountDeletionMarkerForOwner(ctx, args.ownerTokenIdentifier);
  },
});

export const resumeIncompleteAccountDeletion = internalAction({
  args: {
    ownerTokenIdentifier: v.string(),
  },
  handler: async (ctx, args): Promise<void> => {
    const marker = await ctx.runQuery(
      internal.sync.accountDeletionMarkerForOwnerInternal,
      { ownerTokenIdentifier: args.ownerTokenIdentifier },
    );
    if (marker === null || marker.phaseRaw !== "deletionIncomplete") {
      return;
    }

    await deleteAccountDataWithBatches(async (tableName) => {
      return await ctx.runMutation(internal.sync.deleteAccountDataBatch, {
        ownerTokenIdentifier: args.ownerTokenIdentifier,
        tableName,
      });
    });

    await ctx.runMutation(internal.sync.markAccountDeletionDataDeleted, {
      ownerTokenIdentifier: args.ownerTokenIdentifier,
      cancellationToken: marker.cancellationToken,
    });
  },
});
```

Safety notes that make this correct: `deleteAccountDataBatch` no-ops when the marker is gone (Task 3 guard), so a cancellation that lands mid-resume stops the wipe; its first batch also flips `deletionIncomplete` → `deleting`, so a crash mid-resume returns the marker to the expired-`deleting` pool and the next GC pass re-parks and re-schedules it; if the resume fails to fully drain in 100 passes, `deleteAccountDataWithBatches` throws and the marker stays `deleting` for the same retry path.

- [ ] **Step 5: Rewrite `resolveExpiredAccountDeletionMarker`**

```ts
async function resolveExpiredAccountDeletionMarker(
  ctx: MutationCtx,
  marker: Doc<"accountDeletionMarkers">,
): Promise<boolean> {
  if (
    marker.phaseRaw === "cloudDataDeleted" ||
    marker.phaseRaw === "deletionIncomplete"
  ) {
    return false;
  }

  if (marker.phaseRaw === "started") {
    await ctx.db.delete(marker._id);
    return true;
  }

  // "deleting" or legacy phase-less: destructive work may have run.
  if (await ownerHasAccountData(ctx, marker.ownerTokenIdentifier)) {
    await ctx.db.patch(marker._id, { phaseRaw: "deletionIncomplete" });
    await ctx.scheduler.runAfter(0, internal.sync.resumeIncompleteAccountDeletion, {
      ownerTokenIdentifier: marker.ownerTokenIdentifier,
    });
    return false;
  }

  await ctx.db.patch(marker._id, {
    phaseRaw: "cloudDataDeleted",
    cloudDataDeletedAt: Date.now(),
  });
  return false;
}
```

- [ ] **Step 6: Rewrite `clearExpiredAccountDeletionMarkers`**

Replace the entire mutation (this collapses the three copy-pasted query blocks into a loop, adds the purge pass, retries parked resumes hourly, and self-reschedules on backlog — note markers processed by the expiry loop always leave their phase bucket, and purge deletes unconditionally, so `hasMore`-driven rescheduling is monotonic; the `deletionIncomplete` retry pass deliberately does not contribute to `hasMore`):

```ts
const expirableAccountDeletionPhases = ["started", "deleting", undefined] as const;

export const clearExpiredAccountDeletionMarkers = internalMutation({
  args: {
    expiresBefore: v.optional(v.number()),
    purgeBefore: v.optional(v.number()),
  },
  handler: async (ctx, args): Promise<AccountDeletionMarkerCleanupResult> => {
    const now = Date.now();
    const expiresBefore = args.expiresBefore ?? now - accountDeletionMarkerExpiryMs;
    const purgeBefore = args.purgeBefore ?? now - accountDeletionMarkerPurgeMs;
    let deletedCount = 0;
    let hasMore = false;

    for (const phaseRaw of expirableAccountDeletionPhases) {
      const candidates = await ctx.db
        .query("accountDeletionMarkers")
        .withIndex("by_phaseRaw_and_createdAt", (q) =>
          q.eq("phaseRaw", phaseRaw).lt("createdAt", expiresBefore),
        )
        .take(accountDeletionMarkerCleanupBatchSize + 1);
      hasMore = hasMore || candidates.length > accountDeletionMarkerCleanupBatchSize;

      for (const marker of candidates.slice(0, accountDeletionMarkerCleanupBatchSize)) {
        if (await resolveExpiredAccountDeletionMarker(ctx, marker)) {
          deletedCount += 1;
        }
      }
    }

    // Privacy backstop: markers whose cloud wipe finished long ago can never be
    // cancelled once the Clerk account is gone, so purge them instead of
    // retaining ownerTokenIdentifier forever.
    const purgeCandidates = await ctx.db
      .query("accountDeletionMarkers")
      .withIndex("by_phaseRaw_and_createdAt", (q) =>
        q.eq("phaseRaw", "cloudDataDeleted").lt("createdAt", purgeBefore),
      )
      .take(accountDeletionMarkerCleanupBatchSize + 1);
    hasMore = hasMore || purgeCandidates.length > accountDeletionMarkerCleanupBatchSize;
    for (const marker of purgeCandidates.slice(0, accountDeletionMarkerCleanupBatchSize)) {
      await ctx.db.delete(marker._id);
      deletedCount += 1;
    }

    // Hourly retry for parked partial deletions; intentionally excluded from
    // hasMore because these markers stay in their bucket until the resume
    // action completes.
    const parked = await ctx.db
      .query("accountDeletionMarkers")
      .withIndex("by_phaseRaw_and_createdAt", (q) =>
        q.eq("phaseRaw", "deletionIncomplete"),
      )
      .take(accountDeletionMarkerCleanupBatchSize);
    for (const marker of parked) {
      await ctx.scheduler.runAfter(0, internal.sync.resumeIncompleteAccountDeletion, {
        ownerTokenIdentifier: marker.ownerTokenIdentifier,
      });
    }

    if (hasMore) {
      await ctx.scheduler.runAfter(
        0,
        internal.sync.clearExpiredAccountDeletionMarkers,
        args,
      );
    }

    return { deletedCount, hasMore };
  },
});
```

- [ ] **Step 7: Update the four existing GC tests for the new args/semantics**

All in `convex/sync.test.ts`:

1. **"clearExpiredAccountDeletionMarkers removes only stale pre-wipe markers"** — add `purgeBefore: 0` to the mutation args (userB's `cloudDataDeleted` marker has `createdAt: 1_000`, which the new default purge cutoff would delete).
2. **"clearExpiredAccountDeletionMarkers protects stale markers after cloud data is gone"** — add `purgeBefore: 0` (the marker transitions to `cloudDataDeleted` in the same run and must not be purged by the test's cutoffs).
3. **"clearExpiredAccountDeletionMarkers handles legacy markers without a phase"** — add `purgeBefore: 0`; ALSO wrap the test in `vi.useFakeTimers()`/`vi.useRealTimers()` (same try/finally shape as the new tests) and, after the existing assertions, drain the scheduled resume so convex-test does not complain about in-flight scheduled functions, asserting the end state:

```ts
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    await expect(accountDeletionMarkersForOwner(t, userA)).resolves.toMatchObject([
      { phaseRaw: "cloudDataDeleted" },
    ]);
```

4. **"clearExpiredAccountDeletionMarkers keeps partial deletion markers when data remains"** — same treatment: add `purgeBefore: 0`, wrap in fake timers, keep the existing `deletionIncomplete` assertion as the mid-state check, then `await t.finishAllScheduledFunctions(vi.runAllTimers)` and assert the marker ends `cloudDataDeleted` (the server-side resume finished the wipe).
5. **"clearExpiredAccountDeletionMarkers reaches stale started markers behind completed markers"** — add `purgeBefore: 0` (the 101 seeded `cloudDataDeleted` markers have tiny `createdAt` values).
6. **DELETE the test "clearExpiredAccountDeletionMarkers moves past retained partial markers"** — it seeds 101 markers for one owner, which the one-marker-per-owner model never produces, and its two-manual-calls flow is superseded by the self-reschedule test added in Step 2.

- [ ] **Step 8: Run the full file**

```bash
npx vitest run convex/sync.test.ts
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add convex/sync.ts convex/sync.test.ts
git commit -m "Rework marker GC: phase loop, post-wipe purge, self-reschedule, server-side resume"
```

---

### Task 6: Full verification

**Files:** none modified.

- [ ] **Step 1: Run the entire Convex test suite and typecheck**

```bash
npx vitest run
npx tsc --noEmit -p convex
```

Expected: all tests PASS; typecheck clean. (If `convex/tsconfig.json` is not set up for `--noEmit` invocation, `npx convex dev --once --typecheck-only` is the fallback; skip if neither works and note it.)

- [ ] **Step 2: Push the branch**

```bash
git push origin codex/issue-93-account-deletion-marker
```

Do NOT open a PR or run any iOS simulator/Swift tests — the requester will review first.

---

## Explicitly out of scope

- **Swift changes.** The owner-scoped UserDefaults store and its first-reader-wins legacy migration ship as already implemented on the branch; the ≤24h edge case it leaves is accepted.
- **`convex/crons.ts`** stays as-is (hourly, empty args).
- The `deletionIncomplete` phase stays in the schema union; it is now a transient parking state that the GC + resume action drain.

## Self-review notes (already checked)

- `deleteAccountDataWithBatches` throws on the 100-pass limit, so `markAccountDeletionDataDeleted` (client action and resume action) only runs after a verified-empty wipe.
- `assertAccountDeletionNotStarted` deleting expired `started` markers is safe because `deleteAccountDataBatch` advances `started → deleting` in the same mutation as the first destructive delete (Task 3 keeps that atomicity).
- `hasMore` monotonicity: expiry buckets always shrink (delete or phase change out of bucket), purge always deletes; `deletionIncomplete` retries are excluded from `hasMore`.
- `accountDeletionMarkerForOwnerInternal` is required because actions cannot touch `ctx.db`; it reuses the existing helper after the Task 4 `QueryCtx` widening.
