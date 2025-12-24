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
            VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                Text("MindSync")
                    .font(AppConstants.Typography.largeTitle)
                    .accessibilityIdentifier("home.title")

                Text(NSLocalizedString("home.subtitle", comment: ""))
                    .font(AppConstants.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.mindSyncSecondaryText)
                    .padding(.horizontal, AppConstants.Spacing.horizontalPadding)

                Button(NSLocalizedString("home.startSession", comment: "")) {
                    showingSourceSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(NSLocalizedString("home.startSession", comment: ""))
                .accessibilityHint("Öffnet die Auswahl der Audioquelle")
                
                // Show current mode (tappable)
                Button(action: {
                    showingModeSelection = true
                }) {
                    VStack(spacing: AppConstants.Spacing.sm) {
                        Text(NSLocalizedString("home.currentMode", comment: "Label for displaying the currently selected mode on the home screen"))
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
                        HStack(spacing: AppConstants.Spacing.sm) {
                            Image(systemName: preferences.preferredMode.iconName)
                                .font(.system(size: AppConstants.IconSize.medium))
                                .foregroundColor(preferences.preferredMode.themeColor)
                            Text(preferences.preferredMode.displayName)
                                .font(AppConstants.Typography.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: AppConstants.IconSize.small))
                                .foregroundColor(.mindSyncSecondaryText)
                        }
                    }
                    .padding(AppConstants.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color.mindSyncCardBackground())
                    .cornerRadius(AppConstants.CornerRadius.card)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: NSLocalizedString("modeSelection.currentMode", comment: ""), preferences.preferredMode.displayName))
                .accessibilityHint(NSLocalizedString("modeSelection.changeMode", comment: ""))
            }
            .padding(AppConstants.Spacing.md)
            .navigationTitle(NSLocalizedString("common.home", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
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
    }
}

#Preview {
    HomeView()
}
