import SwiftUI
import Foundation

extension LightEvent.LightColor {
    /// Converts LightColor to SwiftUI Color
    var swiftUIColor: Color {
        switch self {
        case .white:
            return .white
        case .red:
            return .red
        case .blue:
            return .blue
        case .green:
            return .green
        case .custom:
            // TODO: Custom color functionality not yet implemented
            // For now, use white as fallback until RGB cycle feature is added
            return .white
        }
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
    
    /// Screen accent color (blue)
    static let mindSyncScreen = Color.blue
    
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
        switch self {
        case .flashlight:
            return .mindSyncFlashlight
        case .screen:
            return .mindSyncScreen
        }
    }
}
