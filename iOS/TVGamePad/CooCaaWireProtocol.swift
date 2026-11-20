import Foundation

/// Encoder/decoder for the proprietary TiMessage framing recovered from
/// CooKaa 1.4.5. Lengths and integer header values are big-endian.
enum CooCaaWireProtocol {
    static let discoveryPort: UInt16 = 64315
    static let tcpPort: UInt16 = 62015

    static let registerMethod: UInt8 = 112
    static let keyDownMethod: UInt8 = 4
    static let keyUpMethod: UInt8 = 3
    static let responseOK: UInt8 = 0xF0

    static let sequenceHeader: UInt8 = 0xFE
    static let eventHeader: UInt8 = 16
    static let authKeyHeader: UInt8 = 7
    static let deviceNameHeader: UInt8 = 10

    struct Advertisement: Equatable {
        let address: String
        let deviceName: String
    }

    enum ProtocolError: Error {
        case malformedFrame
        case unsupportedAdvertisement
        case invalidAddress
    }

    /// TV discovery payload: Ti class id 3, header 1 = "ip:62015",
    /// header 10 = Android Build.MODEL.
    static func decodeAdvertisement(_ data: Data) throws -> Advertisement {
        guard let message = decodeMessage(data),
              message.method == 3,
              let addressBytes = message.headers[1],
              let nameBytes = message.headers[10],
              let address = String(data: addressBytes, encoding: .utf8),
              let name = String(data: nameBytes, encoding: .utf8),
              address.contains(":") else {
            throw ProtocolError.unsupportedAdvertisement
        }
        return Advertisement(address: address, deviceName: name)
    }

    /// Registration request used by TiVirtualKeypad:
    /// method 112, header 7 = opaque client key, header 10 = display name.
    static func makeRegistration(key: Data, deviceName: String, sequence: UInt32) -> Data {
        encodeMessage(
            method: registerMethod,
            headers: [
                (authKeyHeader, key),
                (deviceNameHeader, Data(deviceName.utf8)),
                (sequenceHeader, bigEndian(sequence))
            ]
        )
    }

    /// TiVirtualKeypadEvent maps method 4 to KeyEvent ACTION_DOWN and
    /// method 3 to ACTION_UP. Header 16 contains a 32-bit Android key code.
    static func makeKeyEvent(androidKeyCode: Int32, pressed: Bool, sequence: UInt32) -> Data {
        encodeMessage(
            method: pressed ? keyDownMethod : keyUpMethod,
            headers: [
                (eventHeader, bigEndian(UInt32(bitPattern: androidKeyCode))),
                (sequenceHeader, bigEndian(sequence))
            ]
        )
    }

    /// Returns the complete frame size once the outer length field is available.
    /// The TCP stream may deliver only part of a frame or several frames at once.
    static func frameLength(in data: Data) -> Int? {
        guard data.count >= 2 else { return nil }
        var cursor = 1
        guard let payloadLength = readLength(data, cursor: &cursor) else { return nil }
        return cursor + payloadLength
    }

    static func decodeMessage(_ data: Data) -> (method: UInt8, headers: [UInt8: Data])? {
        guard data.count >= 2 else { return nil }
        let method = data[0]
        var cursor = 1
        guard let totalLength = readLength(data, cursor: &cursor),
              totalLength >= 0,
              cursor + totalLength <= data.count else { return nil }
        let end = cursor + totalLength
        var headers: [UInt8: Data] = [:]

        while cursor < end {
            let type = data[cursor]
            cursor += 1
            guard let length = readLength(data, cursor: &cursor),
                  length >= 0, cursor + length <= end else { return nil }
            headers[type] = data.subdata(in: cursor..<(cursor + length))
            cursor += length
        }
        return (method, headers)
    }

    private static func encodeMessage(method: UInt8, headers: [(UInt8, Data)]) -> Data {
        var payload = Data()
        for (type, value) in headers {
            payload.append(type)
            payload.append(encodeLength(value.count))
            payload.append(value)
        }
        var frame = Data([method])
        frame.append(encodeLength(payload.count))
        frame.append(payload)
        return frame
    }

    private static func encodeLength(_ length: Int) -> Data {
        if length <= 127 {
            return Data([UInt8(length)])
        }
        return Data([UInt8(((length >> 8) & 0x7F) | 0x80), UInt8(length & 0xFF)])
    }

    private static func readLength(_ data: Data, cursor: inout Int) -> Int? {
        guard cursor < data.count else { return nil }
        let first = data[cursor]
        cursor += 1
        if first & 0x80 == 0 { return Int(first) }
        guard cursor < data.count else { return nil }
        let second = data[cursor]
        cursor += 1
        return (Int(first & 0x7F) << 8) | Int(second)
    }

    private static func bigEndian(_ value: UInt32) -> Data {
        var value = value.bigEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }
}
