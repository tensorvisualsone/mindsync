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
            ScrollView {
                VStack(spacing: AppConstants.Spacing.lg) {
                    // Entrainment Mode
                    SettingsCard(
                        icon: preferences.preferredMode.iconName,
                        iconColor: preferences.preferredMode.themeColor,
                        title: NSLocalizedString("settings.entrainmentMode", comment: ""),
                        footer: NSLocalizedString("settings.entrainmentModeDescription", comment: "")
                    ) {
                        Picker(NSLocalizedString("settings.mode", comment: ""), selection: Binding(
                            get: { preferences.preferredMode },
                            set: { newValue in
                                preferences.preferredMode = newValue
                                preferences.save()
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
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("settings.modePicker")
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Safety & Feedback
                    SettingsCard(
                        icon: "shield.fill",
                        iconColor: .mindSyncWarning,
                        title: NSLocalizedString("settings.safetyAndFeedback", comment: "")
                    ) {
                        VStack(spacing: AppConstants.Spacing.md) {
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
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Vibration
                    SettingsCard(
                        icon: "iphone.radiowaves.left.and.right",
                        iconColor: .mindSyncInfo,
                        title: NSLocalizedString("settings.vibration", comment: ""),
                        footer: NSLocalizedString("settings.vibrationDescription", comment: "")
                    ) {
                        VStack(spacing: AppConstants.Spacing.md) {
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
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Affirmations
                    SettingsCard(
                        icon: "waveform.and.mic",
                        iconColor: .mindSyncAccent,
                        title: NSLocalizedString("settings.affirmations", comment: ""),
                        footer: NSLocalizedString("settings.affirmationsDescription", comment: "")
                    ) {
                        VStack(spacing: AppConstants.Spacing.md) {
                            if let url = preferences.selectedAffirmationURL {
                                Text(url.lastPathComponent)
                                    .font(AppConstants.Typography.body)
                                    .foregroundColor(.mindSyncPrimaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(NSLocalizedString("settings.affirmationNone", comment: ""))
                                    .font(AppConstants.Typography.caption)
                                    .foregroundColor(.mindSyncSecondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Button(NSLocalizedString("settings.affirmationSelect", comment: "")) {
                                showingAffirmationImporter = true
                            }
                            .frame(maxWidth: .infinity)
                            
                            if preferences.selectedAffirmationURL != nil {
                                Button(NSLocalizedString("settings.affirmationRemove", comment: ""), role: .destructive) {
                                    if let url = preferences.selectedAffirmationURL {
                                        try? FileManager.default.removeItem(at: url)
                                    }
                                    preferences.selectedAffirmationURL = nil
                                    preferences.save()
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Session Settings
                    SettingsCard(
                        icon: "clock.fill",
                        iconColor: .mindSyncInfo,
                        title: NSLocalizedString("settings.session", comment: ""),
                        footer: NSLocalizedString("settings.sessionDescription", comment: "")
                    ) {
                        VStack(spacing: AppConstants.Spacing.md) {
                            Toggle(NSLocalizedString("settings.quickAnalysis", comment: ""), isOn: Binding(
                                get: { preferences.quickAnalysisEnabled },
                                set: { newValue in
                                    preferences.quickAnalysisEnabled = newValue
                                    preferences.save()
                                }
                            ))
                            .accessibilityIdentifier("settings.quickAnalysisToggle")
                            
                            Picker(NSLocalizedString("settings.maxDuration", comment: ""), selection: Binding(
                                get: { preferences.maxSessionDuration },
                                set: { newValue in
                                    preferences.maxSessionDuration = newValue
                                    preferences.save()
                                }
                            )) {
                                Text(NSLocalizedString("settings.duration.unlimited", comment: ""))
                                    .tag(TimeInterval?.none)
                                Text(NSLocalizedString("settings.duration.5min", comment: ""))
                                    .tag(TimeInterval?(300))
                                Text(NSLocalizedString("settings.duration.10min", comment: ""))
                                    .tag(TimeInterval?(600))
                                Text(NSLocalizedString("settings.duration.15min", comment: ""))
                                    .tag(TimeInterval?(900))
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Audio Settings
                    SettingsCard(
                        icon: "waveform.circle",
                        iconColor: .mindSyncAccent,
                        title: NSLocalizedString("settings.audio", comment: ""),
                        footer: NSLocalizedString("settings.audioDescription", comment: "")
                    ) {
                        NavigationLink {
                            LatencyCalibrationView()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("settings.latencyCalibration", comment: ""))
                                        .font(AppConstants.Typography.body)
                                    
                                    Text(String(format: NSLocalizedString("settings.latencyCalibration.current", comment: ""), Int(preferences.audioLatencyOffset * 1000)))
                                        .font(.caption)
                                        .foregroundColor(.mindSyncSecondaryText)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: AppConstants.IconSize.small))
                                    .foregroundColor(.mindSyncSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // History
                    SettingsCard(
                        icon: "clock.arrow.circlepath",
                        iconColor: .mindSyncInfo,
                        title: NSLocalizedString("settings.history", comment: "")
                    ) {
                        Button {
                            showingHistory = true
                        } label: {
                            HStack {
                                Text(NSLocalizedString("settings.history", comment: ""))
                                    .font(AppConstants.Typography.body)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: AppConstants.IconSize.small))
                                    .foregroundColor(.mindSyncSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    
                    // Intensity
                    SettingsCard(
                        icon: "slider.horizontal.3",
                        iconColor: .mindSyncAccent,
                        title: NSLocalizedString("settings.intensity", comment: ""),
                        footer: NSLocalizedString("settings.intensityDescription", comment: "")
                    ) {
                        VStack(spacing: AppConstants.Spacing.md) {
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
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                }
                .padding(.vertical, AppConstants.Spacing.lg)
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

// MARK: - Settings Card Component

private struct SettingsCard<Content: View>: View {
    let icon: String?
    let iconColor: Color?
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content
    
    init(
        icon: String? = nil,
        iconColor: Color? = nil,
        title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.footer = footer
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
            // Header
            HStack(spacing: AppConstants.Spacing.sm) {
                if let icon = icon, let iconColor = iconColor {
                    Image(systemName: icon)
                        .font(.system(size: AppConstants.IconSize.small, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(AppConstants.Typography.headline)
                    .foregroundColor(.mindSyncPrimaryText)
            }
            
            // Content
            content()
            
            // Footer
            if let footer = footer {
                Text(footer)
                    .font(AppConstants.Typography.caption)
                    .foregroundColor(.mindSyncSecondaryText)
                    .padding(.top, AppConstants.Spacing.xs)
            }
        }
        .padding(AppConstants.Spacing.lg)
        .mindSyncCardStyle()
    }
}

#Preview {
    SettingsView()
}

