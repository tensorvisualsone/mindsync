import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("MindSync")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("home.title")

                Text("Audio-synchronisiertes Stroboskop für veränderte Bewusstseinszustände.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                NavigationLink("Session starten") {
                    SessionView()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

#Preview {
    HomeView()
}
