import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Settings view for user preferences
struct SettingsView: View {
    // MARK: - Error Constants
    private enum ValidationError {
        static let domain = "com.mindsync.settings"
        static let invalidAudioFileCode = 1
    }
    
    @State private var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var showingAffirmationImporter = false
    @State private var showingHistory = false
    @State private var importError: Error?
    @State private var showingImportError = false
    
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
                    if let url = preferences.selectedAffirmationURL {
                        Text(url.lastPathComponent)
                            .font(AppConstants.Typography.body)
                            .foregroundColor(.mindSyncPrimaryText)
                    } else {
                        Text(NSLocalizedString("settings.affirmationNone", comment: ""))
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                    }
                    
                    Button(NSLocalizedString("settings.affirmationSelect", comment: "")) {
                        showingAffirmationImporter = true
                    }
                    
                    if preferences.selectedAffirmationURL != nil {
                        Button(NSLocalizedString("settings.affirmationRemove", comment: ""), role: .destructive) {
                            preferences.selectedAffirmationURL = nil
                            preferences.save()
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.affirmations", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.affirmationsDescription", comment: ""))
                }
                
                Section {
                    Picker(NSLocalizedString("settings.maxDuration", comment: ""), selection: Binding(
                        get: { preferences.maxSessionDuration },
                        set: { newValue in
                            preferences.maxSessionDuration = newValue
                            preferences.save()
                        }
                    )) {
                        Text(NSLocalizedString("settings.duration.unlimited", comment: ""))
                            .tag(TimeInterval?.none)
                        Text("5 min").tag(TimeInterval?(300))
                        Text("10 min").tag(TimeInterval?(600))
                        Text("15 min").tag(TimeInterval?(900))
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(NSLocalizedString("settings.session", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.sessionDescription", comment: ""))
                }
                
                Section {
                    Button {
                        showingHistory = true
                    } label: {
                        Label(NSLocalizedString("settings.history", comment: ""), systemImage: "clock.arrow.circlepath")
                    }
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
        .navigationDestination(isPresented: $showingHistory) {
            SessionHistoryView()
        }
        .fileImporter(isPresented: $showingAffirmationImporter, allowedContentTypes: [.audio]) { result in
            // SwiftUI's fileImporter callbacks are serialized on the MainActor and cannot be
            // invoked concurrently, so no additional synchronization is needed.
            
            switch result {
            case .success(let url):
                // Validate that the file is playable before saving (async load for consistency)
                Task {
                    let asset = AVURLAsset(url: url)
                    do {
                        let isPlayable = try await asset.load(.isPlayable)
                        
                        if isPlayable {
                            preferences.selectedAffirmationURL = url
                            preferences.save()
                        } else {
                            importError = NSError(
                                domain: ValidationError.domain,
                                code: ValidationError.invalidAudioFileCode,
                                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("settings.invalidAudioFile",
                                                                                       value: "The selected file is not a valid or playable audio file",
                                                                                       comment: "Error shown when imported audio file cannot be played")]
                            )
                            showingImportError = true
                        }
                    } catch {
                        importError = error
                        showingImportError = true
                    }
                }
            case .failure(let error):
                importError = error
                showingImportError = true
            }
        }
        .alert(NSLocalizedString("common.error", comment: ""), isPresented: $showingImportError, presenting: importError) { _ in
            Button(NSLocalizedString("common.ok", comment: ""), role: .cancel) { }
        } message: { error in
            Text(NSLocalizedString("settings.importError", comment: "") + ": " + error.localizedDescription)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.06, green: 0.02, blue: 0.12),
                    Color(red: 0.01, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    SettingsView()
}

