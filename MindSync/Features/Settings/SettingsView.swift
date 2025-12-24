import SwiftUI

/// Settings view for user preferences
struct SettingsView: View {
    @State private var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    
    init() {
        _preferences = State(initialValue: UserPreferences.load())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LightSourcePicker(
                        selectedSource: Binding(
                            get: { preferences.preferredLightSource },
                            set: { newValue in
                                preferences.preferredLightSource = newValue
                                preferences.save()
                            }
                        ),
                        screenColor: Binding(
                            get: { preferences.screenColor },
                            set: { newValue in
                                preferences.screenColor = newValue
                                preferences.save()
                            }
                        ),
                        customColorRGB: Binding(
                            get: { preferences.customColorRGB },
                            set: { newValue in
                                preferences.customColorRGB = newValue
                                preferences.save()
                            }
                        )
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text(NSLocalizedString("settings.lightSource", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.lightSourceDescription", comment: ""))
                }
                
                Section {
                    Picker(NSLocalizedString("settings.mode", comment: ""), selection: Binding(
                        get: { preferences.preferredMode },
                        set: { newValue in
                            preferences.preferredMode = newValue
                            preferences.save()
                            // Haptic feedback for mode change
                            if preferences.hapticFeedbackEnabled {
                                HapticFeedback.light()
                            }
                        }
                    )) {
                        ForEach(EntrainmentMode.allCases) { mode in
                            HStack {
                                Image(systemName: mode.iconName)
                                Text(mode.displayName)
                            }
                            .tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settings.modePicker")
                } header: {
                    Text(NSLocalizedString("settings.entrainmentMode", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.entrainmentModeDescription", comment: ""))
                }
                
                Section {
                    Toggle(NSLocalizedString("settings.fallDetection", comment: ""), isOn: Binding(
                        get: { preferences.fallDetectionEnabled },
                        set: { newValue in
                            preferences.fallDetectionEnabled = newValue
                            preferences.save()
                        }
                    ))
                    .accessibilityIdentifier("settings.fallDetectionToggle")
                    
                    Toggle(NSLocalizedString("settings.thermalProtection", comment: ""), isOn: Binding(
                        get: { preferences.thermalProtectionEnabled },
                        set: { newValue in
                            preferences.thermalProtectionEnabled = newValue
                            preferences.save()
                        }
                    ))
                    .accessibilityIdentifier("settings.thermalProtectionToggle")
                    
                    Toggle(NSLocalizedString("settings.hapticFeedback", comment: ""), isOn: Binding(
                        get: { preferences.hapticFeedbackEnabled },
                        set: { newValue in
                            preferences.hapticFeedbackEnabled = newValue
                            preferences.save()
                        }
                    ))
                    .accessibilityIdentifier("settings.hapticFeedbackToggle")
                } header: {
                    Text(NSLocalizedString("settings.safetyAndFeedback", comment: ""))
                }
                
                Section {
                    HStack {
                        Text(NSLocalizedString("settings.defaultIntensity", comment: ""))
                            .font(AppConstants.Typography.body)
                        Spacer()
                        Text("\(Int(preferences.defaultIntensity * 100))%")
                            .font(AppConstants.Typography.body)
                            .foregroundColor(.mindSyncSecondaryText)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { preferences.defaultIntensity },
                            set: { newValue in
                                preferences.defaultIntensity = newValue
                                preferences.save()
                            }
                        ),
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    .accessibilityIdentifier("settings.intensitySlider")
                } header: {
                    Text(NSLocalizedString("settings.intensity", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.intensityDescription", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("settings.done", comment: "")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.doneButton")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

