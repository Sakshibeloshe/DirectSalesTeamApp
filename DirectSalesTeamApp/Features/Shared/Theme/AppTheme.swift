import SwiftUI

// MARK: - Color Palette
extension Color {
    // Brand
    static let brandBlue      = Color(hex: "#1A56DB")
    static let brandBlueSoft  = Color(hex: "#EBF0FF")

    // Status colors
    static let statusNew      = Color(hex: "#1A56DB")
    static let statusNewBg    = Color(hex: "#EBF0FF")
    static let statusPending  = Color(hex: "#C27803")
    static let statusPendingBg = Color(hex: "#FDF6EC")
    static let statusSubmitted = Color(hex: "#057A55")
    static let statusSubmittedBg = Color(hex: "#E8F5EF")
    static let statusRejected = Color(hex: "#C81E1E")
    static let statusRejectedBg = Color(hex: "#FEF2F2")
    static let statusApproved = Color(hex: "#057A55")
    static let statusApprovedBg = Color(hex: "#E8F5EF")
    static let statusDisbursed = Color(hex: "#5521B5")
    static let statusDisbursedBg = Color(hex: "#F0EBFF")

    // Neutral
    static let textPrimary    = Color(hex: "#111928")
    static let textSecondary  = Color(hex: "#6B7280")
    static let textTertiary   = Color(hex: "#9CA3AF")
    static let surfacePrimary = Color(hex: "#FFFFFF")
    static let surfaceSecondary = Color(hex: "#F9FAFB")
    static let surfaceTertiary = Color(hex: "#F3F4F6")
    static let borderLight    = Color(hex: "#E5E7EB")
    static let borderMedium   = Color(hex: "#D1D5DB")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
struct AppFont {
    static func largeTitle()   -> Font { .system(size: 28, weight: .bold,     design: .default) }
    static func title()        -> Font { .system(size: 22, weight: .bold,     design: .default) }
    static func title2()       -> Font { .system(size: 20, weight: .semibold, design: .default) }
    static func headline()     -> Font { .system(size: 16, weight: .semibold, design: .default) }
    static func body()         -> Font { .system(size: 15, weight: .regular,  design: .default) }
    static func bodyMedium()   -> Font { .system(size: 15, weight: .medium,   design: .default) }
    static func subhead()      -> Font { .system(size: 13, weight: .regular,  design: .default) }
    static func subheadMed()   -> Font { .system(size: 13, weight: .medium,   design: .default) }
    static func caption()      -> Font { .system(size: 12, weight: .regular,  design: .default) }
    static func captionMed()   -> Font { .system(size: 12, weight: .medium,   design: .default) }
    static func mono()         -> Font { .system(size: 13, weight: .regular,  design: .monospaced) }
}

// MARK: - Spacing
struct AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat  = 8
    static let sm: CGFloat  = 12
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius
struct AppRadius {
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 24
    static let full: CGFloat = 999
}

// MARK: - Shadow
struct AppShadow {
    static let card = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    static let soft = Shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    func softShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}
