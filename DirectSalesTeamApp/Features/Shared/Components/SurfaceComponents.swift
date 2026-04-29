import SwiftUI

struct DSTHeaderGradientBackground: View {
    var height: CGFloat = 230

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.headerBlueTop,
                    Color.headerBlueMid,
                    Color.headerBlueBottom
                ],
                startPoint: UnitPoint(x: 0.15, y: 0.0),
                endPoint: UnitPoint(x: 0.95, y: 0.88)
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.28),
                    .white.opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.18, y: 0.02),
                startRadius: 10,
                endRadius: 240
            )
            .offset(x: -18, y: -24)

            LinearGradient(
                colors: [
                    .white.opacity(0.10),
                    .clear,
                    Color.brandBlueSoft.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.20),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.16),
                startRadius: 0,
                endRadius: 140
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.surfaceSecondary.opacity(0.18),
                    Color.surfaceSecondary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .ignoresSafeArea(edges: .top)
    }
}

struct DSTPageContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceSecondary.ignoresSafeArea()
            DSTHeaderGradientBackground(height: 220)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(title)
                            .font(AppFont.largeTitle())
                            .foregroundColor(.white)
                        Text("Built for confident selling, fast tracking, and transparent follow-through.")
                            .font(AppFont.subhead())
                            .foregroundColor(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)

                    content
                        .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
    }
}

struct DSTSurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(AppSpacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
    }
}

struct DSTSectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.headline())
                .foregroundColor(Color.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
            }
        }
    }
}

struct DSTPrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.bodyMedium())
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color.mainBlue, Color.secondaryBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .elevatedCardShadow()
    }
}

// MARK: - Skeleton Loading Components
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 400)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

//extension View {
//    func shimmering() -> some View {
//        modifier(ShimmerModifier())
//    }
//}

struct DSTSkeletonRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 140, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 220, height: 10)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
        .shimmering()
    }
}

struct DSTSkeletonList: View {
    var count: Int = 5
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                DSTSkeletonRow()
            }
        }
    }
}
