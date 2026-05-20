@preconcurrency import CoreBluetooth
import Foundation

final class GlassesBluetoothStore: NSObject, ObservableObject {
    @Published private(set) var centralState: CBManagerState = .unknown
    @Published private(set) var phase: ConnectionPhase = .idle
    @Published private(set) var discoveredPairs: [GlassesPair] = []
    @Published private(set) var recentEvents: [EvenEvent] = []
    @Published private(set) var logEntries: [GlassesLogEntry] = []

    @Published var brightnessLevel = 21
    @Published var autoBrightness = false
    @Published var headUpMode: HeadUpMode = .none
    @Published var doubleTapAction: DoubleTapAction = .transcribe

    private let uartServiceUUID = CBUUID(string: EvenProtocol.uartServiceUUID)
    private let writeCharacteristicUUID = CBUUID(string: EvenProtocol.writeCharacteristicUUID)
    private let notifyCharacteristicUUID = CBUUID(string: EvenProtocol.notifyCharacteristicUUID)

    private var centralManager: CBCentralManager?
    private var partialPairs: [String: PartialPair] = [:]
    private var pendingPeripheralSides: [UUID: GlassesSide] = [:]
    private var pendingPairID: String?
    private var connectedPeripheralIDs: [GlassesSide: UUID] = [:]
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var writeCharacteristics: [GlassesSide: CBCharacteristic] = [:]
    private var notifyCharacteristics: [GlassesSide: CBCharacteristic] = [:]
    private var sequence: UInt8 = 0

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.ckorhonen.eveng1companion.central"]
        )
        appendSystem("Bluetooth manager initialized", detail: "Waiting for CoreBluetooth state")
    }

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var isReady: Bool {
        !writeCharacteristics.isEmpty
    }

    func startScanning() {
        guard let centralManager else {
            appendSystem("Scan unavailable", detail: "CoreBluetooth manager is not ready")
            return
        }

        guard centralManager.state == .poweredOn else {
            phase = .unavailable(centralManager.state.displayName)
            appendSystem("Scan blocked", detail: centralManager.state.displayName)
            return
        }

        partialPairs.removeAll()
        discoveredPairs.removeAll()
        centralManager.scanForPeripherals(
            withServices: [uartServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        phase = .scanning
        appendSystem("Scanning", detail: "Looking for Even UART service")
    }

    func stopScanning() {
        centralManager?.stopScan()
        if case .scanning = phase {
            phase = .idle
        }
        appendSystem("Scan stopped", detail: "\(discoveredPairs.count) pair candidates")
    }

    func connect(to pair: GlassesPair) {
        guard let centralManager else { return }
        guard let partialPair = partialPairs[pair.id], partialPair.isComplete else {
            appendSystem("Connect blocked", detail: "Both left and right temples must be visible")
            return
        }

        pendingPairID = pair.id
        phase = .connecting(pair.displayName)
        centralManager.stopScan()

        for side in GlassesSide.allCases {
            guard let peripheral = partialPair.peripheral(for: side) else { continue }
            pendingPeripheralSides[peripheral.identifier] = side
            peripheralsByID[peripheral.identifier] = peripheral
            centralManager.connect(
                peripheral,
                options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
            )
        }

        appendSystem("Connecting", detail: pair.detail)
    }

    func disconnect() {
        guard let centralManager else { return }
        for id in connectedPeripheralIDs.values {
            if let peripheral = peripheralsByID[id] {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
        connectedPeripheralIDs.removeAll()
        writeCharacteristics.removeAll()
        notifyCharacteristics.removeAll()
        phase = .disconnected
        publishPairs()
        appendSystem("Disconnected", detail: "Cancelled active peripheral links")
    }

    func sendHUD(title: String, body: String) {
        let content = [title, body]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let packets = EvenProtocol.displayTextPackets(content, sequence: nextSequence())
        write(packets, label: "HUD card")
    }

    func streamText(_ text: String) {
        var localSequence = sequence
        let packets = EvenProtocol.streamingTextSessionPackets(text, sequence: &localSequence)
        sequence = localSequence
        write(packets, label: "Streaming text")
    }

    func clearDisplay() {
        write(EvenProtocol.clearDisplayPackets(), label: "Clear display")
    }

    func sendBrightness() {
        let packet = EvenProtocol.brightness(level: brightnessLevel, auto: autoBrightness)
        write([packet], label: "Brightness \(brightnessLevel)")
    }

    func sendHeadUpMode() {
        write([EvenProtocol.headUp(headUpMode)], label: "Head-up \(headUpMode.label)")
    }

    func sendDoubleTapAction() {
        write([EvenProtocol.doubleTap(doubleTapAction, sequence: nextSequence())], label: "Double-tap \(doubleTapAction.label)")
    }

    func setMicrophone(enabled: Bool) {
        write([EvenProtocol.microphone(enabled: enabled)], label: enabled ? "Mic on" : "Mic off")
    }

    private func nextSequence() -> UInt8 {
        let value = sequence
        sequence &+= 1
        return value
    }

    private func write(_ packets: [Data], label: String) {
        guard !writeCharacteristics.isEmpty else {
            appendSystem("Not connected", detail: "Skipped \(label)")
            return
        }

        for packet in packets {
            for side in GlassesSide.allCases {
                guard
                    let id = connectedPeripheralIDs[side],
                    let peripheral = peripheralsByID[id],
                    let characteristic = writeCharacteristics[side]
                else {
                    continue
                }

                let type: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse)
                    ? .withoutResponse
                    : .withResponse

                if type == .withoutResponse, !peripheral.canSendWriteWithoutResponse {
                    appendSystem("Write delayed", detail: "\(side.shortLabel) is flow-controlled")
                    continue
                }

                peripheral.writeValue(packet, for: characteristic, type: type)
                appendLog(
                    title: "\(label) \(side.shortLabel)",
                    detail: packet.hexString,
                    direction: .outbound
                )
            }
        }
    }

    private func publishPairs() {
        discoveredPairs = partialPairs
            .values
            .map { $0.model(connectedIDs: connectedPeripheralIDs) }
            .sorted { $0.channel.localizedStandardCompare($1.channel) == .orderedAscending }
    }

    private func appendSystem(_ title: String, detail: String) {
        appendLog(title: title, detail: detail, direction: .system)
    }

    private func appendLog(title: String, detail: String, direction: GlassesLogEntry.Direction) {
        let entry = GlassesLogEntry(date: Date(), title: title, detail: detail, direction: direction)
        logEntries.insert(entry, at: 0)
        if logEntries.count > 80 {
            logEntries.removeLast(logEntries.count - 80)
        }
    }

    private func side(for peripheral: CBPeripheral) -> GlassesSide? {
        if let pending = pendingPeripheralSides[peripheral.identifier] {
            return pending
        }
        if connectedPeripheralIDs[.left] == peripheral.identifier {
            return .left
        }
        if connectedPeripheralIDs[.right] == peripheral.identifier {
            return .right
        }
        return parseDeviceName(peripheral.name)?.side
    }

    private func parseDeviceName(_ name: String?) -> (pairID: String, channel: String, side: GlassesSide)? {
        guard let name else { return nil }
        let parts = name.split(separator: "_").map(String.init)
        guard parts.count >= 3 else { return nil }

        let channel = parts[1]
        let side: GlassesSide?
        if parts.contains("L") {
            side = .left
        } else if parts.contains("R") {
            side = .right
        } else {
            side = nil
        }

        guard let side else { return nil }
        return ("Pair_\(channel)", channel, side)
    }
}

extension GlassesBluetoothStore: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState = central.state
        appendSystem("Bluetooth \(central.state.displayName)", detail: central.state == .poweredOn ? "Ready to scan" : "Waiting")
        if central.state != .poweredOn, case .scanning = phase {
            phase = .unavailable(central.state.displayName)
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        appendSystem("Bluetooth restored", detail: "CoreBluetooth restored prior state")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheralsByID[peripheral.identifier] = peripheral
                peripheral.delegate = self
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let parsed = parseDeviceName(peripheral.name) else { return }

        var pair = partialPairs[parsed.pairID] ?? PartialPair(id: parsed.pairID, channel: parsed.channel)
        pair.update(peripheral: peripheral, side: parsed.side, rssi: RSSI.intValue)
        partialPairs[parsed.pairID] = pair
        peripheralsByID[peripheral.identifier] = peripheral
        publishPairs()

        appendSystem(
            "Found \(parsed.side.shortLabel)",
            detail: "\(peripheral.name ?? "Unknown") RSSI \(RSSI.intValue)"
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let side = side(for: peripheral) else {
            appendSystem("Connected unknown", detail: peripheral.name ?? peripheral.identifier.uuidString)
            return
        }

        connectedPeripheralIDs[side] = peripheral.identifier
        peripheral.delegate = self
        peripheral.discoverServices([uartServiceUUID])
        publishPairs()
        appendSystem("Connected \(side.shortLabel)", detail: peripheral.name ?? peripheral.identifier.uuidString)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        appendSystem("Connect failed", detail: error?.localizedDescription ?? peripheral.identifier.uuidString)
        phase = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let side = side(for: peripheral) {
            connectedPeripheralIDs[side] = nil
            writeCharacteristics[side] = nil
            notifyCharacteristics[side] = nil
        }
        phase = .disconnected
        publishPairs()
        appendSystem("Disconnected", detail: error?.localizedDescription ?? (peripheral.name ?? peripheral.identifier.uuidString))
    }
}

extension GlassesBluetoothStore: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            appendSystem("Service discovery failed", detail: error.localizedDescription)
            return
        }

        guard let service = peripheral.services?.first(where: { $0.uuid == uartServiceUUID }) else {
            appendSystem("UART missing", detail: peripheral.name ?? peripheral.identifier.uuidString)
            return
        }

        peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            appendSystem("Characteristic discovery failed", detail: error.localizedDescription)
            return
        }

        guard let side = side(for: peripheral) else { return }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == writeCharacteristicUUID {
                writeCharacteristics[side] = characteristic
            } else if characteristic.uuid == notifyCharacteristicUUID {
                notifyCharacteristics[side] = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        if let writeCharacteristic = writeCharacteristics[side] {
            peripheral.writeValue(EvenProtocol.handshake, for: writeCharacteristic, type: .withoutResponse)
            appendLog(title: "Handshake \(side.shortLabel)", detail: EvenProtocol.handshake.hexString, direction: .outbound)
        }

        if writeCharacteristics[.left] != nil || writeCharacteristics[.right] != nil {
            let pairLabel = pendingPairID ?? "glasses"
            phase = .ready(pairLabel)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            appendSystem("Notify failed", detail: error.localizedDescription)
            return
        }
        appendSystem("Notify \(characteristic.isNotifying ? "on" : "off")", detail: peripheral.name ?? peripheral.identifier.uuidString)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            appendSystem("Read failed", detail: error.localizedDescription)
            return
        }

        guard let data = characteristic.value else { return }
        let event = EvenEvent.parse(data: data, side: side(for: peripheral))
        recentEvents.insert(event, at: 0)
        if recentEvents.count > 12 {
            recentEvents.removeLast(recentEvents.count - 12)
        }
        appendLog(title: event.name, detail: "\(event.detail) \(event.rawHex)", direction: .inbound)
    }
}

