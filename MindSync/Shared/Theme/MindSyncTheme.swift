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


