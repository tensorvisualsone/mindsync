import SwiftUI

struct EpilepsyWarningView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Epilepsie- und Sicherheitswarnung")
                    .font(.title.bold())

                Text("Diese App verwendet intensives, stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie (PSE) Anfälle auslösen kann.")

                Text("Verwenden Sie MindSync nicht, wenn:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• bei Ihnen jemals ein epileptischer Anfall diagnostiziert wurde")
                    Text("• in Ihrer Familie eine Vorgeschichte mit Krampfanfällen besteht")
                    Text("• Ihnen von medizinischem Fachpersonal von stroboskopischem Licht abgeraten wurde")
                }

                Text("Weitere Hinweise")
                    .font(.headline)

                Text("• Verwenden Sie MindSync nur in einer sicheren, sitzenden oder liegenden Position in einem dunklen Raum.")
                Text("• Entfernen Sie sich von Gefahrenquellen (Treppen, Kanten, spitze Gegenstände).")
                Text("• Beenden Sie die Sitzung sofort, wenn Sie sich unwohl, schwindelig oder desorientiert fühlen.")

                Text("MindSync ist ein Wellness- und Unterhaltungs-Tool und ersetzt keine medizinische Behandlung oder Beratung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Sicherheit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EpilepsyWarningView()
    }
}