private struct PartialPair {
    let id: String
    var channel: String
    var leftPeripheral: CBPeripheral?
    var rightPeripheral: CBPeripheral?
    var leftRSSI: Int?
    var rightRSSI: Int?

    var isComplete: Bool {
        leftPeripheral != nil && rightPeripheral != nil
    }

    func peripheral(for side: GlassesSide) -> CBPeripheral? {
        switch side {
        case .left: leftPeripheral
        case .right: rightPeripheral
        }
    }

    mutating func update(peripheral: CBPeripheral, side: GlassesSide, rssi: Int) {
        switch side {
        case .left:
            leftPeripheral = peripheral
            leftRSSI = rssi
        case .right:
            rightPeripheral = peripheral
            rightRSSI = rssi
        }
    }

    func model(connectedIDs: [GlassesSide: UUID]) -> GlassesPair {
        GlassesPair(
            id: id,
            channel: channel,
            leftName: leftPeripheral?.name,
            rightName: rightPeripheral?.name,
            leftRSSI: leftRSSI,
            rightRSSI: rightRSSI,
            leftConnected: connectedIDs[.left] == leftPeripheral?.identifier,
            rightConnected: connectedIDs[.right] == rightPeripheral?.identifier
        )
    }
}

extension CBManagerState {
    var displayName: String {
        switch self {
        case .unknown: "Bluetooth unknown"
        case .resetting: "Bluetooth resetting"
        case .unsupported: "Bluetooth unsupported"
        case .unauthorized: "Bluetooth unauthorized"
        case .poweredOff: "Bluetooth off"
        case .poweredOn: "Bluetooth on"
        @unknown default: "Bluetooth unavailable"
        }
    }
}
