import SwiftUI

/// Banner displaying thermal warnings during sessions
struct SafetyBanner: View {
    let warningLevel: ThermalWarningLevel
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        if warningLevel != .none {
            HStack(spacing: 12) {
                // Warning icon
                Image(systemName: warningLevel.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true) // Icon is decorative, message provides context
                
                // Warning message
                if let message = warningLevel.message {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Optional dismiss button
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .accessibilityLabel("Warnung schließen")
                    .accessibilityHint("Schließt die thermische Warnung")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isStaticText)
        }
    }
    
    private var accessibilityLabel: String {
        switch warningLevel {
        case .none:
            return ""
        case .reduced:
            return "Warnung: Intensität reduziert wegen Gerätewärme"
        case .critical:
            return "Kritische Warnung: Taschenlampe deaktiviert wegen Überhitzung"
        }
    }
    
    private var backgroundColor: Color {
        switch warningLevel {
        case .none:
            return .clear
        case .reduced:
            return Color.orange.opacity(0.9)
        case .critical:
            return Color.red.opacity(0.9)
        }
    }
    
    private var iconColor: Color {
        switch warningLevel {
        case .none:
            return .clear
        case .reduced:
            return .yellow
        case .critical:
            return .white
        }
    }
}

// MARK: - Compact variant for overlay use

extension SafetyBanner {
    /// Creates a compact banner for use as an overlay
    static func compact(warningLevel: ThermalWarningLevel) -> some View {
        SafetyBanner(warningLevel: warningLevel)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("Reduced Warning") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            SafetyBanner(warningLevel: .reduced)
                .padding()
            
            Spacer()
        }
    }
}

#Preview("Critical Warning") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            SafetyBanner(warningLevel: .critical)
                .padding()
            
            Spacer()
        }
    }
}

#Preview("No Warning") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            SafetyBanner(warningLevel: .none)
                .padding()
            
            Text("No banner visible")
                .foregroundStyle(.white)
            
            Spacer()
        }
    }
}

