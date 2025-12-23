import SwiftUI

/// View for displaying analysis progress
struct AnalysisProgressView: View {
    let progress: AnalysisProgress
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress ring
            ProgressRing(progress: progress.progress)
                .frame(width: 120, height: 120)
            
            // Message
            Text(progress.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            // Percentage display
            Text("\(Int(progress.progress * 100))%")
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    AnalysisProgressView(
        progress: AnalysisProgress(
            phase: .analyzing,
            progress: 0.6,
            message: "Analysiere Frequenzen..."
        )
    )
}

