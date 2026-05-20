import Foundation

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

extension UInt8 {
    var paddedHex: String {
        "0x" + String(format: "%02X", self)
    }
}

