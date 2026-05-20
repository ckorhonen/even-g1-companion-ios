import SwiftUI

struct LogView: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            if bluetooth.logEntries.isEmpty {
                                GlassPanel(tint: .white.opacity(0.08)) {
                                    Text("No log entries yet.")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(bluetooth.logEntries) { entry in
                                    LogRow(entry: entry, timestamp: formatter.string(from: entry.date))
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 96)
                    }
                }
            }
            .navigationTitle("Log")
        }
    }
}

private struct LogRow: View {
    let entry: GlassesLogEntry
    let timestamp: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.direction.rawValue)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 24)
                .glassEffect(.regular.tint(color.opacity(0.16)), in: .capsule)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(timestamp)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(entry.detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.white.opacity(0.07)), in: .rect(cornerRadius: 18))
    }

    private var color: Color {
        switch entry.direction {
        case .inbound: .green
        case .outbound: .cyan
        case .system: .orange
        }
    }
}
