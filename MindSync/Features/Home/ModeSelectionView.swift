import SwiftUI

/// View for selecting EntrainmentMode (Alpha, Theta, Gamma)
struct ModeSelectionView: View {
    @Binding var selectedMode: EntrainmentMode
    let onModeSelected: ((EntrainmentMode) -> Void)?
    
    init(
        selectedMode: Binding<EntrainmentMode>,
        onModeSelected: ((EntrainmentMode) -> Void)? = nil
    ) {
        self._selectedMode = selectedMode
        self.onModeSelected = onModeSelected
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(NSLocalizedString("modeSelection.title", comment: ""))
                        .font(.title2.bold())
                        .padding(.top)
                    
                    Text(NSLocalizedString("modeSelection.description", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        ForEach(EntrainmentMode.allCases) { mode in
                            ModeCard(
                                mode: mode,
                                isSelected: selectedMode == mode
                            ) {
                                selectMode(mode)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("settings.mode", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func selectMode(_ mode: EntrainmentMode) {
        selectedMode = mode
        
        // Load preferences fresh and save the new mode
        var preferences = UserPreferences.load()
        preferences.preferredMode = mode
        preferences.save()
        
        // Haptic feedback if enabled
        if preferences.hapticFeedbackEnabled {
            HapticFeedback.light()
        }
        
        onModeSelected?(mode)
    }
}

/// Card view for a single EntrainmentMode
private struct ModeCard: View {
    let mode: EntrainmentMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: mode.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(isSelected ? .white : .blue)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(Int(mode.frequencyRange.lowerBound))-\(Int(mode.frequencyRange.upperBound)) Hz")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModeSelectionView(selectedMode: .constant(.alpha))
}

