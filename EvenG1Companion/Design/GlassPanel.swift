import SwiftUI

struct GlassPanel<Content: View>: View {
    var title: String?
    var systemImage: String?
    var tint: Color = .white.opacity(0.08)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || systemImage != nil {
                HStack(spacing: 9) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Spacer(minLength: 0)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 24))
    }
}

struct StatusBadge: View {
    var text: String
    var systemImage: String
    var color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(color.opacity(0.18)).interactive(), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                    Color(red: 0.05, green: 0.08, blue: 0.09).opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                Canvas { context, size in
                    let rows = 9
                    let columns = 7
                    for row in 0..<rows {
                        for column in 0..<columns {
                            let x = size.width * CGFloat(column) / CGFloat(columns - 1)
                            let y = size.height * CGFloat(row) / CGFloat(rows - 1)
                            let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                            let hue = Double((row + column) % 6) / 8.0
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(Color(hue: hue, saturation: 0.45, brightness: 0.75).opacity(0.22))
                            )
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()
        }
    }
}

