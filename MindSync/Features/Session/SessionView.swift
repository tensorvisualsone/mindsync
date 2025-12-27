import SwiftUI
import MediaPlayer

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let mediaItem: MPMediaItem?
    let audioFileURL: URL?
    let isMicrophoneMode: Bool
    
    init(song: MPMediaItem? = nil, audioFileURL: URL? = nil, isMicrophoneMode: Bool = false) {
        self.mediaItem = song
        self.audioFileURL = audioFileURL
        self.isMicrophoneMode = isMicrophoneMode
    }
    
    var body: some View {
        ZStack {
            // Background: Use screen controller color if available, otherwise black
            if let screenController = viewModel.screenController, screenController.isActive {
                ScreenStrobeView(controller: screenController)
            } else {
                Color.black.ignoresSafeArea()
            }
            
            switch viewModel.state {
            case .idle:
                // Should not be here - navigated from HomeView
                EmptyView()
                
            case .analyzing:
                if let progress = viewModel.analysisProgress {
                    AnalysisProgressView(progress: progress) {
                        viewModel.cancelAnalysis()
                    }
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
            } else if let audioFileURL = audioFileURL {
                await viewModel.startSession(with: audioFileURL)
            }
        }
    }
    
    // MARK: - Running Session View
    
    private var runningSessionView: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            if let session = viewModel.currentSession {
                SessionTrackInfoView(
                    track: viewModel.currentTrack,
                    script: viewModel.currentScript,
                    session: session,
                    currentFrequency: viewModel.currentFrequency
                )
                .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
            }
            
            if shouldShowPlaybackProgress {
                playbackProgressSection
                    .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
            }
            
            if let affirmationStatus = viewModel.affirmationStatus {
                AffirmationStatusView(status: affirmationStatus)
                    .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
            }
            
            Spacer()
            
            SessionControlsView(
                state: viewModel.state,
                onTogglePause: {
                    if viewModel.state == .running {
                        viewModel.pauseSession()
                    } else if viewModel.state == .paused {
                        viewModel.resumeSession()
                    }
                },
                onStop: {
                    viewModel.stopSession()
                    dismiss()
                }
            )
            .accessibilityIdentifier("session.controls")
            
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
                viewModel.resumeSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("session.resumeButton")
            .accessibilityLabel(NSLocalizedString("session.resume", comment: ""))
            
            Button(NSLocalizedString("session.stop", comment: "")) {
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

/// Dedicated view for screen strobe to isolate high-frequency updates
struct ScreenStrobeView: View {
    @ObservedObject var controller: ScreenController
    
    var body: some View {
        controller.currentColor
            .ignoresSafeArea()
            .animation(.linear(duration: 0.08), value: controller.currentColor)
    }
}

private extension SessionView {
    var shouldShowPlaybackProgress: Bool {
        viewModel.currentSession?.audioSource == .localFile
    }
    
    var playbackProgressSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
            ProgressView(value: viewModel.playbackProgress)
                .progressViewStyle(.linear)
                .tint(.mindSyncAccent)
            
            Text(viewModel.playbackTimeLabel)
                .font(AppConstants.Typography.caption)
                .foregroundStyle(.white.opacity(AppConstants.Opacity.secondary))
        }
    }
}

private struct SessionTrackInfoView: View {
    let track: AudioTrack?
    let script: LightScript?
    let session: Session
    let currentFrequency: Double?
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.sm) {
            HStack(spacing: AppConstants.Spacing.sm) {
                Image(systemName: session.audioSource == .microphone ? "waveform" : "music.note")
                    .font(.system(size: AppConstants.IconSize.medium, weight: .semibold))
                    .foregroundColor(session.audioSource == .microphone ? .mindSyncWarning : .mindSyncAccent)
                
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(track?.title ?? NSLocalizedString("session.liveAudio", comment: ""))
                        .font(AppConstants.Typography.title2)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    if let artist = track?.artist {
                        Text(artist)
                            .font(AppConstants.Typography.subheadline)
                            .foregroundStyle(.white.opacity(AppConstants.Opacity.secondary))
                    } else if session.audioSource == .microphone {
                        Text(NSLocalizedString("session.microphone", comment: ""))
                            .font(AppConstants.Typography.subheadline)
                            .foregroundStyle(.white.opacity(AppConstants.Opacity.secondary))
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: AppConstants.Spacing.sm) {
                ModeChip(
                    icon: session.mode.iconName,
                    text: session.mode.displayName,
                    color: session.mode.themeColor
                )
                
                if let script = script, let bpm = track?.bpm {
                    let frequency = currentFrequency ?? script.targetFrequency
                    let frequencyText = String(format: NSLocalizedString("session.frequencyBpm", comment: ""), Int(frequency), Int(bpm))
                    ModeChip(
                        icon: "metronome.fill",
                        text: frequencyText,
                        color: .mint.opacity(0.8)
                    )
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(AppConstants.Spacing.md)
        .mindSyncCardStyle()
    }
}

private struct ModeChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: AppConstants.IconSize.small, weight: .semibold))
            Text(text)
                .font(AppConstants.Typography.caption)
        }
        .padding(.vertical, AppConstants.Spacing.xs)
        .padding(.horizontal, AppConstants.Spacing.sm)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.CornerRadius.small, style: .continuous))
    }
}

private struct AffirmationStatusView: View {
    let status: String
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.sm) {
            Image(systemName: "waveform.and.mic")
                .foregroundColor(.mindSyncInfo)
            Text(status)
                .font(AppConstants.Typography.caption)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(AppConstants.Spacing.md)
        .mindSyncCardStyle()
    }
}

#Preview {
    SessionView()
}
