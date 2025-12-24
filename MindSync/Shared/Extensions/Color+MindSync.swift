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

