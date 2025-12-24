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

                Text(NSLocalizedString("onboarding.title", comment: ""))
                    .font(AppConstants.Typography.title)
                    .accessibilityIdentifier("onboarding.title")

                Text(NSLocalizedString("onboarding.description", comment: ""))
                    .font(AppConstants.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.mindSyncPrimaryText)

                Button(NSLocalizedString("onboarding.learnMore", comment: "")) {
                    viewModel.showDetails = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.learnMoreButton")
                .accessibilityHint(NSLocalizedString("onboarding.learnMore", comment: ""))

                Button(NSLocalizedString("onboarding.accept", comment: "")) {
                    disclaimerAccepted = true
                    disclaimerAcceptedAt = Date().timeIntervalSince1970
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, AppConstants.Spacing.sm)
                .accessibilityIdentifier("onboarding.acceptButton")
                .accessibilityHint(NSLocalizedString("onboarding.accept", comment: "Accessibility hint for accept button"))
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
