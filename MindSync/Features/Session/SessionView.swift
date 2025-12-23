import SwiftUI
import MediaPlayer

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let mediaItem: MPMediaItem?
    
    init(song: MPMediaItem? = nil) {
        self.mediaItem = song
    }
    
    var body: some View {
        ZStack {
            // Dark background for session
            Color.black.ignoresSafeArea()
            
            switch viewModel.state {
            case .idle:
                // Should not be here - navigated from HomeView
                EmptyView()
                
            case .analyzing:
                if let progress = viewModel.analysisProgress {
                    AnalysisProgressView(progress: progress)
                }
                
            case .running:
                runningSessionView
                
            case .paused:
                pausedSessionView
                
            case .error:
                errorView
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if let mediaItem = mediaItem {
                await viewModel.startSession(with: mediaItem)
            }
        }
    }
    
    // MARK: - Running Session View
    
    private var runningSessionView: some View {
        VStack(spacing: 32) {
            // Track info
            if let track = viewModel.currentTrack {
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    if let artist = track.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let script = viewModel.currentScript {
                        Text("\(Int(script.targetFrequency)) Hz • \(Int(track.bpm)) BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Stop button (large, for easy operation)
            Button(action: {
                viewModel.stopSession()
                dismiss()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 60))
                    Text("Stoppen")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.red.opacity(0.3))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Paused Session View
    
    private var pausedSessionView: some View {
        VStack(spacing: 24) {
            Text("Pausiert")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Button("Fortsetzen") {
                // TODO: Resume functionality
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
            .opacity(0.5)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Zurück") {
                viewModel.reset()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    SessionView()
}
