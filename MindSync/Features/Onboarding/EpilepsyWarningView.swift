import SwiftUI

struct EpilepsyWarningView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.elementSpacing) {
                Text("Epilepsie- und Sicherheitswarnung")
                    .font(AppConstants.Typography.title)

                Text("Diese App verwendet intensives, stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie (PSE) Anfälle auslösen kann.")
                    .font(AppConstants.Typography.body)

                Text("Verwenden Sie MindSync nicht, wenn:")
                    .font(AppConstants.Typography.headline)

                VStack(alignment: .leading, spacing: AppConstants.Spacing.sm) {
                    Text("• bei Ihnen jemals ein epileptischer Anfall diagnostiziert wurde")
                        .font(AppConstants.Typography.body)
                    Text("• in Ihrer Familie eine Vorgeschichte mit Krampfanfällen besteht")
                        .font(AppConstants.Typography.body)
                    Text("• Ihnen von medizinischem Fachpersonal von stroboskopischem Licht abgeraten wurde")
                        .font(AppConstants.Typography.body)
                }

                Text("Weitere Hinweise")
                    .font(AppConstants.Typography.headline)

                Text("• Verwenden Sie MindSync nur in einer sicheren, sitzenden oder liegenden Position in einem dunklen Raum.")
                    .font(AppConstants.Typography.body)
                Text("• Entfernen Sie sich von Gefahrenquellen (Treppen, Kanten, spitze Gegenstände).")
                    .font(AppConstants.Typography.body)
                Text("• Beenden Sie die Sitzung sofort, wenn Sie sich unwohl, schwindelig oder desorientiert fühlen.")
                    .font(AppConstants.Typography.body)

                Text("MindSync ist ein Wellness- und Unterhaltungs-Tool und ersetzt keine medizinische Behandlung oder Beratung.")
                    .font(AppConstants.Typography.caption)
                    .foregroundStyle(.mindSyncSecondaryText)
            }
            .padding(AppConstants.Spacing.md)
        }
        .navigationTitle("Sicherheit")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("epilepsyWarning.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
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
