import SwiftUI

struct EpilepsyWarningView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.elementSpacing) {
                Text(NSLocalizedString("epilepsyWarning.title", comment: ""))
                    .font(AppConstants.Typography.title)

                Text(NSLocalizedString("epilepsyWarning.description", comment: ""))
                    .font(AppConstants.Typography.body)

                Text(NSLocalizedString("epilepsyWarning.doNotUse", comment: ""))
                    .font(AppConstants.Typography.headline)

                VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                    Text("• \(NSLocalizedString("epilepsyWarning.condition1", comment: ""))")
                        .font(AppConstants.Typography.body)
                    Text("• \(NSLocalizedString("epilepsyWarning.condition2", comment: ""))")
                        .font(AppConstants.Typography.body)
                    Text("• \(NSLocalizedString("epilepsyWarning.condition3", comment: ""))")
                        .font(AppConstants.Typography.body)
                }

                Text(NSLocalizedString("epilepsyWarning.additionalNotes", comment: ""))
                    .font(AppConstants.Typography.headline)

                Text("• \(NSLocalizedString("epilepsyWarning.note1", comment: ""))")
                    .font(AppConstants.Typography.body)
                Text("• \(NSLocalizedString("epilepsyWarning.note2", comment: ""))")
                    .font(AppConstants.Typography.body)
                Text("• \(NSLocalizedString("epilepsyWarning.note3", comment: ""))")
                    .font(AppConstants.Typography.body)

                Text(NSLocalizedString("epilepsyWarning.disclaimer", comment: ""))
                    .font(AppConstants.Typography.caption)
                    .foregroundColor(.mindSyncSecondaryText)
            }
            .padding(AppConstants.Spacing.md)
        }
        .navigationTitle(NSLocalizedString("epilepsyWarning.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("epilepsyWarning.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("epilepsyWarning.close", comment: "")) {
                    dismiss()
                }
                .accessibilityIdentifier("epilepsyWarning.closeButton")
            }
        }
    }
}

#Preview {
    NavigationStack {
        EpilepsyWarningView()
    }
}
