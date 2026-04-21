import SwiftUI

struct AvatarView: View {
    let initials: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)

            Circle()
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// Computed avatar color from name (deterministic)
extension String {
    var avatarColor: Color {
        let palette: [Color] = [
            Color(hex: "#7C3AED"),
            Color(hex: "#DB2777"),
            Color(hex: "#059669"),
            Color(hex: "#D97706"),
            Color(hex: "#2563EB"),
            Color(hex: "#DC2626"),
            Color(hex: "#0891B2"),
            Color(hex: "#65A30D"),
        ]
        let index = abs(self.hashValue) % palette.count
        return palette[index]
    }
}
