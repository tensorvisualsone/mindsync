import SwiftUI
import MediaPlayer

struct HomeView: View {
    @State private var showingSourceSelection = false
    @State private var selectedSong: MPMediaItem?
    @State private var showingSession = false
    
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

                Button("Session starten") {
                    showingSourceSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                // Aktueller Modus anzeigen
                let mode = UserPreferences.load().preferredMode
                VStack(spacing: 8) {
                    Text("Aktueller Modus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
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
            .sheet(isPresented: $showingSourceSelection) {
                SourceSelectionView { item in
                    selectedSong = item
                    showingSourceSelection = false
                    showingSession = true
                }
            }
            .fullScreenCover(isPresented: $showingSession) {
                if let song = selectedSong {
                    SessionView(song: song)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
