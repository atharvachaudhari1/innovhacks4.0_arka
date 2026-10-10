import SwiftUI

struct FitTheme {
    static let background = Color(red: 10/255, green: 10/255, blue: 10/255)
    static let cardBackground = Color(red: 24/255, green: 24/255, blue: 27/255)
    static let cardBorder = Color(red: 39/255, green: 39/255, blue: 42/255)
    
    // Exact Android Accent Lime
    static let accentLime = Color(red: 206/255, green: 255/255, blue: 0/255)
    static let textOnAccent = Color(red: 18/255, green: 18/255, blue: 18/255)
    
    // Heart Rate Red
    static let accentRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    
    // Text Hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 161/255, green: 161/255, blue: 170/255)
    static let textMuted = Color(red: 113/255, green: 113/255, blue: 122/255)
    
    // Skeleton Landmarks
    static let skeletonTeal = Color(red: 0/255, green: 127/255, blue: 139/255)
    static let skeletonYellow = Color(red: 255/255, green: 230/255, blue: 0/255)
    
    // Corner Radii matching Android CardViews (16dp - 20dp)
    static let radiusLarge: CGFloat = 20
    static let radiusMedium: CGFloat = 16
    static let radiusSmall: CGFloat = 12
    static let radiusPill: CGFloat = 999
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
