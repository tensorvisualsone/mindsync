import SwiftUI

/// View for selecting light source (Flashlight vs Screen)
struct LightSourcePicker: View {
    @Binding var selectedSource: LightSource
    @Binding var screenColor: LightEvent.LightColor
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Lichtquelle")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Light source options
            HStack(spacing: 16) {
                // Flashlight option
                Button(action: {
                    selectedSource = .flashlight
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "flashlight.on.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(selectedSource == .flashlight ? .yellow : .secondary)
                        
                        Text("Taschenlampe")
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedSource == .flashlight ? .primary : .secondary)
                        
                        Text(LightSource.flashlight.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedSource == .flashlight
                            ? Color.yellow.opacity(0.2)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedSource == .flashlight ? Color.yellow : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
                
                // Screen option
                Button(action: {
                    selectedSource = .screen
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.system(size: 40))
                            .foregroundStyle(selectedSource == .screen ? .blue : .secondary)
                        
                        Text("Bildschirm")
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedSource == .screen ? .primary : .secondary)
                        
                        Text(LightSource.screen.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedSource == .screen
                            ? Color.blue.opacity(0.2)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedSource == .screen ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Screen color picker (only visible when screen mode is selected)
            if selectedSource == .screen {
                VStack(spacing: 16) {
                    Text("Bildschirmfarbe")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Color options
                    HStack(spacing: 12) {
                        ForEach(LightEvent.LightColor.allCases.filter { $0 != .custom }) { color in
                            Button(action: {
                                screenColor = color
                            }) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                screenColor == color ? Color.primary : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(
                                                color == .white ? .black : .white
                                            )
                                            .opacity(screenColor == color ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Wähle die Farbe für das Stroboskoplicht")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedSource)
    }
}

#Preview {
    LightSourcePicker(
        selectedSource: .constant(.screen),
        screenColor: .constant(.white)
    )
    .padding()
}

