import SwiftUI

enum MindSyncTheme {
    static func backgroundColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.06, green: 0.02, blue: 0.12),
                Color(red: 0.01, green: 0.06, blue: 0.12)
            ]
        } else {
            return [
                Color(red: 0.93, green: 0.95, blue: 0.99),
                Color(red: 0.88, green: 0.92, blue: 0.99),
                Color(red: 0.96, green: 0.97, blue: 1.0)
            ]
        }
    }
}

private struct MindSyncBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: MindSyncTheme.backgroundColors(for: colorScheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

private struct MindSyncCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppConstants.CornerRadius.card
    var borderOpacity: Double = 0.25
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15),
                        radius: colorScheme == .dark ? 18 : 12,
                        x: 0,
                        y: colorScheme == .dark ? 16 : 10
                    )
            )
    }
    
    private var cardFill: Color {
        if colorScheme == .dark {
            return Color(.secondarySystemBackground).opacity(0.7)
        } else {
            return Color.white.opacity(0.9)
        }
    }
    
    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(borderOpacity * 0.6)
            : Color.black.opacity(borderOpacity * 0.4)
    }
}

extension View {
    func mindSyncBackground() -> some View {
        modifier(MindSyncBackgroundModifier())
    }
    
    func mindSyncCardStyle(
        cornerRadius: CGFloat = AppConstants.CornerRadius.card,
        borderOpacity: Double = 0.25
    ) -> some View {
        modifier(MindSyncCardStyle(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}

