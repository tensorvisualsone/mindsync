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
            VStack(spacing: 24) {
                Text("MindSync")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("home.title")

                Text("Audio-synchronisiertes Stroboskop für veränderte Bewusstseinszustände.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Button("Start Session") {
                    showingSourceSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Show current mode
                VStack(spacing: 8) {
                    Text("Current Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: preferences.preferredMode.iconName)
                        Text(preferences.preferredMode.displayName)
                            .font(.headline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
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
