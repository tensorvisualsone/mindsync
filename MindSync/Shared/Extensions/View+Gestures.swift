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

