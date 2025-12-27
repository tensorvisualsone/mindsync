import SwiftUI

struct EpilepsyWarningView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.lg) {
                // Header with icon
                HStack(spacing: AppConstants.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.mindSyncWarning)
                    
                    Text(NSLocalizedString("epilepsyWarning.title", comment: ""))
                        .font(AppConstants.Typography.title2)
                        .foregroundColor(.white)
                }
                .padding(.bottom, AppConstants.Spacing.sm)

                Text(NSLocalizedString("epilepsyWarning.description", comment: ""))
                    .font(AppConstants.Typography.body)
                    .foregroundColor(.mindSyncPrimaryText)

                // Do Not Use Section
                VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
                    Label(NSLocalizedString("epilepsyWarning.doNotUse", comment: ""), systemImage: "xmark.shield.fill")
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(.mindSyncError)

                    VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                        WarningConditionRow(text: NSLocalizedString("epilepsyWarning.condition1", comment: ""))
                        WarningConditionRow(text: NSLocalizedString("epilepsyWarning.condition2", comment: ""))
                        WarningConditionRow(text: NSLocalizedString("epilepsyWarning.condition3", comment: ""))
                    }
                }
                .padding(AppConstants.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                        .fill(Color.mindSyncError.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                                .stroke(Color.mindSyncError.opacity(0.3), lineWidth: 1)
                        )
                )

                // Additional Notes Section
                VStack(alignment: .leading, spacing: AppConstants.Spacing.md) {
                    Label(NSLocalizedString("epilepsyWarning.additionalNotes", comment: ""), systemImage: "info.circle.fill")
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(.mindSyncInfo)

                    VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                        SafetyNoteRow(text: NSLocalizedString("epilepsyWarning.note1", comment: ""), icon: "figure.seated.side.air.pump")
                        SafetyNoteRow(text: NSLocalizedString("epilepsyWarning.note2", comment: ""), icon: "exclamationmark.octagon")
                        SafetyNoteRow(text: NSLocalizedString("epilepsyWarning.note3", comment: ""), icon: "stop.circle")
                    }
                }
                .padding(AppConstants.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                        .fill(Color.mindSyncInfo.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                                .stroke(Color.mindSyncInfo.opacity(0.3), lineWidth: 1)
                        )
                )

                // Disclaimer
                Text(NSLocalizedString("epilepsyWarning.disclaimer", comment: ""))
                    .font(AppConstants.Typography.caption)
                    .foregroundColor(.mindSyncSecondaryText)
                    .italic()
                    .padding(.top, AppConstants.Spacing.sm)
            }
            .padding(AppConstants.Spacing.md)
        }
        .navigationTitle(NSLocalizedString("epilepsyWarning.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("epilepsyWarning.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("epilepsyWarning.close", comment: "")) {
                    HapticFeedback.light()
                    dismiss()
                }
                .accessibilityIdentifier("epilepsyWarning.closeButton")
            }
        }
        .mindSyncBackground()
        .preferredColorScheme(.dark)
    }
}

private struct WarningConditionRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppConstants.Spacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.mindSyncError.opacity(0.8))
                .font(.system(size: 14))
            Text(text)
                .font(AppConstants.Typography.body)
                .foregroundColor(.mindSyncPrimaryText)
        }
    }
}

private struct SafetyNoteRow: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppConstants.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.mindSyncInfo.opacity(0.8))
                .font(.system(size: 14))
                .frame(width: 20)
            Text(text)
                .font(AppConstants.Typography.body)
                .foregroundColor(.mindSyncPrimaryText)
        }
    }
}

#Preview {
    NavigationStack {
        EpilepsyWarningView()
    }
}
