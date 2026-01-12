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
                VStack(spacing: AppConstants.Spacing.xl) {
                    // Header
                    VStack(spacing: AppConstants.Spacing.sm) {
                        Text(NSLocalizedString("modeSelection.title", comment: ""))
                            .font(AppConstants.Typography.title)
                            .accessibilityIdentifier("modeSelection.title")
                        
                        Text(NSLocalizedString("modeSelection.description", comment: ""))
                            .font(AppConstants.Typography.body)
                            .foregroundColor(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppConstants.Spacing.md)
                    }
                    .padding(.top, AppConstants.Spacing.lg)
                    
                    // Mode Cards
                    VStack(spacing: AppConstants.Spacing.md) {
                        ForEach(EntrainmentMode.allCases) { mode in
                            ModeCard(
                                mode: mode,
                                isSelected: selectedMode == mode
                            ) {
                                selectMode(mode)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, AppConstants.Spacing.md)
                }
                .padding(.bottom, AppConstants.Spacing.lg)
            }
            .navigationTitle(NSLocalizedString("modeSelection.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func selectMode(_ mode: EntrainmentMode) {
        // Load preferences fresh and save the new mode
        var preferences = UserPreferences.load()
        
        // Haptic feedback for mode selection (if enabled)
        if preferences.hapticFeedbackEnabled {
            HapticFeedback.medium()
        }
        
        selectedMode = mode
        
        preferences.preferredMode = mode
        preferences.save()
        
        onModeSelected?(mode)
    }
}

/// Card view for a single EntrainmentMode
private struct ModeCard: View {
    let mode: EntrainmentMode
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppConstants.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [mode.themeColor, mode.themeColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [mode.themeColor.opacity(0.2), mode.themeColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: mode.iconName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [mode.themeColor, mode.themeColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(mode.displayName)
                        .font(AppConstants.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .mindSyncPrimaryText)
                        .accessibilityIdentifier("mode.\(mode.rawValue).displayName")
                    
                    Text(mode.description)
                        .font(AppConstants.Typography.body)
                        .foregroundColor(isSelected ? .white.opacity(AppConstants.Opacity.secondary) : .mindSyncSecondaryText)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: AppConstants.Spacing.xs) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(Int(mode.frequencyRange.lowerBound))-\(Int(mode.frequencyRange.upperBound)) Hz")
                            .font(AppConstants.Typography.caption)
                    }
                    .foregroundColor(isSelected ? .white.opacity(AppConstants.Opacity.tertiary) : .mindSyncTertiaryText)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(AppConstants.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.large, style: .continuous)
                    .fill(isSelected ? mode.themeColor : Color.mindSyncCardBackground())
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .accessibilityIdentifier("modeCard.\(mode.rawValue)")
        .accessibilityLabel(mode.displayName)
        .accessibilityHint(isSelected ? NSLocalizedString("modeSelection.selectedMode", comment: "") : NSLocalizedString("modeSelection.selectMode", comment: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Custom button style that tracks press state for visual feedback
private struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

#Preview {
    ModeSelectionView(selectedMode: .constant(.alpha))
}

