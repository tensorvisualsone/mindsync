import SwiftUI

/// Großformatiger Button mit einheitlicher MindSync-Optik und Haptic-Feedback.
struct LargeButton: View {
    enum Style {
        case filled(Color)
        case outlined(Color)
        case tonal(Color)
        
        var foregroundColor: Color {
            switch self {
            case .filled:
                return .white
            case .outlined(let color),
                 .tonal(let color):
                return color
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .filled(let color):
                return Color.mindSyncButtonBackground(color: color)
            case .outlined:
                return Color.mindSyncCardBackground()
            case .tonal(let color):
                return color.opacity(0.15)
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outlined(let color):
                return color.opacity(0.8)
            default:
                return nil
            }
        }
    }
    
    let title: String
    var subtitle: String?
    var systemImage: String?
    var style: Style = .filled(.blue)
    var isDisabled: Bool = false
    var cornerRadius: CGFloat = AppConstants.CornerRadius.button
    var minHeight: CGFloat = AppConstants.TouchTarget.extraLarge
    var horizontalPadding: CGFloat = AppConstants.Spacing.md
    var verticalPadding: CGFloat = AppConstants.Spacing.lg
    var accessibilityIdentifier: String?
    var action: () -> Void
    
    var body: some View {
        Button(action: triggerAction) {
            VStack(spacing: AppConstants.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: AppConstants.IconSize.extraLarge))
                }
                
                VStack(spacing: AppConstants.Spacing.xs) {
                    Text(title)
                        .font(AppConstants.Typography.headline)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(style.foregroundColor.opacity(AppConstants.Opacity.secondary))
                    }
                }
            }
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(style.borderColor ?? .clear, lineWidth: style.borderColor == nil ? 0 : 2)
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .modifier(OptionalAccessibilityIdentifierModifier(identifier: accessibilityIdentifier))
    }
    
    private func triggerAction() {
        guard !isDisabled else { return }
        HapticFeedback.light()
        action()
    }
}

private struct OptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?
    
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LargeButton(
            title: "Session starten",
            subtitle: "Lokale Musik",
            systemImage: "music.note.list",
            style: .filled(.blue),
            action: {}
        )
        
        LargeButton(
            title: "Mikrofon-Modus",
            subtitle: "Streaming / externe Audioquelle",
            systemImage: "mic.fill",
            style: .tonal(.mindSyncWarning),
            action: {}
        )
        
        LargeButton(
            title: "Stoppen",
            systemImage: "stop.circle.fill",
            style: .outlined(.mindSyncError),
            action: {}
        )
    }
    .padding()
    .background(Color.black)
}

