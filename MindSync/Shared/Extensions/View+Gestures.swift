import SwiftUI

/// Reusable Gesture-Modifikatoren für großflächige Steuerflächen
extension View {
    /// Fügt optionale Doppel-Tipp- und Swipe-Gesten hinzu – ideal für Session Controls.
    func mindSyncGestureArea(
        doubleTapAction: (() -> Void)? = nil,
        swipeUpAction: (() -> Void)? = nil,
        swipeDownAction: (() -> Void)? = nil,
        minimumDistance: CGFloat = 30
    ) -> some View {
        modifier(
            MindSyncGestureModifier(
                doubleTapAction: doubleTapAction,
                swipeUpAction: swipeUpAction,
                swipeDownAction: swipeDownAction,
                minimumDistance: minimumDistance
            )
        )
    }
    
    /// Applies MindSync card styling with background, border and shadow
    func mindSyncCardStyle(
        cornerRadius: CGFloat = AppConstants.CornerRadius.card,
        borderOpacity: Double = 0.25
    ) -> some View {
        modifier(MindSyncCardStyleModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
    
    /// Applies MindSync gradient background
    func mindSyncBackground() -> some View {
        modifier(MindSyncBackgroundModifier())
    }
}

private struct MindSyncGestureModifier: ViewModifier {
    let doubleTapAction: (() -> Void)?
    let swipeUpAction: (() -> Void)?
    let swipeDownAction: (() -> Void)?
    let minimumDistance: CGFloat
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    doubleTapAction?()
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onEnded { value in
                        if value.translation.height <= -minimumDistance {
                            swipeUpAction?()
                        } else if value.translation.height >= minimumDistance {
                            swipeDownAction?()
                        }
                    }
            )
    }
}

private struct MindSyncCardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var borderOpacity: Double
    
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

private struct MindSyncBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
    
    private var backgroundColors: [Color] {
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

