import SwiftUI
import MediaPlayer

struct HomeView: View {
    @State private var showingSourceSelection = false
    @State private var selectedMediaItem: MPMediaItem?
    @State private var showingSession = false
    @State private var isMicrophoneSession = false
    @State private var showingModeSelection = false
    @State private var showingSettings = false
    @State private var preferences = UserPreferences.load()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                    // App Header with Logo
                    VStack(spacing: AppConstants.Spacing.md) {
                        // App Icon/Logo
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.mindSyncAccent.opacity(0.4),
                                            Color.mindSyncAccent.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            // Icon background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.mindSyncAccent.opacity(0.3),
                                            Color.mindSyncTheta.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            // Brain/Wave icon
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .padding(.top, AppConstants.Spacing.lg)
                        .accessibilityHidden(true)
                        
                        VStack(spacing: AppConstants.Spacing.xs) {
                            Text("MindSync")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .accessibilityIdentifier("home.title")
                            
                            Text(NSLocalizedString("home.subtitle", comment: ""))
                                .font(AppConstants.Typography.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.mindSyncSecondaryText)
                                .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
                        }
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
                        selectedMediaItem = item
                        isMicrophoneSession = false
                        showingSourceSelection = false
                        showingSession = true
                    },
                    onMicrophoneSelected: {
                        selectedMediaItem = nil
                        isMicrophoneSession = true
                        showingSourceSelection = false
                        showingSession = true
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
            .fullScreenCover(isPresented: $showingSession) {
                if isMicrophoneSession {
                    SessionView(song: nil, isMicrophoneMode: true)
                } else if let mediaItem = selectedMediaItem {
                    SessionView(song: mediaItem, isMicrophoneMode: false)
                } else {
                    VStack(spacing: 16) {
                        Text(NSLocalizedString("session.unableToStart", comment: ""))
                            .font(.headline)
                        Text(NSLocalizedString("session.noMediaItem", comment: ""))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button(NSLocalizedString("common.dismiss", comment: "")) {
                            showingSession = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
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
