import SwiftUI

struct PulseDot: View {
    let color: Color
    let size: CGFloat
    let pulses: Bool

    init(color: Color, size: CGFloat = 8, pulses: Bool = true) {
        self.color = color
        self.size = size
        self.pulses = pulses
    }

    @State private var animate = false

    var body: some View {
        ZStack {
            if pulses {
                Circle()
                    .fill(color.opacity(0.35))
                    .frame(width: size * 2.2, height: size * 2.2)
                    .scaleEffect(animate ? 1.0 : 0.6)
                    .opacity(animate ? 0 : 0.7)
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            guard pulses else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        PulseDot(color: .green)
        PulseDot(color: .red, size: 12)
        PulseDot(color: .blue, size: 10, pulses: false)
    }
}
