import Foundation

/// Mathematical utility functions for interpolation and smoothing
enum MathHelpers {
    /// Smoothstep interpolation function
    /// Clamps input to 0.0...1.0 and applies smoothstep curve: t * t * (3 - 2 * t)
    /// - Parameter t: Input value (typically progress from 0.0 to 1.0)
    /// - Returns: Smoothly interpolated value between 0.0 and 1.0
    static func smoothstep(_ t: Double) -> Double {
        let clamped = max(0.0, min(1.0, t))
        return clamped * clamped * (3.0 - 2.0 * clamped)
    }
}

