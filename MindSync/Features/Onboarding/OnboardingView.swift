import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("epilepsyDisclaimerAcceptedAt") private var disclaimerAcceptedAt: Double = 0
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: AppConstants.IconSize.extraLarge))
                    .foregroundColor(.mindSyncWarning)

                Text("Wichtige Sicherheitshinweise")
                    .font(AppConstants.Typography.title)
                    .accessibilityIdentifier("onboarding.title")

                Text("Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann.")
                    .font(AppConstants.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.mindSyncPrimaryText)

                Button("Mehr erfahren") {
                    viewModel.showDetails = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.learnMoreButton")
                .accessibilityHint("Zeigt weitere Informationen zur Sicherheit an")

                Button("Ich verstehe und akzeptiere") {
                    disclaimerAccepted = true
                    disclaimerAcceptedAt = Date().timeIntervalSince1970
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, AppConstants.Spacing.sm)
                .accessibilityIdentifier("onboarding.acceptButton")
                .accessibilityHint("Akzeptiert die Sicherheitshinweise und öffnet die App")
            }
            .padding(AppConstants.Spacing.md)
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
