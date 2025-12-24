import SwiftUI

/// View for selecting light source (Flashlight vs Screen)
struct LightSourcePicker: View {
    @Binding var selectedSource: LightSource
    @Binding var screenColor: LightEvent.LightColor
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            Text("Lichtquelle")
                .font(AppConstants.Typography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Light source options
            HStack(spacing: AppConstants.Spacing.elementSpacing) {
                // Flashlight option
                Button(action: {
                    selectedSource = .flashlight
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "flashlight.on.fill")
                            .font(.system(size: AppConstants.IconSize.large))
                            .foregroundStyle(selectedSource == .flashlight ? .mindSyncFlashlight : .mindSyncSecondaryText)
                        
                        Text("Taschenlampe")
                            .font(AppConstants.Typography.subheadline.weight(.bold))
                            .foregroundStyle(selectedSource == .flashlight ? .mindSyncPrimaryText : .mindSyncSecondaryText)
                        
                        Text(LightSource.flashlight.description)
                            .font(AppConstants.Typography.caption)
                            .foregroundStyle(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppConstants.Spacing.md)
                    .background(
                        selectedSource == .flashlight
                            ? Color.mindSyncFlashlight.opacity(AppConstants.Opacity.cardBackground)
                            : Color.mindSyncCardBackground()
                    )
                    .cornerRadius(AppConstants.CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                            .stroke(
                                selectedSource == .flashlight ? Color.mindSyncFlashlight : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.lightSource.flashlight")
                .accessibilityLabel("Taschenlampe auswählen")
                .accessibilityAddTraits(selectedSource == .flashlight ? .isSelected : [])
                
                // Screen option
                Button(action: {
                    selectedSource = .screen
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "iphone")
                            .font(.system(size: AppConstants.IconSize.large))
                            .foregroundStyle(selectedSource == .screen ? .mindSyncScreen : .mindSyncSecondaryText)
                        
                        Text("Bildschirm")
                            .font(AppConstants.Typography.subheadline.weight(.bold))
                            .foregroundStyle(selectedSource == .screen ? .mindSyncPrimaryText : .mindSyncSecondaryText)
                        
                        Text(LightSource.screen.description)
                            .font(AppConstants.Typography.caption)
                            .foregroundStyle(.mindSyncSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppConstants.Spacing.md)
                    .background(
                        selectedSource == .screen
                            ? Color.mindSyncScreen.opacity(AppConstants.Opacity.cardBackground)
                            : Color.mindSyncCardBackground()
                    )
                    .cornerRadius(AppConstants.CornerRadius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.CornerRadius.card)
                            .stroke(
                                selectedSource == .screen ? Color.mindSyncScreen : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.lightSource.screen")
                .accessibilityLabel("Bildschirm auswählen")
                .accessibilityAddTraits(selectedSource == .screen ? .isSelected : [])
            }
            
            // Screen color picker (only visible when screen mode is selected)
            if selectedSource == .screen {
                VStack(spacing: AppConstants.Spacing.elementSpacing) {
                    Text("Bildschirmfarbe")
                        .font(AppConstants.Typography.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Color options
                    HStack(spacing: AppConstants.Spacing.md) {
                        ForEach(LightEvent.LightColor.allCases.filter { $0 != .custom }) { color in
                            Button(action: {
                                screenColor = color
                            }) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(
                                        width: AppConstants.TouchTarget.minimum,
                                        height: AppConstants.TouchTarget.minimum
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                screenColor == color ? Color.mindSyncPrimaryText : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: AppConstants.IconSize.small, weight: .bold))
                                            .foregroundStyle(
                                                color == .white ? .black : .white
                                            )
                                            .opacity(screenColor == color ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Farbe auswählen: \(color.displayName)")
                            .accessibilityAddTraits(screenColor == color ? .isSelected : [])
                        }
                    }
                    
                    Text("Wähle die Farbe für das Stroboskoplicht")
                        .font(AppConstants.Typography.caption)
                        .foregroundStyle(.mindSyncSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, AppConstants.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppConstants.Animation.spring, value: selectedSource)
    }
}

#Preview {
    LightSourcePicker(
        selectedSource: .constant(.screen),
        screenColor: .constant(.white)
    )
    .padding()
}

