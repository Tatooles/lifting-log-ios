import SwiftData
import SwiftUI

struct WorkoutHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncScheduler.self) private var syncScheduler
    let session: WorkoutSession
    @State private var deleteErrorMessage: String?
    @State private var editPresentation: CompletedWorkoutEditPresentation?
    @Query(sort: \UserSettings.createdAt) private var settingsRecords: [UserSettings]

    private var metrics: WorkoutMetrics {
        WorkoutMetrics(session: session)
    }

    private var weightUnit: MeasurementUnit {
        UserSettings.visibleSettingsRecords(
            from: settingsRecords,
            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier
        ).first?.weightUnit ?? .pounds
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(WorkoutFormatters.compactDate(session.startedAt))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    metricCard(title: "Duration", value: AppTheme.formatDuration(metrics.durationSeconds))
                    metricCard(title: "Exercises", value: "\(session.sortedLoggedExercises.count)")
                    metricCard(title: "Sets", value: "\(metrics.completedSetCount)")
                }

                if !session.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.system(size: 16, weight: .bold))
                            Text(session.notes)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("WorkoutHistoryNotesCard")
                }

                ForEach(session.sortedLoggedExercises) { loggedExercise in
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loggedExercise.exerciseSnapshotName)
                                    .font(.system(size: 18, weight: .bold))
                                if let metadataDisplayText = loggedExercise.metadataDisplayText {
                                    Text(metadataDisplayText)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            ForEach(loggedExercise.sortedSets) { set in
                                HStack {
                                    Text("Set \(set.orderIndex + 1)")
                                    Spacer()
                                    Text(setSummary(for: set))
                                        .foregroundStyle(set.isCompleted ? AppTheme.accentBright : AppTheme.textSecondary)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .accessibilityIdentifier("WorkoutHistorySetSummary-\(loggedExercise.orderIndex)-\(set.orderIndex)")
                            }

                            ExerciseHistoryNoteBlock(note: loggedExercise.notes)
                        }
                    }
                }

                Button(role: .destructive) {
                    do {
                        try WorkoutHistoryMutationService().deleteWorkoutHistory(
                            session,
                            ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
                            context: modelContext
                        )
                        syncScheduler.requestSync()
                        deleteErrorMessage = nil
                        dismiss()
                    } catch {
                        modelContext.rollback()
                        deleteErrorMessage = error.localizedDescription
                    }
                } label: {
                    Text("Delete Workout")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accentBright)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.accentBright.opacity(0.45))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(AppTheme.shellPadding)
        }
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    editPresentation = CompletedWorkoutEditPresentation(session: session)
                }
                .accessibilityIdentifier("EditWorkoutButton")
            }
        }
        .sheet(item: $editPresentation) { presentation in
            CompletedWorkoutEditView(
                session: session,
                draft: presentation.draft,
                weightUnit: weightUnit
            )
        }
        .alert(
            "Couldn't Delete Workout",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Try deleting again.")
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        SurfaceCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func setSummary(for set: LoggedSet) -> String {
        let weight = weightText(for: set)
        let reps = set.reps.map(String.init) ?? "-"
        let rpe = set.rpe.map { " @ \(WorkoutFormatters.number($0))" } ?? ""
        let status = set.isCompleted ? "Done" : "Open"
        return "\(weight) x \(reps)\(rpe) · \(status)"
    }

    private func weightText(for set: LoggedSet) -> String {
        guard let displayWeight = weightUnit.displayWeight(fromCanonicalPounds: set.weight) else {
            return "-"
        }

        return WorkoutFormatters.number(displayWeight)
    }
}

private struct CompletedWorkoutEditPresentation: Identifiable {
    let id: UUID
    let draft: CompletedWorkoutEditDraft

    init(session: WorkoutSession) {
        id = session.id
        draft = CompletedWorkoutEditDraft(session: session)
    }
}

