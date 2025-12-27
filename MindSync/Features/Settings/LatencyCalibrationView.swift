import SwiftUI

/// View für die Audio-Latenz-Kalibrierung
/// Zeigt interaktiven Kalibrierungsprozess mit Anweisungen und visuellem Feedback
struct LatencyCalibrationView: View {
    @StateObject private var viewModel = LatencyCalibrationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Hauptinhalt
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Content basierend auf State
                contentView
                
                Spacer()
                
                // Actions
                actionButtons
            }
            .padding()
            
            // Weißer Flash Overlay (erscheint während der Messung)
            if viewModel.showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .navigationTitle("Latenz-Kalibrierung")
        .navigationBarTitleDisplayMode(.inline)
        // Tap-Geste für Messungen
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.state.isWaitingForTap {
                viewModel.userTapped()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            Text("Audio-Synchronisation")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .ready:
            readyView
            
        case .instructions:
            instructionsView
            
        case .measuring, .waitingForTap:
            measuringView
            
        case .processing:
            processingView
            
        case .completed:
            completedView
            
        case .error(let message):
            errorView(message: message)
        }
    }
    
    // MARK: - State Views
    
    private var readyView: some View {
        VStack(spacing: 20) {
            Text("Optimiere die Synchronisation zwischen Audio und Licht für deine Kopfhörer.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                calibrationInfoRow(
                    icon: "headphones",
                    title: "Bluetooth-Kompensation",
                    description: "Gleicht Verzögerungen aus"
                )
                
                calibrationInfoRow(
                    icon: "timer",
                    title: "5 Messungen",
                    description: "Dauert ca. 30 Sekunden"
                )
                
                calibrationInfoRow(
                    icon: "checkmark.circle",
                    title: "Automatisch",
                    description: "Optimaler Wert wird berechnet"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var instructionsView: some View {
        VStack(spacing: 30) {
            // Countdown oder Animation
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 16) {
                Text("Vorbereitung...")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Gleich erscheint ein weißer Blitz zusammen mit einem Klick-Sound.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("Tippe auf den Screen, sobald du **beide gleichzeitig** wahrnimmst.")
                    .multilineTextAlignment(.center)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
        }
    }
    
    private var measuringView: some View {
        VStack(spacing: 40) {
            // Progress
            VStack(spacing: 12) {
                Text("Messung \(viewModel.currentMeasurement) von \(viewModel.totalMeasurements)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(viewModel.currentMeasurement), total: Double(viewModel.totalMeasurements))
                    .tint(.blue)
                    .scaleEffect(y: 2)
            }
            .padding(.horizontal, 40)
            
            // Instruction
            if viewModel.state.isWaitingForTap {
                VStack(spacing: 20) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)
                        .symbolEffect(.bounce, value: viewModel.state)
                    
                    Text("Tippe jetzt!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Wenn Blitz und Sound synchron waren")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Bereite dich vor...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Berechne optimalen Wert...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var completedView: some View {
        VStack(spacing: 30) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green.gradient)
            
            VStack(spacing: 12) {
                Text("Kalibrierung abgeschlossen!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Dein optimaler Latenz-Offset wurde ermittelt.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Result Display
            VStack(spacing: 16) {
                HStack {
                    Text("Latenz-Offset:")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.0f ms", viewModel.calibratedOffset * 1000))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Messungen:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.measurements.enumerated()), id: \.offset) { _, measurement in
                            Text(String(format: "%.0f", measurement * 1000))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Info Text
            if viewModel.calibratedOffset > 0.05 {
                Label {
                    Text("Bluetooth-Latenz erkannt. Synchronisation wird automatisch angepasst.")
                        .font(.caption)
                } icon: {
                    Image(systemName: "info.circle.fill")
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .ready:
            Button {
                viewModel.startCalibration()
            } label: {
                Label("Kalibrierung starten", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
            
        case .completed:
            VStack(spacing: 12) {
                Button {
                    viewModel.saveCalibration()
                    dismiss()
                } label: {
                    Label("Speichern und schließen", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                }
                
                Button {
                    viewModel.reset()
                } label: {
                    Text("Erneut kalibrieren")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            
        case .error:
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Abbrechen")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button {
                    viewModel.reset()
                } label: {
                    Text("Erneut versuchen")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Views
    
    private func calibrationInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LatencyCalibrationView()
    }
}

