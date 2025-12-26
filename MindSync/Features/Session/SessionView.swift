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
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            // Track info
            if let track = viewModel.currentTrack {
                VStack(spacing: AppConstants.Spacing.sm) {
                    Text(track.title)
                        .font(AppConstants.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    if let artist = track.artist {
                        Text(artist)
                            .font(AppConstants.Typography.subheadline)
                            .foregroundStyle(.white.opacity(AppConstants.Opacity.secondary))
                            .multilineTextAlignment(.center)
                    }
                    
                    if let script = viewModel.currentScript {
                        Text("\(Int(script.targetFrequency)) Hz • \(Int(track.bpm)) BPM")
                            .font(AppConstants.Typography.caption)
                            .foregroundStyle(.white.opacity(AppConstants.Opacity.tertiary))
                            .padding(.top, AppConstants.Spacing.xs)
                    }
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Pause/Resume and Stop buttons
            HStack(spacing: AppConstants.Spacing.elementSpacing) {
                // Pause/Resume button
                Button(action: {
                    HapticFeedback.medium()
                    if viewModel.state == .running {
                        viewModel.pauseSession()
                    } else if viewModel.state == .paused {
                        viewModel.resumeSession()
                    }
                }) {
                    VStack(spacing: AppConstants.Spacing.sm) {
                        Image(systemName: viewModel.state == .running ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: AppConstants.IconSize.large))
                        Text(viewModel.state == .running ? NSLocalizedString("session.pause", comment: "") : NSLocalizedString("session.resume", comment: ""))
                            .font(AppConstants.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppConstants.Spacing.lg)
                    .frame(minHeight: AppConstants.TouchTarget.large)
                    .background(Color.mindSyncButtonBackground(color: .blue))
                    .cornerRadius(AppConstants.CornerRadius.button)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.state == .running ? NSLocalizedString("session.pauseAccessibility", comment: "") : NSLocalizedString("session.resumeAccessibility", comment: ""))
                .accessibilityIdentifier("session.pauseResumeButton")
                
                // Stop button (large, for easy operation)
                Button(action: {
                    HapticFeedback.heavy()
                    viewModel.stopSession()
                    dismiss()
                }) {
                VStack(spacing: AppConstants.Spacing.sm) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: AppConstants.IconSize.extraLarge))
                    Text(NSLocalizedString("session.stop", comment: ""))
                        .font(AppConstants.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppConstants.Spacing.lg)
                .frame(minHeight: AppConstants.TouchTarget.large)
                .background(Color.mindSyncButtonBackground(color: .red))
                .cornerRadius(AppConstants.CornerRadius.button)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session.stopButton")
                .accessibilityLabel(NSLocalizedString("session.stopAccessibility", comment: ""))
            }
            .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
            
            Spacer()
        }
        .padding(AppConstants.Spacing.md)
    }
    
    // MARK: - Paused Session View
    
    private var pausedSessionView: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            Text(NSLocalizedString("session.paused", comment: ""))
                .font(AppConstants.Typography.title)
                .foregroundStyle(.white)
                .accessibilityIdentifier("session.pausedLabel")
            
            Button(NSLocalizedString("session.resume", comment: "")) {
                HapticFeedback.medium()
                viewModel.resumeSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("session.resumeButton")
            .accessibilityLabel(NSLocalizedString("session.resume", comment: ""))
            
            Button(NSLocalizedString("session.stop", comment: "")) {
                HapticFeedback.heavy()
                viewModel.stopSession()
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("session.stopButtonPaused")
            .accessibilityLabel(NSLocalizedString("session.stop", comment: ""))
        }
        .padding(AppConstants.Spacing.md)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: AppConstants.IconSize.extraLarge))
                .foregroundColor(.mindSyncWarning)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppConstants.Typography.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
                    .accessibilityIdentifier("session.errorMessage")
            }
            
            Button(NSLocalizedString("common.back", comment: "")) {
                HapticFeedback.light()
                viewModel.reset()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("session.errorBackButton")
            .accessibilityLabel(NSLocalizedString("common.back", comment: ""))
        }
        .padding(AppConstants.Spacing.md)
    }
}

#Preview {
    SessionView()
}
