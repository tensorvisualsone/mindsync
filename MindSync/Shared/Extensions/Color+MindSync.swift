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
            // For custom, use white as fallback
            return .white
        }
    }
}

