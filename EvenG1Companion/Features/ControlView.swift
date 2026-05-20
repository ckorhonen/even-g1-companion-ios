import SwiftUI

struct ControlView: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore

    @State private var hudTitle = "Codex"
    @State private var hudBody = "Build running. Next checkpoint in 5 min."
    @State private var streamText = "Thinking through the iOS port. BLE transport is ready, notifications stay out of scope."
    @State private var micEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    GlassEffectContainer(spacing: 18) {
                        VStack(spacing: 18) {
                            HeroPanel()
                            PairingPanel()
                            ComposerPanel(
                                hudTitle: $hudTitle,
                                hudBody: $hudBody,
                                streamText: $streamText
                            )
                            FirmwarePanel(micEnabled: $micEnabled)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 96)
                    }
                }
            }
            .navigationTitle("Even G1")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        bluetooth.clearDisplay()
                    } label: {
                        Image(systemName: "rectangle.slash")
                    }
                    .accessibilityLabel("Clear glasses display")
                }
            }
        }
    }
}

private struct HeroPanel: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore

    var body: some View {
        GlassPanel(tint: .cyan.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Even G1")
                            .font(.largeTitle.bold())
                            .accessibilityIdentifier("EvenG1Title")
                        Text("iOS 26 companion surface for BLE control, app-owned HUDs, and safe firmware settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "eyeglasses")
                        .font(.system(size: 34, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.cyan)
                        .frame(width: 54, height: 54)
                        .glassEffect(.regular.tint(.cyan.opacity(0.16)), in: .circle)
                }

                HStack(spacing: 8) {
                    StatusBadge(
                        text: bluetooth.phase.label,
                        systemImage: bluetooth.isReady ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right",
                        color: bluetooth.isReady ? .green : .cyan
                    )
                    StatusBadge(
                        text: bluetooth.centralState.displayName,
                        systemImage: "antenna.radiowaves.left.and.right",
                        color: .orange
                    )
                }
            }
        }
    }
}

private struct PairingPanel: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore

    var body: some View {
        GlassPanel(title: "Glasses", systemImage: "dot.radiowaves.left.and.right", tint: .green.opacity(0.10)) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        bluetooth.isScanning ? bluetooth.stopScanning() : bluetooth.startScanning()
                    } label: {
                        Label(bluetooth.isScanning ? "Stop" : "Scan", systemImage: bluetooth.isScanning ? "stop.fill" : "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        bluetooth.disconnect()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .frame(width: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Disconnect")
                }

                if bluetooth.discoveredPairs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No pair found")
                            .font(.subheadline.weight(.semibold))
                        Text("Power on both temples and keep them near the phone. The scan filters for the Even UART service.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(bluetooth.discoveredPairs) { pair in
                        PairRow(pair: pair)
                    }
                }
            }
        }
    }
}

private struct PairRow: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore
    let pair: GlassesPair

    var body: some View {
        Button {
            bluetooth.connect(to: pair)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pair.isComplete ? "link.circle.fill" : "link.circle")
                    .font(.title2)
                    .foregroundStyle(pair.isComplete ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pair.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(pair.detail.isEmpty ? "Waiting for both sides" : pair.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    sideLabel("L", connected: pair.leftConnected, rssi: pair.leftRSSI)
                    sideLabel("R", connected: pair.rightConnected, rssi: pair.rightRSSI)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!pair.isComplete)
    }

    private func sideLabel(_ label: String, connected: Bool, rssi: Int?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? .green : .secondary)
                .frame(width: 7, height: 7)
            Text("\(label) \(rssi.map(String.init) ?? "-")")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct ComposerPanel: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore
    @Binding var hudTitle: String
    @Binding var hudBody: String
    @Binding var streamText: String

    var body: some View {
        GlassPanel(title: "HUD Composer", systemImage: "rectangle.and.text.magnifyingglass", tint: .indigo.opacity(0.10)) {
            VStack(spacing: 12) {
                TextField("Title", text: $hudTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("Card text", text: $hudBody, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button {
                        bluetooth.sendHUD(title: hudTitle, body: hudBody)
                    } label: {
                        Label("Send Card", systemImage: "arrow.up.forward.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        bluetooth.clearDisplay()
                    } label: {
                        Image(systemName: "rectangle.slash")
                            .frame(width: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Clear card")
                }

                Divider()

                TextField("Streaming text", text: $streamText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)

                Button {
                    bluetooth.streamText(streamText)
                } label: {
                    Label("Stream Reply", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }
}

private struct FirmwarePanel: View {
    @EnvironmentObject private var bluetooth: GlassesBluetoothStore
    @Binding var micEnabled: Bool

    var body: some View {
        GlassPanel(title: "Safe Settings", systemImage: "slider.horizontal.3", tint: .orange.opacity(0.10)) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Brightness", systemImage: "sun.max")
                        Spacer()
                        Text("\(bluetooth.brightnessLevel)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(bluetooth.brightnessLevel) },
                            set: { bluetooth.brightnessLevel = Int($0.rounded()) }
                        ),
                        in: 0...42,
                        step: 1
                    )
                    Toggle("Auto brightness", isOn: $bluetooth.autoBrightness)
                    Button {
                        bluetooth.sendBrightness()
                    } label: {
                        Label("Apply Brightness", systemImage: "sun.max.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }

                Divider()

                Picker("Tilt-up", selection: $bluetooth.headUpMode) {
                    ForEach(HeadUpMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    bluetooth.sendHeadUpMode()
                } label: {
                    Label("Apply Tilt-up Mode", systemImage: "arrow.up.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Picker("Double tap", selection: $bluetooth.doubleTapAction) {
                    ForEach(DoubleTapAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }

                Button {
                    bluetooth.sendDoubleTapAction()
                } label: {
                    Label("Apply Double-tap Action", systemImage: "hand.tap")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Toggle("Mic command enabled", isOn: Binding(
                    get: { micEnabled },
                    set: { enabled in
                        micEnabled = enabled
                        bluetooth.setMicrophone(enabled: enabled)
                    }
                ))
            }
        }
    }
}