private struct CompletedWorkoutEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncScheduler.self) private var syncScheduler

    let session: WorkoutSession
    let weightUnit: MeasurementUnit
    private let initialDurationSeconds: Int
    private let initialDurationMinutesText: String
    @State private var draft: CompletedWorkoutEditDraft
    @State private var durationMinutesText: String
    @State private var errorMessage: String?
    @State private var removalCandidate: CompletedWorkoutSetRemovalCandidate?
    @FocusState private var focusedField: CompletedWorkoutEditFocusedField?

    init(session: WorkoutSession, draft: CompletedWorkoutEditDraft, weightUnit: MeasurementUnit) {
        self.session = session
        self.weightUnit = weightUnit
        initialDurationSeconds = draft.durationSeconds
        initialDurationMinutesText = CompletedWorkoutDurationInput.minutesText(for: draft.durationSeconds)
        _draft = State(initialValue: draft)
        _durationMinutesText = State(initialValue: initialDurationMinutesText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sessionFields

                    ForEach(draft.exercises.indices, id: \.self) { exerciseIndex in
                        exerciseEditor(exerciseIndex: exerciseIndex)
                    }
                }
                .padding(AppTheme.shellPadding)
            }
            .background(AppTheme.subtleBackground.ignoresSafeArea())
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .accessibilityIdentifier("SaveCompletedWorkoutEditButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("DismissKeyboardButton")
                }
            }
            .alert(
                "Remove Set?",
                isPresented: Binding(
                    get: { removalCandidate != nil },
                    set: { isPresented in
                        if !isPresented {
                            removalCandidate = nil
                        }
                    }
                )
            ) {
                Button("Remove", role: .destructive) {
                    if let removalCandidate {
                        removeSet(removalCandidate)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes set \(removalCandidate?.displayNumber ?? 1) from the completed workout.")
            }
            .alert(
                "Couldn't Save Workout",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Try saving again.")
            }
        }
    }

    private var sessionFields: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout")
                    .font(.system(size: 18, weight: .bold))

                TextField("Workout Name", text: $draft.title)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .title)
                    .fieldStyle()
                    .accessibilityIdentifier("CompletedWorkoutTitleField")

                TextField("Duration (minutes)", text: $durationMinutesText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .duration)
                    .fieldStyle()
                    .accessibilityIdentifier("CompletedWorkoutDurationMinutesField")

                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .notes)
                    .fieldStyle()
                    .accessibilityIdentifier("CompletedWorkoutNotesField")
            }
        }
    }

    private func exerciseEditor(exerciseIndex: Int) -> some View {
        let exercise = draft.exercises[exerciseIndex]

        return SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.exerciseSnapshotName)
                        .font(.system(size: 18, weight: .bold))
                    if let metadataDisplayText = exercise.metadataDisplayText {
                        Text(metadataDisplayText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                VStack(spacing: 10) {
                    let setIndices = visibleSetIndices(for: exerciseIndex)
                    ForEach(Array(setIndices.enumerated()), id: \.element) { visibleIndex, setIndex in
                        setEditor(exerciseIndex: exerciseIndex, setIndex: setIndex, visibleIndex: visibleIndex)
                    }
                }

                Button {
                    addSet(to: exerciseIndex)
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accentBright)
                .accessibilityIdentifier("AddHistorySetButton-\(exerciseIndex)")
            }
        }
    }

    private func setEditor(exerciseIndex: Int, setIndex: Int, visibleIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(visibleIndex + 1)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 18)

            editableNumberField(
                placeholder: weightUnit.fieldPlaceholder,
                text: weightBinding(exerciseIndex: exerciseIndex, setIndex: setIndex),
                keyboard: .decimalPad,
                focusTarget: .setWeight(exerciseIndex, setIndex),
                accessibilityIdentifier: "HistorySetWeightField-\(exerciseIndex)-\(visibleIndex)"
            )

            editableNumberField(
                placeholder: "REPS",
                text: repsBinding(exerciseIndex: exerciseIndex, setIndex: setIndex),
                keyboard: .numberPad,
                focusTarget: .setReps(exerciseIndex, setIndex),
                accessibilityIdentifier: "HistorySetRepsField-\(exerciseIndex)-\(visibleIndex)"
            )

            editableNumberField(
                placeholder: "RPE",
                text: rpeBinding(exerciseIndex: exerciseIndex, setIndex: setIndex),
                keyboard: .decimalPad,
                focusTarget: .setRPE(exerciseIndex, setIndex),
                accessibilityIdentifier: "HistorySetRPEField-\(exerciseIndex)-\(visibleIndex)"
            )

            Button {
                draft.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
            } label: {
                Image(systemName: draft.exercises[exerciseIndex].sets[setIndex].isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(draft.exercises[exerciseIndex].sets[setIndex].isCompleted ? AppTheme.accentBright : AppTheme.textTertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.exercises[exerciseIndex].sets[setIndex].isCompleted ? "Mark set incomplete" : "Mark set complete")
            .accessibilityIdentifier("HistorySetCompletionButton-\(exerciseIndex)-\(visibleIndex)")

            Button(role: .destructive) {
                removalCandidate = CompletedWorkoutSetRemovalCandidate(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    displayNumber: visibleIndex + 1
                )
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accentBright)
                    .frame(width: 34, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove set")
            .accessibilityIdentifier("RemoveHistorySetButton-\(exerciseIndex)-\(visibleIndex)")
        }
    }

    private func editableNumberField(
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        focusTarget: CompletedWorkoutEditFocusedField,
        accessibilityIdentifier: String
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(AppTheme.textPrimary)
            .focused($focusedField, equals: focusTarget)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = focusTarget
            }
            .background(
                AppTheme.fieldFill,
                in: RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
            )
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func weightBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: {
                let canonicalWeight = draft.exercises[exerciseIndex].sets[setIndex].weight
                return weightUnit.displayWeight(fromCanonicalPounds: canonicalWeight).map(WorkoutFormatters.number) ?? ""
            },
            set: { value in
                let displayWeight = WorkoutFormatters.parseNumber(value)
                draft.exercises[exerciseIndex].sets[setIndex].weight = weightUnit.canonicalWeight(fromDisplayWeight: displayWeight)
            }
        )
    }

    private func repsBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { draft.exercises[exerciseIndex].sets[setIndex].reps.map(String.init) ?? "" },
            set: { value in
                draft.exercises[exerciseIndex].sets[setIndex].reps = Int(value)
            }
        )
    }

    private func rpeBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { draft.exercises[exerciseIndex].sets[setIndex].rpe.map(WorkoutFormatters.number) ?? "" },
            set: { value in
                draft.exercises[exerciseIndex].sets[setIndex].rpe = WorkoutFormatters.parseNumber(value)
            }
        )
    }

    private func visibleSetIndices(for exerciseIndex: Int) -> [Int] {
        draft.exercises[exerciseIndex].sets.indices.filter { !draft.exercises[exerciseIndex].sets[$0].isRemoved }
    }

    private func addSet(to exerciseIndex: Int) {
        let visibleCount = visibleSetIndices(for: exerciseIndex).count
        let setIndex = draft.exercises[exerciseIndex].sets.count
        draft.exercises[exerciseIndex].sets.append(
            CompletedWorkoutEditSetDraft(orderIndex: visibleCount)
        )
        focusedField = .setWeight(exerciseIndex, setIndex)
    }

    private func removeSet(_ candidate: CompletedWorkoutSetRemovalCandidate) {
        guard draft.exercises.indices.contains(candidate.exerciseIndex),
              draft.exercises[candidate.exerciseIndex].sets.indices.contains(candidate.setIndex)
        else { return }

        if draft.exercises[candidate.exerciseIndex].sets[candidate.setIndex].id == nil {
            draft.exercises[candidate.exerciseIndex].sets.remove(at: candidate.setIndex)
        } else {
            draft.exercises[candidate.exerciseIndex].sets[candidate.setIndex].isRemoved = true
        }
        reindexDraftSets(for: candidate.exerciseIndex)
    }

    private func reindexDraftSets(for exerciseIndex: Int) {
        for (visibleIndex, setIndex) in visibleSetIndices(for: exerciseIndex).enumerated() {
            draft.exercises[exerciseIndex].sets[setIndex].orderIndex = visibleIndex
        }
    }

    private func save() {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.title = trimmedTitle.isEmpty ? "Workout" : trimmedTitle

        do {
            draft.durationSeconds = try CompletedWorkoutDurationInput.durationSeconds(
                from: durationMinutesText,
                initialMinutesText: initialDurationMinutesText,
                initialDurationSeconds: initialDurationSeconds
            )
            try WorkoutHistoryMutationService().saveCompletedWorkoutEdit(
                draft,
                for: session,
                ownerTokenIdentifier: syncScheduler.currentOwnerTokenIdentifier,
                context: modelContext
            )
            syncScheduler.requestSync()
            errorMessage = nil
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct CompletedWorkoutSetRemovalCandidate: Identifiable {
    let id = UUID()
    let exerciseIndex: Int
    let setIndex: Int
    let displayNumber: Int
}

private enum CompletedWorkoutEditFocusedField: Hashable {
    case title
    case duration
    case notes
    case setWeight(Int, Int)
    case setReps(Int, Int)
    case setRPE(Int, Int)
}

private extension View {
    func fieldStyle() -> some View {
        self
            .font(.body.weight(.medium))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                AppTheme.fieldFill,
                in: RoundedRectangle(cornerRadius: AppTheme.fieldCornerRadius, style: .continuous)
            )
    }
}
