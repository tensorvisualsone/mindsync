import SwiftUI
import MediaPlayer

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let mediaItem: MPMediaItem?
    let audioFileURL: URL?
    let dmnShutdown: Bool
    
    /// Height of the status banner including padding (used for offset calculations)
    /// Calculated from: top padding (8) + banner vertical padding (sm + xs = 12) + content height (icon ~24 or text ~20)
    /// Note: Uses max of icon and text heights, accounts for potential text wrapping with conservative estimate
    private static var statusBannerHeight: CGFloat {
        let topPadding: CGFloat = 8
        let bannerVerticalPadding: CGFloat = AppConstants.Spacing.sm + AppConstants.Spacing.xs // 8 + 4 = 12
        let iconHeight: CGFloat = AppConstants.IconSize.medium // 24
        // Subheadline font typically ~20pt, but allow for text wrapping
        let estimatedTextHeight: CGFloat = 20
        let contentHeight = max(iconHeight, estimatedTextHeight) // 24
        
        return topPadding + bannerVerticalPadding + contentHeight // 8 + 12 + 24 = 44
    }
    
    init(song: MPMediaItem? = nil, audioFileURL: URL? = nil, dmnShutdown: Bool = false) {
        self.mediaItem = song
        self.audioFileURL = audioFileURL
        self.dmnShutdown = dmnShutdown
    }
    
    var body: some View {
        ZStack {
            // Background: Always black for flashlight mode
            Color.black.ignoresSafeArea()
            
            switch viewModel.state {
            case .idle:
                // Show loading state while session is being initialized
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("analysis.loading", comment: "Loading audio..."))
                        .font(AppConstants.Typography.subheadline)
                        .foregroundColor(.mindSyncSecondaryText)
                        .padding(.top, AppConstants.Spacing.md)
                }
                
            case .analyzing:
                if let progress = viewModel.analysisProgress {
                    AnalysisProgressView(progress: progress) {
                        viewModel.cancelAnalysis()
                    }
                } else {
                    // Fallback if progress is nil
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("analysis.analyzing", comment: "Analyzing..."))
                            .font(AppConstants.Typography.subheadline)
                            .foregroundColor(.mindSyncSecondaryText)
                            .padding(.top, AppConstants.Spacing.md)
                    }
                }
                
            case .running:
                runningSessionView
                
            case .paused:
                pausedSessionView
                
            case .error:
                errorView
            }
            
            // Status message banner overlay (non-error notifications)
            if let statusMessage = viewModel.statusMessage {
                VStack {
                    StatusBanner(message: statusMessage)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.statusMessage)
            }
            
            // Thermal warning banner overlay
            VStack {
                SafetyBanner(warningLevel: viewModel.thermalWarningLevel)
                    .padding(.horizontal)
                    .padding(.top, viewModel.statusMessage != nil ? Self.statusBannerHeight : 8)
                
                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.thermalWarningLevel)
        }
        .preferredColorScheme(.dark)
        .task {
            // Start the session immediately when view appears
            // Use Task to ensure it runs even if the view is already loaded
            // Only start if state is still idle to prevent race conditions
            guard viewModel.state == .idle else { return }
            
            Task { @MainActor in
                // dmnShutdown flag takes precedence over preferences
                if dmnShutdown {
                    // DMN-Shutdown mode: Start automatically without audio selection
                    await viewModel.startDMNShutdownSession()
                } else {
                    // Check if we should start a fixed session based on preferred mode
                    let preferences = UserPreferences.load()
                    let mode = preferences.preferredMode
                    
                    if mode.usesFixedScript {
                        // Fixed-script modes: Start automatically without audio selection
                        await viewModel.startFixedSession(mode: mode)
                    } else if let mediaItem = mediaItem {
                        // Cinematic mode with media item
                        await viewModel.startSession(with: mediaItem)
                    } else if let audioFileURL = audioFileURL {
                        // Cinematic mode with audio file
                        await viewModel.startSession(with: audioFileURL)
                    } else {
                        // No media item or file URL - show error
                        viewModel.errorMessage = NSLocalizedString("session.noMediaItem", comment: "")
                        viewModel.state = .error
                    }
                }
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
                .foregroundStyle(Color.mindSyncWarning)
            
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
    
    // Helper to determine if frequency chip should be shown
    private var shouldShowFrequency: Bool {
        guard let _ = script, let currentFrequency = currentFrequency, currentFrequency > 0 else {
            return false
        }
        
        // For fixed-script modes, always show frequency (they use frequency overrides)
        if session.mode.usesFixedScript {
            return true
        }
        
        // For other modes (cinematic), only show if it differs significantly from BPM (indicating ramping)
        if let bpm = track?.bpm {
            return abs(Int(bpm) - Int(currentFrequency)) >= 2
        }
        
        return false
    }
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.lg) {
            // Track Info
            HStack(spacing: AppConstants.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.mindSyncAccent.opacity(0.3),
                                    Color.mindSyncAccent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.mindSyncAccent, Color.mindSyncAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Track Details
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(track?.title ?? "")
                        .font(AppConstants.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    if let artist = track?.artist {
                        Text(artist)
                            .font(AppConstants.Typography.body)
                            .foregroundStyle(.white.opacity(AppConstants.Opacity.secondary))
                    }
                }
                
                Spacer()
            }
            
            // Mode and Frequency Chips
            HStack(spacing: AppConstants.Spacing.sm) {
                ModeChip(
                    icon: session.mode.iconName,
                    text: session.mode.displayName,
                    color: session.mode.themeColor
                )
                
                // Show frequency indicator for DMN-Shutdown mode or if frequency differs from BPM
                if shouldShowFrequency, let currentFrequency = currentFrequency {
                    ModeChip(
                        icon: "waveform",
                        text: "\(Int(currentFrequency)) Hz",
                        color: .mint.opacity(0.8)
                    )
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(AppConstants.Spacing.lg)
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
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.CornerRadius.small, style: .continuous))
    }
}

private struct AffirmationStatusView: View {
    let status: String
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.sm) {
            Image(systemName: "waveform.and.mic")
                .foregroundStyle(Color.mindSyncInfo)
            Text(status)
                .font(AppConstants.Typography.caption)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(AppConstants.Spacing.md)
        .mindSyncCardStyle()
    }
}

private struct StatusBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.md) {
            // Info icon (non-error)
            Image(systemName: "info.circle.fill")
                .font(.system(size: AppConstants.IconSize.medium, weight: .semibold))
                .foregroundStyle(Color.mindSyncInfo)
                .accessibilityHidden(true)
            
            // Status message
            Text(message)
                .font(AppConstants.Typography.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, AppConstants.Spacing.md)
        .padding(.vertical, AppConstants.Spacing.sm + AppConstants.Spacing.xs)
        .background(Color.mindSyncInfo.opacity(AppConstants.Opacity.bannerBackground))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                .stroke(Color.mindSyncInfo.opacity(AppConstants.Opacity.bannerBorder), lineWidth: AppConstants.Border.standard)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium))
    }
}

#Preview {
    SessionView()
}
