import SwiftUI

/// Ringförmiger Fortschrittsindikator
struct ProgressRing: View {
    let progress: Double  // 0.0 - 1.0
    
    private let lineWidth: CGFloat = 12
    private var clampedProgress: Double {
        max(0.0, min(1.0, progress))
    }
    
    var body: some View {
        ZStack {
            // Hintergrund-Ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            
            // Fortschritts-Ring
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: clampedProgress)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressRing(progress: 0.0)
        ProgressRing(progress: 0.3)
        ProgressRing(progress: 0.6)
        ProgressRing(progress: 1.0)
    }
    .padding()
}

