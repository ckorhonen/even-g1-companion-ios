import Foundation

enum EvenProtocol {
    static let uartServiceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let writeCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let notifyCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    static let displayModeInit = Data([0x50, 0x06, 0x00, 0x00, 0x01, 0x01])
    static let streamingModeInit = Data([0x52, 0x06, 0x00, 0x00, 0x01, 0x01])
    static let streamingKeepalive = Data([0x53])
    static let exitToDashboard = Data([0x18])
    static let handshake = Data([0x4D, 0x01])

    static func clearDisplayPackets() -> [Data] {
        [displayModeInit, exitToDashboard]
    }

    static func brightness(level: Int, auto: Bool) -> Data {
        Data([0x01, UInt8(clamping: level.clamped(to: 0...42)), auto ? 0x01 : 0x00])
    }

    static func headUp(_ mode: HeadUpMode) -> Data {
        Data([0x08, 0x06, 0x00, 0x00, 0x03, mode.wireValue])
    }

    static func doubleTap(_ action: DoubleTapAction, sequence: UInt8) -> Data {
        Data([0x26, 0x06, 0x00, sequence, 0x05, action.wireValue])
    }

    static func microphone(enabled: Bool) -> Data {
        Data([0x0E, enabled ? 0x01 : 0x00])
    }

    static func displayTextPackets(
        _ text: String,
        sequence: UInt8,
        maxPayloadBytes: Int = 160
    ) -> [Data] {
        let bodyChunks = utf8Chunks(text.isEmpty ? " " : text, maxBytes: maxPayloadBytes)
        let total = UInt8(clamping: bodyChunks.count)

        var offset = 0
        return bodyChunks.enumerated().map { index, body in
            defer { offset += body.count }
            let charPosition = UInt16(clamping: offset)
            var packet = Data([
                0x4E,
                sequence,
                total,
                UInt8(clamping: index),
                0x71,
                UInt8(charPosition & 0x00FF),
                UInt8((charPosition & 0xFF00) >> 8),
                0x00,
                0x01
            ])
            packet.append(body)
            return packet
        }
    }

    static func streamingTextSessionPackets(_ text: String, sequence: inout UInt8) -> [Data] {
        var packets = [displayModeInit, streamingModeInit]
        let visibleText = visibleStreamingWindow(for: text)
        packets.append(streamingLinePacket(text: "\n", line: 1, sequence: next(&sequence), startsParagraph: true))
        packets.append(streamingLinePacket(text: visibleText, line: 2, sequence: next(&sequence), startsParagraph: true))
        packets.append(streamingKeepalive)
        return packets
    }

    static func streamingLinePacket(
        text: String,
        line: UInt8,
        sequence: UInt8,
        startsParagraph: Bool = false
    ) -> Data {
        let safeLine = min(max(line, 1), 2)
        let body = Data(text.utf8)
        let length = UInt8(truncatingIfNeeded: 12 + body.count + 1)
        var packet = Data([
            0x52,
            length,
            0x00,
            sequence,
            0x02,
            0x02,
            0x00,
            safeLine,
            0x00,
            startsParagraph ? 0x01 : 0x00,
            0x00,
            0x00
        ])
        packet.append(body)
        packet.append(0x0A)
        return packet
    }

    static func visibleStreamingWindow(for text: String, lineWidth: Int = 43, visibleRows: Int = 3) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return " " }

        var lines: [String] = []
        var current = ""

        for word in words {
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= lineWidth {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines.suffix(visibleRows).joined(separator: "\n")
    }

    private static func next(_ sequence: inout UInt8) -> UInt8 {
        let value = sequence
        sequence &+= 1
        return value
    }

    private static func utf8Chunks(_ text: String, maxBytes: Int) -> [Data] {
        let safeMax = max(maxBytes, 4)
        var chunks: [Data] = []
        var current = Data()

        for character in text {
            let characterData = Data(String(character).utf8)
            if !current.isEmpty, current.count + characterData.count > safeMax {
                chunks.append(current)
                current.removeAll(keepingCapacity: true)
            }
            current.append(characterData)
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.isEmpty ? [Data()] : chunks
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
