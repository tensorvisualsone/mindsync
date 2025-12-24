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
                        )
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Lichtquelle")
                } footer: {
                    Text("Wähle zwischen Taschenlampe (heller) oder Bildschirm (mit Farben).")
                }
                
                Section {
                    Picker("Modus", selection: Binding(
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
                } header: {
                    Text("Entrainment-Modus")
                } footer: {
                    Text("Alpha: Entspannung, Theta: Trip, Gamma: Fokus")
                }
                
                Section {
                    Toggle("Sturzerkennung", isOn: Binding(
                        get: { preferences.fallDetectionEnabled },
                        set: { newValue in
                            preferences.fallDetectionEnabled = newValue
                            preferences.save()
                        }
                    ))
                    
                    Toggle("Thermischer Schutz", isOn: Binding(
                        get: { preferences.thermalProtectionEnabled },
                        set: { newValue in
                            preferences.thermalProtectionEnabled = newValue
                            preferences.save()
                        }
                    ))
                    
                    Toggle("Haptisches Feedback", isOn: Binding(
                        get: { preferences.hapticFeedbackEnabled },
                        set: { newValue in
                            preferences.hapticFeedbackEnabled = newValue
                            preferences.save()
                        }
                    ))
                } header: {
                    Text("Sicherheit & Feedback")
                }
                
                Section {
                    HStack {
                        Text("Standard-Intensität")
                        Spacer()
                        Text("\(Int(preferences.defaultIntensity * 100))%")
                            .foregroundStyle(.secondary)
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
                } header: {
                    Text("Intensität")
                } footer: {
                    Text("Standard-Helligkeit für Stroboskoplicht (betrifft nur Taschenlampe).")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

