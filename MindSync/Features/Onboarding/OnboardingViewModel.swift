import Foundation
import Combine

/// ViewModel für den Onboarding-Flow
final class OnboardingViewModel: ObservableObject {
    @Published var showDetails: Bool = false
}
