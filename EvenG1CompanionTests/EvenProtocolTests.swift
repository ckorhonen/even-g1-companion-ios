import XCTest
@testable import EvenG1Companion

final class EvenProtocolTests: XCTestCase {
    func testUARTConstantsMatchG1Protocol() {
        XCTAssertEqual(EvenProtocol.uartServiceUUID, "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        XCTAssertEqual(EvenProtocol.writeCharacteristicUUID, "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        XCTAssertEqual(EvenProtocol.notifyCharacteristicUUID, "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    }

    func testBrightnessClampsToFirmwareRange() {
        XCTAssertEqual([UInt8](EvenProtocol.brightness(level: -5, auto: false)), [0x01, 0x00, 0x00])
        XCTAssertEqual([UInt8](EvenProtocol.brightness(level: 99, auto: true)), [0x01, 0x2A, 0x01])
    }

    func testDisplayTextPacketHeader() {
        let packets = EvenProtocol.displayTextPackets("Hello glasses", sequence: 0x7A)
        XCTAssertEqual(packets.count, 1)

        let bytes = [UInt8](packets[0])
        XCTAssertEqual(Array(bytes.prefix(9)), [0x4E, 0x7A, 0x01, 0x00, 0x71, 0x00, 0x00, 0x00, 0x01])
        XCTAssertEqual(String(decoding: packets[0].dropFirst(9), as: UTF8.self), "Hello glasses")
    }

    func testDisplayTextChunksDoNotSplitCharacters() {
        let text = "A🙂B🙂C🙂D"
        let packets = EvenProtocol.displayTextPackets(text, sequence: 0x01, maxPayloadBytes: 5)
        let decoded = packets
            .map { String(decoding: $0.dropFirst(9), as: UTF8.self) }
            .joined()
        XCTAssertEqual(decoded, text)
        XCTAssertGreaterThan(packets.count, 1)
    }

    func testStreamingLinePacketShape() {
        let packet = EvenProtocol.streamingLinePacket(text: "Ready", line: 2, sequence: 0x03, startsParagraph: true)
        let bytes = [UInt8](packet)

        XCTAssertEqual(bytes[0], 0x52)
        XCTAssertEqual(bytes[3], 0x03)
        XCTAssertEqual(bytes[7], 0x02)
        XCTAssertEqual(bytes[9], 0x01)
        XCTAssertEqual(bytes.last, 0x0A)
        XCTAssertEqual(String(decoding: packet.dropFirst(12).dropLast(), as: UTF8.self), "Ready")
    }

    func testVisibleStreamingWindowKeepsLastRows() {
        let text = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen"
        let window = EvenProtocol.visibleStreamingWindow(for: text, lineWidth: 12, visibleRows: 3)
        XCTAssertEqual(window.split(separator: "\n").count, 3)
        XCTAssertTrue(window.contains("fourteen"))
    }

    func testSettingsPackets() {
        XCTAssertEqual([UInt8](EvenProtocol.headUp(.none)), [0x08, 0x06, 0x00, 0x00, 0x03, 0x02])
        XCTAssertEqual([UInt8](EvenProtocol.doubleTap(.transcribe, sequence: 0x09)), [0x26, 0x06, 0x00, 0x09, 0x05, 0x05])
        XCTAssertEqual([UInt8](EvenProtocol.microphone(enabled: true)), [0x0E, 0x01])
        XCTAssertEqual(EvenProtocol.clearDisplayPackets(), [Data([0x50, 0x06, 0x00, 0x00, 0x01, 0x01]), Data([0x18])])
    }
}

