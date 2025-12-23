import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("epilepsyDisclaimerAcceptedAt") private var disclaimerAcceptedAt: Double = 0
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Wichtige Sicherheitshinweise")
                    .font(.title.bold())
                    .accessibilityIdentifier("onboarding.title")

                Text("Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann.")
                    .multilineTextAlignment(.center)

                Button("Mehr erfahren") {
                    viewModel.showDetails = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.learnMoreButton")

                Button("Ich verstehe und akzeptiere") {
                    disclaimerAccepted = true
                    disclaimerAcceptedAt = Date().timeIntervalSince1970
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                .accessibilityIdentifier("onboarding.acceptButton")
            }
            .padding()
            // Force dark mode to ensure consistent, high-contrast rendering of safety-critical epilepsy warnings.
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showDetails) {
                NavigationStack {
                    EpilepsyWarningView()
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
