import SwiftUI
import MediaPlayer

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let mediaItem: MPMediaItem?
    let isMicrophoneMode: Bool
    
    init(song: MPMediaItem? = nil, isMicrophoneMode: Bool = false) {
        self.mediaItem = song
        self.isMicrophoneMode = isMicrophoneMode
    }
    
    var body: some View {
        ZStack {
            // Background: Use screen controller color if available, otherwise black
            if let screenController = viewModel.screenController, screenController.isActive {
                screenController.currentColor
                    .ignoresSafeArea()
                    .animation(.linear(duration: 0.08), value: screenController.currentColor)
            } else {
                Color.black.ignoresSafeArea()
            }
            
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
            
            // Thermal warning banner overlay
            VStack {
                SafetyBanner(warningLevel: viewModel.thermalWarningLevel)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.thermalWarningLevel)
        }
        .preferredColorScheme(.dark)
        .task {
            if isMicrophoneMode {
                await viewModel.startMicrophoneSession()
            } else if let mediaItem = mediaItem {
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
            
            // Pause/Resume and Stop buttons
            HStack(spacing: 16) {
                // Pause/Resume button
                Button(action: {
                    if viewModel.state == .running {
                        viewModel.pauseSession()
                    } else if viewModel.state == .paused {
                        viewModel.resumeSession()
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.state == .running ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                        Text(viewModel.state == .running ? "Pausieren" : "Fortsetzen")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.state == .running ? "Sitzung pausieren" : "Sitzung fortsetzen")
                
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
            }
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
                viewModel.resumeSession()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Stoppen") {
                viewModel.stopSession()
                dismiss()
            }
            .buttonStyle(.bordered)
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
