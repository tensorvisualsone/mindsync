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
    
    // MARK: - Helper Methods
    
    /// Copies the affirmation file to the app's documents directory
    /// - Parameters:
    ///   - sourceURL: The source URL from the file picker
    ///   - oldAffirmationURL: The old affirmation URL to remove (optional)
    /// - Returns: The URL in the documents directory, or nil if copy failed
    private func copyAffirmationToDocuments(from sourceURL: URL, oldAffirmationURL: URL? = nil) -> URL? {
        let fileManager = FileManager.default
        
        // Get documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not get documents directory")
            return nil
        }
        
        // Create affirmations subdirectory if needed
        let affirmationsDir = documentsURL.appendingPathComponent("Affirmations", isDirectory: true)
        do {
            try fileManager.createDirectory(at: affirmationsDir, withIntermediateDirectories: true)
        } catch {
            print("Error creating Affirmations directory: \(error.localizedDescription)")
            return nil
        }
        
        // Remove old affirmation file if exists
        if let oldURL = oldAffirmationURL {
            try? fileManager.removeItem(at: oldURL)
        }
        
        // Generate unique filename with timestamp to avoid conflicts
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "affirmation_\(timestamp).\(fileExtension)"
        let destinationURL = affirmationsDir.appendingPathComponent(fileName)
        
        // Try to copy file using Data (more reliable for security-scoped resources)
        do {
            // Read data from source (works with security-scoped resources)
            let data = try Data(contentsOf: sourceURL)
            
            // Write to destination
            try data.write(to: destinationURL)
            
            print("Successfully copied affirmation to: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("Error copying affirmation file: \(error.localizedDescription)")
            
            // Fallback: try FileManager copy
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("Successfully copied affirmation (fallback) to: \(destinationURL.path)")
                return destinationURL
            } catch {
                print("Fallback copy also failed: \(error.localizedDescription)")
                return nil
            }
        }
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
                    Toggle(NSLocalizedString("settings.vibrationEnabled", comment: ""), isOn: Binding(
                        get: { preferences.vibrationEnabled },
                        set: { newValue in
                            preferences.vibrationEnabled = newValue
                            preferences.save()
                        }
                    ))
                    .accessibilityIdentifier("settings.vibrationEnabledToggle")
                    
                    if preferences.vibrationEnabled {
                        HStack {
                            Text(NSLocalizedString("settings.vibrationIntensity", comment: ""))
                                .font(AppConstants.Typography.body)
                            Spacer()
                            Text("\(Int(preferences.vibrationIntensity * 100))%")
                                .font(AppConstants.Typography.body)
                                .foregroundColor(.mindSyncSecondaryText)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { preferences.vibrationIntensity },
                                set: { newValue in
                                    preferences.vibrationIntensity = newValue
                                    preferences.save()
                                }
                            ),
                            in: 0.1...1.0,
                            step: 0.1
                        )
                        .accessibilityIdentifier("settings.vibrationIntensitySlider")
                    }
                } header: {
                    Text(NSLocalizedString("settings.vibration", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.vibrationDescription", comment: ""))
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
                            // Remove the file from documents directory
                            if let url = preferences.selectedAffirmationURL {
                                try? FileManager.default.removeItem(at: url)
                            }
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
                // Handle file import in a Task to properly manage security-scoped resource
                // Capture current old URL before async work
                let oldAffirmationURL = preferences.selectedAffirmationURL
                
                Task {
                    // Start accessing the security-scoped resource
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    
                    // Always stop access when done (even if we didn't get access, it's safe to call)
                    defer { 
                        if hasAccess {
                            url.stopAccessingSecurityScopedResource() 
                        }
                    }
                    
                    // First, copy the file to app's documents directory
                    // This must happen while we have security-scoped access
                    guard let copiedURL = copyAffirmationToDocuments(from: url, oldAffirmationURL: oldAffirmationURL) else {
                        await MainActor.run {
                            importError = NSError(
                                domain: ValidationError.domain,
                                code: ValidationError.invalidAudioFileCode,
                                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("error.file.saveFailed", comment: "")]
                            )
                            showingImportError = true
                        }
                        return
                    }
                    
                    // Now validate the copied file (we now have permanent access to it)
                    let asset = AVURLAsset(url: copiedURL)
                    do {
                        let isPlayable = try await asset.load(.isPlayable)
                        
                        await MainActor.run {
                            if isPlayable {
                                preferences.selectedAffirmationURL = copiedURL
                                preferences.save()
                            } else {
                                // Remove invalid file
                                try? FileManager.default.removeItem(at: copiedURL)
                                importError = NSError(
                                    domain: ValidationError.domain,
                                    code: ValidationError.invalidAudioFileCode,
                                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("settings.invalidAudioFile",
                                                                                           value: "The selected file is not a valid or playable audio file",
                                                                                           comment: "Error shown when imported audio file cannot be played")]
                                )
                                showingImportError = true
                            }
                        }
                    } catch {
                        // Remove file on error
                        try? FileManager.default.removeItem(at: copiedURL)
                        await MainActor.run {
                            importError = error
                            showingImportError = true
                        }
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
        .mindSyncBackground()
    }
}

#Preview {
    SettingsView()
}

