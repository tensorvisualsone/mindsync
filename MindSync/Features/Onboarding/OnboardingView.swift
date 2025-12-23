import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)

                Text("Wichtige Sicherheitshinweise")
                    .font(.title.bold())

                Text("Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann.")
                    .multilineTextAlignment(.center)

                Button("Mehr erfahren") {
                    viewModel.showDetails = true
                }
                .buttonStyle(.bordered)

                Button("Ich verstehe und akzeptiere") {
                    disclaimerAccepted = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
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
