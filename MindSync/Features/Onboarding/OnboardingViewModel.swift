import Foundation
import Combine

/// ViewModel für den Onboarding-Flow
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var showDetails: Bool = false
}
