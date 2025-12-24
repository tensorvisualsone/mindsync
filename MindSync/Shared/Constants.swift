import Foundation
import UIKit

/// Haptic feedback utilities for MindSync
enum HapticFeedback {
    /// Light impact feedback for mode changes and minor actions
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Medium impact feedback for session start/stop
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Heavy impact feedback for critical actions
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Success notification feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Error notification feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    /// Warning notification feedback
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

