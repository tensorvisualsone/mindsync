import Foundation
import SwiftUI

/// App-wide design constants for consistent styling
enum AppConstants {
    
    // MARK: - Spacing
    
    /// Spacing values used throughout the app
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        /// Standard horizontal padding for views
        static let horizontalPadding: CGFloat = md
        
        /// Standard vertical padding for views
        static let verticalPadding: CGFloat = md
        
        /// Standard spacing between UI elements
        static let elementSpacing: CGFloat = md
        
        /// Standard spacing between sections
        static let sectionSpacing: CGFloat = lg
    }
    
    // MARK: - Corner Radius
    
    /// Corner radius values for rounded elements
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        
        /// Standard corner radius for cards and buttons
        static let card: CGFloat = medium
        
        /// Standard corner radius for buttons
        static let button: CGFloat = large
    }
    
    // MARK: - Typography
    
    /// Typography scale for consistent text styling
    enum Typography {
        /// Large title (e.g., main screen titles)
        static let largeTitle = Font.largeTitle.bold()
        
        /// Title (e.g., section headers)
        static let title = Font.title.bold()
        
        /// Title 2 (e.g., secondary headers)
        static let title2 = Font.title2.bold()
        
        /// Headline (e.g., button labels, important text)
        static let headline = Font.headline
        
        /// Body (e.g., main content text)
        static let body = Font.body
        
        /// Subheadline (e.g., secondary information)
        static let subheadline = Font.subheadline
        
        /// Caption (e.g., helper text, metadata)
        static let caption = Font.caption
        
        /// Caption 2 (e.g., fine print)
        static let caption2 = Font.caption2
    }
    
    // MARK: - Icon Sizes
    
    /// Standard icon sizes
    enum IconSize {
        static let small: CGFloat = 16
        static let medium: CGFloat = 24
        static let large: CGFloat = 40
        static let extraLarge: CGFloat = 60
        
        /// Standard icon size for buttons
        static let button: CGFloat = large
    }
    
    // MARK: - Animation
    
    /// Animation durations and styles
    enum Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.3)
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.5)
        
        /// Spring animation for interactive elements
        static let spring: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.8)
        
        /// Linear animation for light updates (high frequency)
        static let linearLight: SwiftUI.Animation = .linear(duration: 0.08)
    }
    
    // MARK: - Opacity
    
    /// Standard opacity values
    enum Opacity {
        static let disabled: Double = 0.5
        static let secondary: Double = 0.7
        static let tertiary: Double = 0.5
        
        /// Background opacity for overlays and cards
        static let cardBackground: Double = 0.3
        
        /// Background opacity for buttons
        static let buttonBackground: Double = 0.3
    }
    
    // MARK: - Shadows
    
    /// Shadow styles
    enum Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.3), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }
    
    // MARK: - Minimum Touch Targets
    
    /// Accessibility: Minimum touch target sizes
    enum TouchTarget {
        static let minimum: CGFloat = 44  // Apple HIG minimum
        static let comfortable: CGFloat = 48
        static let large: CGFloat = 56
    }
}
