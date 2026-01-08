import SwiftUI
import Foundation

extension LightEvent.LightColor {
    /// Converts LightColor to SwiftUI Color
    /// - Parameter customRGB: Optional RGB values for custom color (0.0 - 1.0)
    func swiftUIColor(customRGB: (red: Double, green: Double, blue: Double)? = nil) -> Color {
        switch self {
        case .white:
            return .white
        case .red:
            return .red
        case .blue:
            return .blue
        case .green:
            return .green
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .custom:
            // Use custom RGB if provided, otherwise fallback to white
            if let rgb = customRGB {
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            }
            return .white
        }
    }
    
    /// Legacy method for backward compatibility (uses white for custom)
    var swiftUIColor: Color {
        swiftUIColor(customRGB: nil)
    }
}

// MARK: - MindSync Color Palette

extension Color {
    /// MindSync app color palette for consistent design
    
    // MARK: - Primary Colors
    
    /// Primary accent color - used for interactive elements, highlights
    static let mindSyncAccent = Color.accentColor
    
    /// Primary background color (adaptive for light/dark mode)
    static let mindSyncBackground = Color(.systemBackground)
    
    /// Secondary background color (adaptive)
    static let mindSyncSecondaryBackground = Color(.secondarySystemBackground)
    
    /// Tertiary background color (adaptive)
    static let mindSyncTertiaryBackground = Color(.tertiarySystemBackground)
    
    // MARK: - Semantic Colors
    
    /// Success color (e.g., completed states)
    static let mindSyncSuccess = Color.green
    
    /// Warning color (e.g., thermal warnings)
    static let mindSyncWarning = Color.orange
    
    /// Error color (e.g., error states, critical warnings)
    static let mindSyncError = Color.red
    
    /// Info color (e.g., informational messages)
    static let mindSyncInfo = Color.blue
    
    // MARK: - Text Colors
    
    /// Primary text color (adaptive)
    static let mindSyncPrimaryText = Color(.label)
    
    /// Secondary text color (adaptive)
    static let mindSyncSecondaryText = Color(.secondaryLabel)
    
    /// Tertiary text color (adaptive)
    static let mindSyncTertiaryText = Color(.tertiaryLabel)
    
    // MARK: - Light Source Colors
    
    /// Flashlight accent color (yellow/amber)
    static let mindSyncFlashlight = Color.yellow
    
    // MARK: - Mode Colors
    
    /// Alpha mode color (relaxation - green)
    static let mindSyncAlpha = Color.green
    
    /// Theta mode color (deep meditation - purple)
    static let mindSyncTheta = Color.purple
    
    /// Gamma mode color (focus - cyan/blue)
    static let mindSyncGamma = Color.cyan
    
    /// Cinematic mode color (flow state - orange/amber)
    static let mindSyncCinematic = Color.orange
    
    // MARK: - Session Colors
    
    /// Color for active/running sessions
    static let mindSyncSessionActive = Color.green
    
    /// Color for paused sessions
    static let mindSyncSessionPaused = Color.orange
    
    /// Color for stopped/ended sessions
    static let mindSyncSessionStopped = Color.gray
    
    // MARK: - Card & Surface Colors
    
    /// Card background color with adaptive opacity
    static func mindSyncCardBackground(opacity: Double = 0.3) -> Color {
        Color(.systemGray6).opacity(opacity)
    }
    
    /// Button background color with adaptive opacity
    static func mindSyncButtonBackground(color: Color = .blue, opacity: Double = 0.3) -> Color {
        color.opacity(opacity)
    }
}

// MARK: - Entrainment Mode Color Extension

extension EntrainmentMode {
    /// Returns the theme color for each entrainment mode
    var themeColor: Color {
        switch self {
        case .alpha:
            return .mindSyncAlpha
        case .theta:
            return .mindSyncTheta
        case .gamma:
            return .mindSyncGamma
        case .cinematic:
            return .mindSyncCinematic
        }
    }
}

// MARK: - Light Source Color Extension

extension LightSource {
    /// Returns the theme color for each light source
    var themeColor: Color {
        return .mindSyncFlashlight
    }
}
