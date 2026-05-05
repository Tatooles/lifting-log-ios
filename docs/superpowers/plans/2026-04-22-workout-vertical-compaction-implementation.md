# Workout Vertical Compaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten the workout screen vertically so more active workout content is visible without changing behavior or the overall structure.

**Architecture:** Keep the compaction isolated to the workout feature views instead of shared theme or shell files, because the worktree already contains unrelated in-progress global compaction changes. Remove dead vertical space first by trimming stack spacing, paddings, and control heights in the sticky header, screen intro, exercise cards, and repeated set rows. Preserve the existing expand/collapse flow, bindings, and finish-sheet behavior.

**Tech Stack:** SwiftUI, Observation/AppStore bindings, Xcode build verification

---

### Task 1: Compact The Workout Screen Intro And Sticky Header

**Files:**
- Modify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Modify: `LiftingLog/Features/Workout/WorkoutHeaderView.swift`

- [ ] **Step 1: Update the workout screen spacing and controls**

```swift
VStack(alignment: .leading, spacing: 10) {
    VStack(alignment: .leading, spacing: 2) {
        TextField("Workout Name", text: $store.activeWorkout.name)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityIdentifier("WorkoutTitle")

        Text(AppTheme.formatDate(store.activeWorkout.date))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
    }

    // ...

    Label("Add Exercise", systemImage: "plus")
        .font(.system(size: 16, weight: .bold))
        .padding(.vertical, 11)

    SurfaceCard {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKOUT NOTES")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)

            TextField(
                "How did this session feel? Any PRs or notes for next time...",
                text: $store.activeWorkout.workoutNotes,
                axis: .vertical
            )
            .font(.system(size: 15))
            .lineLimit(3...5)
        }
    }
}
.padding(.horizontal, AppTheme.shellPadding)
.padding(.top, 8)
.padding(.bottom, AppTheme.contentBottomInset)
```

- [ ] **Step 2: Update the sticky header to consume less height**

```swift
HStack(spacing: 10) {
    HStack(spacing: 6) {
        Circle()
            .fill(AppTheme.accentBright)
            .frame(width: 6, height: 6)

        Text(AppTheme.formatDuration(elapsedSeconds))
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(AppTheme.textPrimary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)

    VStack(alignment: .leading, spacing: 2) {
        HStack {
            Text("Sets")
            Spacer()
            Text("\(completedSets)/\(totalSets)")
        }
        .font(.system(size: 12, weight: .medium))

        ProgressView(value: progressValue)
            .tint(AppTheme.accentBright)
            .scaleEffect(x: 1, y: 1.05, anchor: .center)
    }

    Button(action: onFinish) {
        Text("Finish")
            .font(.system(size: 15, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
    }
}
.padding(.horizontal, AppTheme.shellPadding)
.padding(.top, 6)
.padding(.bottom, 7)
```

- [ ] **Step 3: Build the app to verify the intro/header compaction compiles**

Run:

```bash
xcodebuild -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit the intro/header compaction**

```bash
git add LiftingLog/Features/Workout/WorkoutSessionView.swift LiftingLog/Features/Workout/WorkoutHeaderView.swift
git commit -m "refactor: tighten workout screen header spacing"
```

### Task 2: Compact Exercise Cards, Set Rows, And Notes

**Files:**
- Modify: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Modify: `LiftingLog/Features/Workout/SetRowView.swift`

- [ ] **Step 1: Reduce exercise card spacing and padding**

```swift
HStack(spacing: 10) {
    Image(systemName: "chevron.down")
        .font(.system(size: 13, weight: .bold))

    Text(exercise.name)
        .font(.system(size: 18, weight: .bold))

    Spacer()

    Text("\(exercise.sets.filter(\.isDone).count)/\(exercise.sets.count)")
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
}
.padding(.horizontal, 14)
.padding(.vertical, 13)

if !exercise.isCollapsed {
    VStack(spacing: 10) {
        HStack(spacing: 10) {
            Color.clear.frame(width: 18)
            columnHeader("LBS")
            columnHeader("REPS")
            columnHeader("RPE")
            Color.clear.frame(width: 26)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)

        VStack(spacing: 9) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRowView(store: store, exerciseID: exercise.id, set: set, index: index)
                    .padding(.horizontal, 14)
            }
        }

        Label("Add Set", systemImage: "plus")
            .font(.system(size: 15, weight: .bold))
            .padding(.vertical, 11)

        TextField(
            "Exercise notes...",
            text: Binding(
                get: { exercise.notes },
                set: { store.updateExerciseNotes(exerciseID: exercise.id, notes: $0) }
            ),
            axis: .vertical
        )
            .font(.system(size: 15))
            .padding(12)
            .frame(minHeight: 74, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
    }
}
```

- [ ] **Step 2: Shorten set row controls without changing behavior**

```swift
HStack(spacing: 8) {
    Text("\(index + 1)")
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 16)

    numericField(
        placeholder: "lbs",
        text: Binding(
            get: { set.weight },
            set: { store.updateSetWeight(exerciseID: exerciseID, setID: set.id, value: $0) }
        ),
        keyboard: .numberPad
    )

    numericField(
        placeholder: "reps",
        text: Binding(
            get: { set.reps },
            set: { store.updateSetReps(exerciseID: exerciseID, setID: set.id, value: $0) }
        ),
        keyboard: .numberPad
    )

    numericField(
        placeholder: "RPE",
        text: Binding(
            get: { set.rpe },
            set: { store.updateSetRPE(exerciseID: exerciseID, setID: set.id, value: $0) }
        ),
        keyboard: .decimalPad
    )

    Button {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleSetDone(exerciseID: exerciseID, setID: set.id)
        }
    } label: {
        Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: .regular))
    }
}

private func numericField(
    placeholder: String,
    text: Binding<String>,
    keyboard: UIKeyboardType
) -> some View {
    TextField(placeholder, text: text)
        .keyboardType(keyboard)
        .multilineTextAlignment(.center)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderStrong)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
}
```

- [ ] **Step 3: Build the app to verify the repeated workout rows compile**

Run:

```bash
xcodebuild -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit the exercise card and row compaction**

```bash
git add LiftingLog/Features/Workout/ExerciseCardView.swift LiftingLog/Features/Workout/SetRowView.swift
git commit -m "refactor: compact workout exercise cards"
```

### Task 3: End-To-End Verification Of The Workout Screen

**Files:**
- Verify: `LiftingLog/Features/Workout/WorkoutSessionView.swift`
- Verify: `LiftingLog/Features/Workout/WorkoutHeaderView.swift`
- Verify: `LiftingLog/Features/Workout/ExerciseCardView.swift`
- Verify: `LiftingLog/Features/Workout/SetRowView.swift`

- [ ] **Step 1: Run a final build after all workout compaction changes**

Run:

```bash
xcodebuild -project LiftingLog.xcodeproj -scheme LiftingLog -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Manually verify the workout screen states in the simulator**

Check:

```text
1. The sticky header is visibly shorter but still readable.
2. The workout name/date block sits closer to the header.
3. Expanded exercise cards show denser spacing between the header, set rows, add-set button, and notes.
4. Collapsed exercise cards still read cleanly.
5. The Finish button still opens the finish sheet.
```

- [ ] **Step 3: Commit the verified workout compaction pass**

```bash
git add LiftingLog/Features/Workout/WorkoutSessionView.swift LiftingLog/Features/Workout/WorkoutHeaderView.swift LiftingLog/Features/Workout/ExerciseCardView.swift LiftingLog/Features/Workout/SetRowView.swift
git commit -m "refactor: tighten workout screen vertical spacing"
```
