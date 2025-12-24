import SwiftUI
import MediaPlayer

struct HomeView: View {
    @State private var showingSourceSelection = false
    @State private var selectedMediaItem: MPMediaItem?
    @State private var showingSession = false
    @State private var isMicrophoneSession = false
    @State private var preferences = UserPreferences.load()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                Text("MindSync")
                    .font(AppConstants.Typography.largeTitle)
                    .accessibilityIdentifier("home.title")

                Text("Audio-synchronisiertes Stroboskop für veränderte Bewusstseinszustände.")
                    .font(AppConstants.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.mindSyncSecondaryText)
                    .padding(.horizontal, AppConstants.Spacing.horizontalPadding)

                Button("Start Session") {
                    showingSourceSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Session starten")
                .accessibilityHint("Öffnet die Auswahl der Audioquelle")
                
                // Show current mode
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
                    }
                }
                .padding(AppConstants.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.mindSyncCardBackground())
                .cornerRadius(AppConstants.CornerRadius.card)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Aktueller Modus: \(preferences.preferredMode.displayName)")
            }
            .padding(AppConstants.Spacing.md)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
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
            .fullScreenCover(isPresented: $showingSession) {
                if isMicrophoneSession {
                    SessionView(song: nil, isMicrophoneMode: true)
                } else if let mediaItem = selectedMediaItem {
                    SessionView(song: mediaItem, isMicrophoneMode: false)
                } else {
                    VStack(spacing: 16) {
                        Text("Unable to start session")
                            .font(.headline)
                        Text("No media item was selected. Please dismiss and try starting a new session.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Dismiss") {
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
