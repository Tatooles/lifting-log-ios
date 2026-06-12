# Design & UX Review

_June 2026 — review of the `fable-redesign-attempt` branch, conducted by walking through every screen in the simulator (light + dark mode) plus a full active-workout loop._

## Overall assessment

The redesign reads as intentional and is noticeably above typical side-project quality:

- Coherent design system: `AppTheme` tokens, one card language (`SurfaceCard`), consistent radii, warm off-white / near-black backgrounds, restrained brick-red accent.
- The active workout screen — the screen that matters — has real polish: pinned timer + session progress pill, per-exercise completion badges, bouncing checkmark, prev/next field navigation, swipe-to-delete sets.
- The finish sheet (summary stats, Keep Going, confirmed destructive discard) is exactly right.
- Real empty states, dark mode holds up, accessibility identifiers/labels everywhere, thoughtful sync-failure banner.

The gaps are less about visual design and more about the mid-workout experience and information density.

## Improvements, in priority order

### 1. Rest timer (highest impact, missing entirely)

Resting between sets is most of a workout's clock time; users currently leave the app to time it. Even a simple auto-starting countdown in the header pill after marking a set complete would transform the in-gym experience.

### 2. Last-time performance visibility

See the [dedicated section below](#last-time-performance-design) — this deserves its own design.

### 3. Set-row visual noise

Each card shows column headers (LBS/REPS/RPE) *and* identical placeholder text in every field, so a fresh card repeats "LBS REPS RPE" up to four times. Drop one of the two. Also: RPE is always shown as a full column, but many lifters never log it. Remove the column entirely and move RPE entry to the keyboard toolbar — see the [RPE entry design](#rpe-entry-design) below. This simplifies the most-used screen by a third and frees row width for the "Previous" column.

### 4. Always-visible notes box

Every exercise card carries a large empty gray "Exercise notes…" block — the biggest single consumer of vertical space on the workout screen, empty the vast majority of the time. Collapse it to a small "Add note" affordance (or move it into the per-exercise ellipsis menu).

### 5. Templates

`WorkoutTemplate` exists as a model but no UI references it. "Use Past Workout" conflates "my routine" with "whatever I happened to do last." Named templates on the Start tab are the natural next step; the model is already there.

### 6. History rows tell you almost nothing

Every row is titled "Workout" with date/counts. Auto-name from muscle groups ("Chest & Calves") or prompt for a title in the finish sheet. In the detail view, empty sets render as `- x -` with a red "Done" that looks tappable but isn't — reads as broken rather than empty.

### 7. Profile duplicates Settings, read-only

The Units/Theme/Data Source rows display values but aren't editable, and the same settings live one tap away behind the Settings row. "Data Source: SwiftData" is developer vocabulary. Make those rows tappable shortcuts or cut them.

### Smaller items

- The keyboard accessory (prev/next/Done) floated on top of the tab bar when a field was focused with a hardware keyboard attached — verify on device; may be a real overlap bug.
- Finish sheet "Volume 1080" needs a unit.
- Exercise Library is a flat alphabetical list — fine at 21 exercises; add muscle-group sections or filter chips as it grows.

**If picking one investment:** the rest timer plus inline last-time numbers. Those two close the loop on "what do I lift and when do I go again," which is the entire in-gym job of the app.

---

## Last-time performance design

### How it works today (and why it's convoluted)

- Placeholders are **persisted fields** on `LoggedSet` (`placeholderWeight/Reps/RPE`), copied from the cloned workout's values in `ActiveWorkoutEngine`, inherited when adding a set, **synced to Convex**, and unit-converted in two separate code paths.
- Completing an empty set **silently commits the placeholder as the real value**, which is why `SetRowView` needs the `WorkoutNumberInputText` draft type and the `suppressNextCompletionClearIfNeeded` timing hack.
- Placeholders only exist when cloning a past workout. Blank workouts and newly added exercises get nothing from history.
- The data source is wrong: it shows what the *cloned* workout did, not what the user did *last time* — and last time is what the user actually cares about.

### Recommended design: dedicated "Previous" column with tap-to-fill

The pattern Strong and Hevy converged on. Each set row shows last session's same-index set as small, non-editable tertiary text ("135 × 8") next to the input fields. Tapping it — or tapping ✓ on an empty row — fills the fields.

Row layout: `# | Previous | LBS | REPS | ✓`, with the RPE column removed entirely (see [RPE entry design](#rpe-entry-design); bundle the two changes — they compete for the same row width).

Why this beats ghost placeholders:

1. **Unambiguous.** Ghost text in an editable field can't answer "did I log this or is it a suggestion?" Today's commit-on-complete means history can contain numbers the user never typed. With a separate column, "what I did then" and "what I'm doing now" never share a pixel. Keep the one-tap fast path: tapping ✓ on an empty row visibly animates the previous values *into* the fields before completing, so logging stays fast but becomes explicit.
2. **The comparison survives typing.** A placeholder vanishes the instant you type — exactly when you want to ask "am I beating last week?" The column stays visible for the whole set.
3. **Right data source.** Computed live from the exercise's *last completed session* (matched by exercise identity, set-by-set by index; extra sets show "—"), independent of how the workout was started. Cloning then copies *structure* (exercises, set counts), not numbers. Blank workouts get history too. The split edge case (same lift, different rep scheme on different days) is rare; if it ever matters, scope "last time" to sessions with the same title/template — a data-source tweak, not a UI change.
4. **Deletes the convoluted machinery.** The three `placeholder*` fields come off `LoggedSet`, out of the sync payloads, and out of both unit-conversion paths. `WorkoutNumberInputText` and the suppression hack go away. "Previous" becomes a read-only computed lookup: one fetch per exercise card, cached in the engine. The fields become dumb text fields.

### Convex cleanup

The placeholder fields never belonged in the synced data model — they are transient UI hints, not workout facts — so they can be removed from the backend outright, with no backward-compatibility shims:

- `convex/schema.ts` (~line 112): drop `placeholderWeight` / `placeholderReps` / `placeholderRPE` from the sets table.
- `convex/sync/validators.ts` (~line 80): drop the same three fields from the set payload validator.
- `convex/sync.test.ts`: remove the fields from fixtures and assertions.
- iOS side: remove the fields from `SyncPayloads` and `ConvexSyncClient` argument mapping in the same change, so client and server payload shapes stay in lockstep.

One practical note: Convex validates existing documents against the schema, so fields can't just be deleted from `schema.ts` while old documents still carry them. Either mark the three fields optional first and run a migration that unsets them from existing set documents, then remove them from the schema — or, if the synced data is still disposable at this stage, clear the table and remove the fields in one step.

### Rejected alternative

A one-line "Last: 135×8, 140×6 · Jun 5" summary under the exercise header. Cheaper, but answers the question at the wrong granularity — mid-workout you want *this set's* target at *this row's* eye line. Only worth it if set rows must stay untouched.

---

## RPE entry design

RPE is a power-user dimension: it shouldn't cost a full column on every set row, but it also shouldn't hide behind a global setting (that just relocates the problem). Entry should live where the user's fingers already are mid-logging.

### Recommended design: keyboard-toolbar chips + badge on the reps field

- **Entry:** while a weight or reps field is focused, the existing keyboard accessory toolbar (prev/next/Done in `WorkoutSessionView`) gains an "RPE" item. Tapping it shows a row of chips — `6 · 7 · 8 · 8.5 · 9 · 9.5 · 10` — either swapping the toolbar content or as a small glass capsule above it. Tapping a chip records the value and advances focus to the next field (same behavior as the Next button).
- **Display:** the chosen value renders as a small "@9" badge overlaid on the top-right corner of the reps field (ZStack overlay — true superscript inside a `TextField` isn't practical). Tapping the badge re-opens the chips to edit or clear, which also covers post-completion editing.
- **No custom keyboard.** A fully custom numeric keyboard (the Hevy approach) would also work but looks slightly foreign next to Liquid Glass, costs system keyboard features (cursor sliding, hardware-keyboard passthrough), and is far more code. A `.glass`-style chip capsule riding above the system keyboard is native vocabulary and gets the same result.
- **Data model:** RPE stays `Double?` on `LoggedSet`; chips at 0.5 increments cover the domain. Free-text RPE entry goes away — treated as a feature (no more `9.25`).

Technical scope is modest: one toolbar item, one chip-row view, one badge overlay; no changes to the focus system.

### Rejected alternatives

- **Global settings toggle for the RPE column:** hides the feature; users who want RPE shouldn't need to find a preference first.
- **Per-exercise "Track RPE" in the ellipsis menu:** better targeting, but still a toggle, and it resurrects the three-column width problem on exactly the rows that also want the Previous column.
- **Completion-time "@ RPE" chip next to the checkmark:** matches the mental model (RPE is assessed after the set) and costs zero space during entry, but adds a tap per set for habitual RPE users and changes the row's shape post-completion. Its one good idea — tap-to-edit after completion — is kept via the badge.
- **Gestures (long-press the checkmark, swipe):** undiscoverable, and the row already owns swipe-to-delete.
