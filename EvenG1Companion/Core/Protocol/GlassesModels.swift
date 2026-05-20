import Foundation

enum GlassesSide: String, CaseIterable, Identifiable, Hashable {
    case left
    case right

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .left: "L"
        case .right: "R"
        }
    }
}

struct GlassesPair: Identifiable, Equatable {
    let id: String
    var channel: String
    var leftName: String?
    var rightName: String?
    var leftRSSI: Int?
    var rightRSSI: Int?
    var leftConnected: Bool
    var rightConnected: Bool

    var isComplete: Bool {
        leftName != nil && rightName != nil
    }

    var displayName: String {
        "Pair \(channel)"
    }

    var detail: String {
        [leftName, rightName]
            .compactMap { $0 }
            .joined(separator: " + ")
    }
}

enum ConnectionPhase: Equatable {
    case idle
    case scanning
    case connecting(String)
    case ready(String)
    case disconnected
    case unavailable(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .scanning: "Scanning"
        case .connecting(let pair): "Connecting \(pair)"
        case .ready(let pair): "Ready \(pair)"
        case .disconnected: "Disconnected"
        case .unavailable(let reason): reason
        }
    }
}

enum HeadUpMode: String, CaseIterable, Identifiable {
    case dashboard
    case none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: "Dashboard"
        case .none: "Companion"
        }
    }

    var wireValue: UInt8 {
        switch self {
        case .dashboard: 0x00
        case .none: 0x02
        }
    }
}

enum DoubleTapAction: String, CaseIterable, Identifiable {
    case none
    case dashboard
    case transcribe
    case translate
    case teleprompter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .dashboard: "Dashboard"
        case .transcribe: "Transcribe"
        case .translate: "Translate"
        case .teleprompter: "Teleprompter"
        }
    }

    var wireValue: UInt8 {
        switch self {
        case .none: 0x00
        case .translate: 0x02
        case .teleprompter: 0x03
        case .dashboard: 0x04
        case .transcribe: 0x05
        }
    }
}

struct GlassesLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let direction: Direction

    enum Direction: String {
        case inbound = "RX"
        case outbound = "TX"
        case system = "SYS"
    }
}

struct EvenEvent: Identifiable, Equatable {
    let id = UUID()
    let side: GlassesSide?
    let name: String
    let detail: String
    let rawHex: String

    static func parse(data: Data, side: GlassesSide?) -> EvenEvent {
        let bytes = [UInt8](data)
        let raw = data.hexString

        guard let opcode = bytes.first else {
            return EvenEvent(side: side, name: "Empty packet", detail: "", rawHex: raw)
        }

        if opcode == 0xF5, bytes.count > 1 {
            switch bytes[1] {
            case 0x00:
                return EvenEvent(side: side, name: "Close / home", detail: "Active feature closed", rawHex: raw)
            case 0x02:
                return EvenEvent(side: side, name: "Tilt up", detail: "Dashboard opened", rawHex: raw)
            case 0x03:
                return EvenEvent(side: side, name: "Tilt down", detail: "Dashboard closed", rawHex: raw)
            case 0x12 where bytes.count > 2:
                return EvenEvent(side: side, name: "Brightness echo", detail: "Level \(bytes[2])", rawHex: raw)
            case 0x17:
                return EvenEvent(side: side, name: "Voice press", detail: "Long-press start", rawHex: raw)
            case 0x18:
                return EvenEvent(side: side, name: "Voice release", detail: "Long-press release", rawHex: raw)
            case 0x20:
                return EvenEvent(side: side, name: "Host double-tap", detail: "Configured host action opened", rawHex: raw)
            default:
                return EvenEvent(side: side, name: "F5 event", detail: "Subcommand 0x\(String(bytes[1], radix: 16))", rawHex: raw)
            }
        }

        if opcode == 0xF1 {
            return EvenEvent(side: side, name: "Mic audio", detail: "\(bytes.count) bytes", rawHex: raw)
        }

        return EvenEvent(side: side, name: "Packet 0x\(String(opcode, radix: 16))", detail: "\(bytes.count) bytes", rawHex: raw)
    }
}

