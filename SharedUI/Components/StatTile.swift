import SwiftUI

struct StatTile: View {
    let label: String
    let value: String
    let sub: String?
    let action: (() -> Void)?

    init(_ label: String, value: String, sub: String? = nil, action: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.sub = sub
        self.action = action
    }

    @State private var isHovered = false

    var body: some View {
        if let action {
            #if os(macOS)
            Button(action: action) { tile }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
            #else
            Button(action: action) { tile }
                .buttonStyle(.plain)
            #endif
        } else {
            tile
        }
    }

    @ViewBuilder
    private var tile: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TTColors.text2)
            Text(value)
                .font(.ttMonoTitle(22))
                .foregroundStyle(TTColors.text)
                .monospacedDigit()
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(TTColors.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ttSurface(cornerRadius: TTRadius.md)
        .overlay(alignment: .topTrailing) {
            if action != nil {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(TTColors.text3)
                    .padding(8)
            }
        }
        .overlay {
            if isHovered {
                RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                    .fill(TTColors.fill3)
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        StatTile("Stundensatz", value: "85 €", sub: "Pro Stunde", action: {})
        StatTile("Budget", value: "20h", sub: "Std.-Budget", action: {})
    }
    .padding()
}
