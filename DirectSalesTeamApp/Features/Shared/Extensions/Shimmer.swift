import SwiftUI

public struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.white.opacity(0.3)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: phase),
                                    .init(color: .white, location: phase + 0.1),
                                    .init(color: .white, location: phase + 0.2),
                                    .init(color: .clear, location: phase + 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    public func shimmering() -> some View {
        modifier(Shimmer())
    }
}
