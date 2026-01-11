import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    @AppStorage("epilepsyDisclaimerAcceptedAt") private var disclaimerAcceptedAt: Double = 0
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.xl) {
                    // Warning Icon with Background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.mindSyncWarning.opacity(0.2),
                                        Color.mindSyncWarning.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.mindSyncWarning, Color.mindSyncWarning.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top, AppConstants.Spacing.xl)
                    
                    // Title and Description Section
                    VStack(spacing: AppConstants.Spacing.md) {
                        Text(NSLocalizedString("onboarding.title", comment: ""))
                            .font(AppConstants.Typography.title)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("onboarding.title")
                        
                        Text(NSLocalizedString("onboarding.description", comment: ""))
                            .font(AppConstants.Typography.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.mindSyncSecondaryText)
                            .lineSpacing(4)
                            .padding(.horizontal, AppConstants.Spacing.md)
                    }
                    
                    // Action Buttons
                    VStack(spacing: AppConstants.Spacing.md) {
                        Button(NSLocalizedString("onboarding.accept", comment: "")) {
                            HapticFeedback.medium()
                            disclaimerAccepted = true
                            disclaimerAcceptedAt = Date().timeIntervalSince1970
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.acceptButton")
                        .accessibilityHint(NSLocalizedString("onboarding.acceptHint", comment: "Accessibility hint: Confirms understanding and starts the app"))
                        
                        Button(NSLocalizedString("onboarding.learnMore", comment: "")) {
                            HapticFeedback.light()
                            viewModel.showDetails = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding.learnMoreButton")
                        .accessibilityHint(NSLocalizedString("onboarding.learnMoreHint", comment: "Accessibility hint: Opens detailed safety information"))
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                    .padding(.top, AppConstants.Spacing.sm)
                }
                .padding(AppConstants.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
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
