import SwiftUI

/// View for selecting light source (Flashlight vs Screen)
struct LightSourcePicker: View {
    @Binding var selectedSource: LightSource
    @Binding var screenColor: LightEvent.LightColor
    @Binding var customColorRGB: CustomColorRGB?
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.sectionSpacing) {
            Text(NSLocalizedString("lightSource.title", comment: ""))
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
                            .foregroundColor(selectedSource == .flashlight ? .mindSyncFlashlight : .mindSyncSecondaryText)
                        
                        Text(NSLocalizedString("lightSource.flashlight", comment: ""))
                            .font(AppConstants.Typography.subheadline.weight(.bold))
                            .foregroundColor(selectedSource == .flashlight ? .mindSyncPrimaryText : .mindSyncSecondaryText)
                        
                        Text(LightSource.flashlight.description)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
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
                .accessibilityLabel(NSLocalizedString("lightSource.selectFlashlight", comment: ""))
                .accessibilityAddTraits(selectedSource == .flashlight ? .isSelected : [])
                
                // Screen option
                Button(action: {
                    selectedSource = .screen
                }) {
                    VStack(spacing: AppConstants.Spacing.md) {
                        Image(systemName: "iphone")
                            .font(.system(size: AppConstants.IconSize.large))
                            .foregroundColor(selectedSource == .screen ? .mindSyncScreen : .mindSyncSecondaryText)
                        
                        Text(NSLocalizedString("lightSource.screen", comment: ""))
                            .font(AppConstants.Typography.subheadline.weight(.bold))
                            .foregroundColor(selectedSource == .screen ? .mindSyncPrimaryText : .mindSyncSecondaryText)
                        
                        Text(LightSource.screen.description)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(.mindSyncSecondaryText)
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
                .accessibilityLabel(NSLocalizedString("lightSource.selectScreen", comment: ""))
                .accessibilityAddTraits(selectedSource == .screen ? .isSelected : [])
            }
            
            // Screen color picker (only visible when screen mode is selected)
            if selectedSource == .screen {
                VStack(spacing: AppConstants.Spacing.elementSpacing) {
                    Text(NSLocalizedString("lightSource.screenColor", comment: ""))
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
                            .accessibilityLabel(String(format: NSLocalizedString("lightSource.selectColor", comment: ""), color.displayName))
                            .accessibilityAddTraits(screenColor == color ? .isSelected : [])
                        }
                        
                        // Custom color option
                        Button(action: {
                            screenColor = .custom
                            // Initialize with white if customColorRGB is nil
                            if customColorRGB == nil {
                                customColorRGB = CustomColorRGB(red: 1.0, green: 1.0, blue: 1.0)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(customColorRGB.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? .white)
                                    .frame(
                                        width: AppConstants.TouchTarget.minimum,
                                        height: AppConstants.TouchTarget.minimum
                                    )
                                
                                // Gradient overlay for "custom" indicator
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .opacity(0.3)
                                
                                Circle()
                                    .stroke(
                                        screenColor == .custom ? Color.mindSyncPrimaryText : Color.clear,
                                        lineWidth: 3
                                    )
                                
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: AppConstants.IconSize.small, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(screenColor == .custom ? 1 : 0.7)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("lightSource.selectCustomColor", comment: ""))
                        .accessibilityAddTraits(screenColor == .custom ? .isSelected : [])
                    }
                    
                    // Custom color picker (only visible when custom is selected)
                    if screenColor == .custom {
                        VStack(spacing: AppConstants.Spacing.sm) {
                            ColorPicker(
                                NSLocalizedString("lightSource.customColor", comment: ""),
                                selection: Binding(
                                    get: {
                                        if let rgb = customColorRGB {
                                            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                                        }
                                        return .white
                                    },
                                    set: { newColor in
                                        let components = UIColor(newColor).cgColor.components ?? [1.0, 1.0, 1.0, 1.0]
                                        customColorRGB = CustomColorRGB(
                                            red: Double(components[0]),
                                            green: Double(components[1]),
                                            blue: Double(components[2])
                                        )
                                    }
                                ),
                                supportsOpacity: false
                            )
                            .accessibilityIdentifier("settings.customColorPicker")
                        }
                        .padding(.top, AppConstants.Spacing.sm)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Text(NSLocalizedString("lightSource.screenColorDescription", comment: ""))
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(.mindSyncSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, AppConstants.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppConstants.Animation.spring, value: selectedSource)
        .animation(AppConstants.Animation.spring, value: screenColor)
    }
}

#Preview {
    LightSourcePicker(
        selectedSource: .constant(.screen),
        screenColor: .constant(.white),
        customColorRGB: .constant(nil)
    )
    .padding()
}

