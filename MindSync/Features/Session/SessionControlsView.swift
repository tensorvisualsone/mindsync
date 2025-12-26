import SwiftUI

/// Großformatige Session-Steuerung mit Gesten-Support (Tippen, Doppeltipp, Swipe)
struct SessionControlsView: View {
    let state: SessionState
    let onTogglePause: () -> Void
    let onStop: () -> Void
    
    // Optional Hinweistext für den Nutzer
    var hintText: String = NSLocalizedString(
        "session.controls.hint",
        comment: "Hint describing gesture controls while a session is running"
    )
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.elementSpacing) {
            HStack(spacing: AppConstants.Spacing.elementSpacing) {
                LargeButton(
                    title: state == .running
                        ? NSLocalizedString("session.pause", comment: "")
                        : NSLocalizedString("session.resume", comment: ""),
                    systemImage: state == .running ? "pause.circle.fill" : "play.circle.fill",
                    style: .filled(.blue),
                    action: onTogglePause
                )
                .accessibilityLabel(
                    state == .running
                        ? NSLocalizedString("session.pauseAccessibility", comment: "")
                        : NSLocalizedString("session.resumeAccessibility", comment: "")
                )
                .accessibilityIdentifier("session.pauseResumeButton")
                
                LargeButton(
                    title: NSLocalizedString("session.stop", comment: ""),
                    systemImage: "stop.circle.fill",
                    style: .filled(.red),
                    action: onStop
                )
                .accessibilityIdentifier("session.stopButton")
                .accessibilityLabel(NSLocalizedString("session.stopAccessibility", comment: ""))
            }
            
            Text(hintText)
                .font(AppConstants.Typography.caption)
                .foregroundColor(.mindSyncSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
        .mindSyncGestureArea(
            doubleTapAction: {
                HapticFeedback.heavy()
                onStop()
            },
            swipeUpAction: {
                HapticFeedback.medium()
                onTogglePause()
            },
            swipeDownAction: {
                HapticFeedback.heavy()
                onStop()
            }
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SessionControlsView(
            state: .running,
            onTogglePause: {},
            onStop: {}
        )
    }
}

