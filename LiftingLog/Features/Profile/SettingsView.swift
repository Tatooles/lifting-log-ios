import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    let settings: UserSettings
    @State private var saveErrorMessage: String?

    var body: some View {
        Form {
            Section("Units") {
                Picker("Weight Unit", selection: weightUnitBinding) {
                    ForEach(MeasurementUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("WeightUnitPicker")
            }

            Section("Rest Timer") {
                Stepper(value: restTimerBinding, in: 30...300, step: 15) {
                    Text("\(settings.defaultRestTimerSeconds) seconds")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Couldn't Save Settings",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        saveErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Try changing the setting again.")
        }
    }

    private var weightUnitBinding: Binding<MeasurementUnit> {
        Binding(
            get: { settings.weightUnit },
            set: { unit in
                do {
                    try settings.updateWeightUnit(unit, context: modelContext)
                    saveErrorMessage = nil
                } catch {
                    modelContext.rollback()
                    saveErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private var restTimerBinding: Binding<Int> {
        Binding(
            get: { settings.defaultRestTimerSeconds },
            set: { seconds in
                settings.defaultRestTimerSeconds = seconds
                settings.touch()
                do {
                    try modelContext.save()
                    saveErrorMessage = nil
                } catch {
                    modelContext.rollback()
                    saveErrorMessage = error.localizedDescription
                }
            }
        )
    }
}
