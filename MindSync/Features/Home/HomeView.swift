import SwiftUI
import MediaPlayer

/// Represents the type of session to start
enum SessionType: Identifiable {
    case microphone
    case mediaItem(MPMediaItem)
    case audioFile(URL)
    
    var id: String {
        switch self {
        case .microphone:
            return "microphone"
        case .mediaItem(let item):
            return "media-\(item.persistentID)"
        case .audioFile(let url):
            return "file-\(url.absoluteString)"
        }
    }
}

struct HomeView: View {
    @State private var showingSourceSelection = false
    @State private var sessionToStart: SessionType?
    @State private var showingModeSelection = false
    @State private var showingSettings = false
    @State private var preferences = UserPreferences.load()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                    VStack(spacing: AppConstants.Spacing.sm) {
                        Text("MindSync")
                            .font(AppConstants.Typography.largeTitle)
                            .accessibilityIdentifier("home.title")
                        
                        Text(NSLocalizedString("home.subtitle", comment: ""))
                            .font(AppConstants.Typography.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.mindSyncSecondaryText)
                            .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
                    }
                    
                    LargeButton(
                        title: NSLocalizedString("home.startSession", comment: ""),
                        subtitle: NSLocalizedString("home.startSessionHint", comment: ""),
                        systemImage: "sparkles",
                        style: .filled(.mindSyncAccent)
                    ) {
                        HapticFeedback.light()
                        showingSourceSelection = true
                    }
                    .accessibilityIdentifier("home.startSessionButton")
                    
                    HomeStatusGrid(
                        preferences: preferences,
                        modeAction: {
                            HapticFeedback.light()
                            showingModeSelection = true
                        },
                        settingsAction: {
                            HapticFeedback.light()
                            showingSettings = true
                        }
                    )
                }
                .padding(AppConstants.Spacing.md)
            }
            .navigationTitle(NSLocalizedString("common.home", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticFeedback.light()
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .accessibilityLabel(NSLocalizedString("settings.title", comment: ""))
                    }
                }
            }
            .onAppear {
                // Reload preferences when view appears
                preferences = UserPreferences.load()
            }
            .sheet(isPresented: $showingSourceSelection) {
                SourceSelectionView(
                    onSongSelected: { item in
                        showingSourceSelection = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sessionToStart = .mediaItem(item)
                        }
                    },
                    onFileSelected: { url in
                        print("HomeView: onFileSelected called with: \(url.lastPathComponent)")
                        showingSourceSelection = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sessionToStart = .audioFile(url)
                        }
                    },
                    onMicrophoneSelected: {
                        showingSourceSelection = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            sessionToStart = .microphone
                        }
                    }
                )
            }
            .sheet(isPresented: $showingModeSelection) {
                ModeSelectionView(
                    selectedMode: Binding(
                        get: { preferences.preferredMode },
                        set: { newMode in
                            preferences.preferredMode = newMode
                            preferences.save()
                        }
                    ),
                    onModeSelected: { _ in
                        // Reload preferences after mode change
                        preferences = UserPreferences.load()
                    }
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .onDisappear {
                        // Reload preferences after settings changes
                        preferences = UserPreferences.load()
                    }
            }
            .fullScreenCover(item: $sessionToStart) { session in
                switch session {
                case .microphone:
                    SessionView(song: nil, isMicrophoneMode: true)
                case .mediaItem(let item):
                    SessionView(song: item, isMicrophoneMode: false)
                case .audioFile(let url):
                    SessionView(audioFileURL: url, isMicrophoneMode: false)
                }
            }
        }
        .mindSyncBackground()
    }
}

private struct HomeStatusGrid: View {
    let preferences: UserPreferences
    let modeAction: () -> Void
    let settingsAction: () -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            Button(action: modeAction) {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                    Text(NSLocalizedString("home.currentMode", comment: ""))
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncSecondaryText)
                    HStack {
                        Label(preferences.preferredMode.displayName, systemImage: preferences.preferredMode.iconName)
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.mindSyncSecondaryText)
                    }
                }
                .padding()
                .mindSyncCardStyle()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("modeSelection.currentMode", comment: ""), preferences.preferredMode.displayName))
            .accessibilityHint(NSLocalizedString("modeSelection.changeMode", comment: ""))
            
            HStack(spacing: AppConstants.Spacing.md) {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(NSLocalizedString("settings.lightSource", comment: ""))
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncSecondaryText)
                    Text(preferences.preferredLightSource.displayName)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .mindSyncCardStyle()
                
                Button(action: settingsAction) {
                    VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                        Text(NSLocalizedString("settings.title", comment: ""))
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                        Text(NSLocalizedString("common.open", comment: ""))
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card, style: .continuous)
                            .fill(Color(.secondarySystemBackground).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 16)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    HomeView()
}
