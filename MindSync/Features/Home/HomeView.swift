import SwiftUI
import MediaPlayer

/// Represents the type of session to start
enum SessionType: Identifiable {
    case mediaItem(MPMediaItem)
    case audioFile(URL)
    case dmnShutdown
    
    var id: String {
        switch self {
        case .mediaItem(let item):
            return "media-\(item.persistentID)"
        case .audioFile(let url):
            return "file-\(url.absoluteString)"
        case .dmnShutdown:
            return "dmn-shutdown"
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
                VStack(spacing: AppConstants.Spacing.xl) {
                    // Hero Section
                    HeroSection()
                        .padding(.top, AppConstants.Spacing.lg)
                    
                    // Start Session Button
                    LargeButton(
                        title: NSLocalizedString("home.startSession", comment: ""),
                        subtitle: NSLocalizedString("home.startSessionHint", comment: ""),
                        systemImage: "sparkles",
                        style: .filled(.mindSyncAccent)
                    ) {
                        HapticFeedback.light()
                        // Fixed-script modes start automatically without audio selection
                        // Only cinematic mode requires user-selected audio
                        if preferences.preferredMode.usesFixedScript {
                            // For fixed-script sessions, we reuse `.dmnShutdown` as a sentinel value
                            // meaning "start the current preferred fixed session"; SessionView resolves
                            // the actual fixed mode based on `preferences.preferredMode`.
                            sessionToStart = .dmnShutdown
                        } else {
                            // Cinematic mode requires audio selection
                            showingSourceSelection = true
                        }
                    }
                    .accessibilityIdentifier("home.startSessionButton")
                    
                    // Status Grid
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
                case .mediaItem(let item):
                    SessionView(song: item)
                case .audioFile(let url):
                    SessionView(audioFileURL: url)
                case .dmnShutdown:
                    SessionView(dmnShutdown: true)
                }
            }
        }
        .mindSyncBackground()
    }
}

// MARK: - Hero Section

private struct HeroSection: View {
    var body: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            // App Icon/Emblem
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.mindSyncAccent.opacity(0.2),
                                Color.mindSyncAccent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform.path")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.mindSyncAccent, Color.mindSyncAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Title
            Text("MindSync")
                .font(AppConstants.Typography.largeTitle)
                .accessibilityIdentifier("home.title")
            
            // Subtitle
            Text(NSLocalizedString("home.subtitle", comment: ""))
                .font(AppConstants.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.mindSyncSecondaryText)
                .padding(.horizontal, AppConstants.Spacing.md)
        }
    }
}

// MARK: - Status Grid

private struct HomeStatusGrid: View {
    let preferences: UserPreferences
    let modeAction: () -> Void
    let settingsAction: () -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.md) {
            // Mode Card
            StatusCard(
                icon: preferences.preferredMode.iconName,
                iconColor: preferences.preferredMode.themeColor,
                title: NSLocalizedString("home.currentMode", comment: ""),
                value: preferences.preferredMode.displayName,
                action: modeAction
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: NSLocalizedString("modeSelection.currentMode", comment: ""), preferences.preferredMode.displayName))
            .accessibilityHint(NSLocalizedString("modeSelection.changeMode", comment: ""))
            
            // Light Source and Settings Cards
            HStack(spacing: AppConstants.Spacing.md) {
                StatusCard(
                    icon: "flashlight.on.fill",
                    iconColor: .mindSyncFlashlight,
                    title: NSLocalizedString("settings.lightSource", comment: ""),
                    value: preferences.preferredLightSource.displayName,
                    action: nil
                )
                
                StatusCard(
                    icon: "gearshape.fill",
                    iconColor: .mindSyncSecondaryText,
                    title: NSLocalizedString("settings.title", comment: ""),
                    value: NSLocalizedString("common.open", comment: ""),
                    action: settingsAction
                )
            }
        }
    }
}

// MARK: - Status Card Component

private struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: AppConstants.IconSize.medium, weight: .semibold))
                        .foregroundColor(iconColor)
                    
                    Spacer()
                    
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: AppConstants.IconSize.small, weight: .semibold))
                            .foregroundColor(.mindSyncSecondaryText)
                    }
                }
                
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(title)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncSecondaryText)
                    
                    Text(value)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(.mindSyncPrimaryText)
                        .lineLimit(2)
                }
            }
            .padding(AppConstants.Spacing.md)
            .mindSyncCardStyle()
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

#Preview {
    HomeView()
}
