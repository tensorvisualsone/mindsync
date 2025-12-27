import SwiftUI

/// View for displaying analysis progress
struct AnalysisProgressView: View {
    let progress: AnalysisProgress
    let onCancel: (() -> Void)?
    
    init(progress: AnalysisProgress, onCancel: (() -> Void)? = nil) {
        self.progress = progress
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            // Progress ring
            ProgressRing(progress: progress.progress)
                .frame(width: 120, height: 120)
            
            // Message
            Text(progress.message)
                .font(AppConstants.Typography.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.mindSyncSecondaryText)
                .accessibilityIdentifier("session.analysisMessage")
            
            // Percentage display
            Text("\(Int(progress.progress * 100))%")
                .font(AppConstants.Typography.title2)
                .foregroundColor(.mindSyncPrimaryText)
                .accessibilityIdentifier("session.analysisProgress")
            
            // Cancel button
            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Text(NSLocalizedString("analysis.cancel", comment: ""))
                        .font(AppConstants.Typography.body)
                        .foregroundColor(.mindSyncWarning)
                }
                .padding(.top, AppConstants.Spacing.md)
                .accessibilityHint(NSLocalizedString("analysis.cancelHint", comment: ""))
                .accessibilityIdentifier("analysis.cancelButton")
            }
        }
        .padding(AppConstants.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    AnalysisProgressView(
        progress: AnalysisProgress(
            phase: .analyzing,
            progress: 0.6,
            message: "Analysiere Frequenzen..."
        )
    )
}

