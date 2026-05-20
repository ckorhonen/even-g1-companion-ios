import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        VStack(spacing: 18) {
                            GlassPanel(title: "Transport", systemImage: "antenna.radiowaves.left.and.right", tint: .cyan.opacity(0.10)) {
                                VStack(alignment: .leading, spacing: 12) {
                                    DiagnosticRow(label: "Bluetooth", value: bluetooth.centralState.displayName)
                                    DiagnosticRow(label: "Phase", value: bluetooth.phase.label)
                                    DiagnosticRow(label: "Pairs", value: "\(bluetooth.discoveredPairs.count)")
                                    DiagnosticRow(label: "Writable", value: bluetooth.isReady ? "yes" : "no")
                                }
                            }

                            GlassPanel(title: "Recent Events", systemImage: "waveform", tint: .green.opacity(0.10)) {
                                if bluetooth.recentEvents.isEmpty {
                                    Text("No glasses events received yet.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(bluetooth.recentEvents) { event in
                                            EventRow(event: event)
                                        }
                                    }
                                }
                            }

                            GlassPanel(title: "Protocol", systemImage: "chevron.left.forwardslash.chevron.right", tint: .orange.opacity(0.10)) {
                                VStack(alignment: .leading, spacing: 10) {
                                    DiagnosticRow(label: "Service", value: EvenProtocol.uartServiceUUID)
                                    DiagnosticRow(label: "Write", value: EvenProtocol.writeCharacteristicUUID)
                                    DiagnosticRow(label: "Notify", value: EvenProtocol.notifyCharacteristicUUID)
                                }
                                .textSelection(.enabled)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 96)
                    }
                }
            }
            .navigationTitle("Diagnostics")
        }
    }
}

private struct DiagnosticRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.callout.monospaced())
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}

private struct EventRow: View {
    let event: EvenEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.side?.shortLabel ?? "-")
                .font(.caption.monospaced().weight(.bold))
                .frame(width: 24, height: 24)
                .glassEffect(.regular.tint(.green.opacity(0.18)), in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.weight(.semibold))
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(event.rawHex)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}
