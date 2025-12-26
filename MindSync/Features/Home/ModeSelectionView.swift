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
                VStack(spacing: AppConstants.Spacing.sectionSpacing) {
                    Text(NSLocalizedString("modeSelection.title", comment: ""))
                        .font(AppConstants.Typography.title2)
                        .padding(.top, AppConstants.Spacing.md)
                        .accessibilityIdentifier("modeSelection.title")
                    
                    Text(NSLocalizedString("modeSelection.description", comment: ""))
                        .font(AppConstants.Typography.subheadline)
                        .foregroundColor(.mindSyncSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppConstants.Spacing.horizontalPadding)
                    
                    VStack(spacing: AppConstants.Spacing.elementSpacing) {
                        ForEach(EntrainmentMode.allCases) { mode in
                            ModeCard(
                                mode: mode,
                                isSelected: selectedMode == mode
                            ) {
                                selectMode(mode)
                            }
                        }
                    }
                    .padding(AppConstants.Spacing.md)
                }
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppConstants.Spacing.elementSpacing) {
                // Icon
                Image(systemName: mode.iconName)
                    .font(.system(size: AppConstants.IconSize.large))
                    .foregroundColor(isSelected ? .white : mode.themeColor)
                    .frame(width: AppConstants.TouchTarget.comfortable, height: AppConstants.TouchTarget.comfortable)
                    .background(
                        Circle()
                            .fill(isSelected ? mode.themeColor : mode.themeColor.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: AppConstants.Spacing.xs) {
                    Text(mode.displayName)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(isSelected ? .white : .mindSyncPrimaryText)
                        .accessibilityIdentifier("mode.\(mode.rawValue).displayName")
                    
                    Text(mode.description)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(isSelected ? .white.opacity(AppConstants.Opacity.secondary) : .mindSyncSecondaryText)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(Int(mode.frequencyRange.lowerBound))-\(Int(mode.frequencyRange.upperBound)) Hz")
                        .font(AppConstants.Typography.caption2)
                        .foregroundColor(isSelected ? .white.opacity(AppConstants.Opacity.tertiary) : .mindSyncTertiaryText)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(AppConstants.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                    .fill(isSelected ? mode.themeColor : Color.mindSyncCardBackground())
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modeCard.\(mode.rawValue)")
        .accessibilityLabel(mode.displayName)
        .accessibilityHint(isSelected ? NSLocalizedString("modeSelection.selectedMode", comment: "") : NSLocalizedString("modeSelection.selectMode", comment: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ModeSelectionView(selectedMode: .constant(.alpha))
}

