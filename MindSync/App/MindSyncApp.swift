import SwiftUI

@main
struct MindSyncApp: App {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false

    var body: some Scene {
        WindowGroup {
            if disclaimerAccepted {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}
