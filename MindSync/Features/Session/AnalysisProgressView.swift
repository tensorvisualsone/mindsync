import SwiftUI

/// View zur Anzeige des Analyse-Fortschritts
struct AnalysisProgressView: View {
    let progress: AnalysisProgress
    
    var body: some View {
        VStack(spacing: 24) {
            // Fortschritts-Ring
            ProgressRing(progress: progress.progress)
                .frame(width: 120, height: 120)
            
            // Nachricht
            Text(progress.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            // Prozentanzeige
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

