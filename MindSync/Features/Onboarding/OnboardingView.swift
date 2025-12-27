import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("epilepsyDisclaimerAcceptedAt") private var disclaimerAcceptedAt: Double = 0
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                Spacer()
                
                // Warning Icon with glow effect
                ZStack {
                    Circle()
                        .fill(Color.mindSyncWarning.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: AppConstants.IconSize.extraLarge))
                        .foregroundColor(.mindSyncWarning)
                }

                Text(NSLocalizedString("onboarding.title", comment: ""))
                    .font(AppConstants.Typography.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.title")

                Text(NSLocalizedString("onboarding.description", comment: ""))
                    .font(AppConstants.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.mindSyncSecondaryText)
                    .padding(.horizontal, AppConstants.Spacing.lg)

                Spacer()
                
                VStack(spacing: AppConstants.Spacing.md) {
                    Button(NSLocalizedString("onboarding.learnMore", comment: "")) {
                        HapticFeedback.light()
                        viewModel.showDetails = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.mindSyncInfo)
                    .accessibilityIdentifier("onboarding.learnMoreButton")
                    .accessibilityHint(NSLocalizedString("onboarding.learnMoreHint", comment: "Accessibility hint: Opens detailed safety information"))

                    Button(action: {
                        HapticFeedback.medium()
                        disclaimerAccepted = true
                        disclaimerAcceptedAt = Date().timeIntervalSince1970
                    }) {
                        Text(NSLocalizedString("onboarding.accept", comment: ""))
                            .font(AppConstants.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppConstants.Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mindSyncAccent)
                    .accessibilityIdentifier("onboarding.acceptButton")
                    .accessibilityHint(NSLocalizedString("onboarding.acceptHint", comment: "Accessibility hint: Confirms understanding and starts the app"))
                }
                .padding(.horizontal, AppConstants.Spacing.lg)
                .padding(.bottom, AppConstants.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Force dark mode to ensure consistent, high-contrast rendering of safety-critical epilepsy warnings.
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showDetails) {
                NavigationStack {
                    EpilepsyWarningView()
                }
            }
        }
        .mindSyncBackground()
    }
}

#Preview {
    OnboardingView()
}
