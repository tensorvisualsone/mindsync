import SwiftUI
import MediaPlayer

struct HomeView: View {
    @State private var showingSourceSelection = false
    @State private var selectedMediaItem: MPMediaItem?
    @State private var showingSession = false
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
                SourceSelectionView { item in
                    selectedMediaItem = item
                    showingSourceSelection = false
                    showingSession = true
                }
            }
            .fullScreenCover(isPresented: $showingSession) {
                if let mediaItem = selectedMediaItem {
                    SessionView(song: mediaItem)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
