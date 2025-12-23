import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Wichtige Sicherheitshinweise")
                .font(.title.bold())

            Text("Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann. Verwenden Sie MindSync nicht, wenn Sie oder Ihre Familie eine Vorgeschichte mit Krampfanfällen haben.")
                .multilineTextAlignment(.center)
                .padding()

            Button("Ich verstehe und akzeptiere") {
                disclaimerAccepted = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingView()
}
