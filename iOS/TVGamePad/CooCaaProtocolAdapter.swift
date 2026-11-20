import Foundation

protocol ControllerTransport {
    func frame(for event: ControllerInputEvent, sequence: UInt32) throws -> Data
}

/// CooKaa 1.4.5 wire-level adapter. The caller owns the TCP connection,
/// registration response and user-approved pairing lifecycle.
struct CooCaaProtocolAdapter: ControllerTransport {
    let deviceName: String
    let authKey: Data

    init(deviceName: String = "TV GamePad iPhone", authKey: Data = Self.makeAuthKey()) {
        self.deviceName = deviceName
        self.authKey = authKey
    }

    func registrationFrame(sequence: UInt32) -> Data {
        CooCaaWireProtocol.makeRegistration(
            key: authKey,
            deviceName: deviceName,
            sequence: sequence
        )
    }

    func frame(for event: ControllerInputEvent, sequence: UInt32) throws -> Data {
        guard let keyCode = Self.androidKeyCode(for: event.button) else {
            throw AdapterError.unsupportedButton(event.button)
        }
        return CooCaaWireProtocol.makeKeyEvent(
            androidKeyCode: keyCode,
            pressed: event.phase == .pressed,
            sequence: sequence
        )
    }

    enum AdapterError: LocalizedError {
        case unsupportedButton(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedButton(let name):
                return "Unsupported controller button: \(name)"
            }
        }
    }

    /// Android KeyEvent key codes observed in the CooKaa input path.
    /// The TV app itself remaps A/B and Start in TiVirtualKeypadEvent.
    private static func androidKeyCode(for button: String) -> Int32? {
        let codes: [String: Int32] = [
            "↑": 19, "↓": 20, "←": 21, "→": 22,
            "A": 96, "B": 97, "C": 98,
            "X": 99, "Y": 100, "Z": 101,
            "L": 102, "R": 103,
            "L1": 102, "R1": 103, "L2": 104, "R2": 105,
            "LB": 102, "RB": 103, "LT": 104, "RT": 105,
            "START": 108, "MENU": 108,
            "SELECT": 109, "VIEW": 109,
            "□": 99, "△": 100, "×": 96, "○": 97
        ]
        return codes[button]
    }

    private static func makeAuthKey() -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
}

enum CooCaaObservedEndpoint {
    static let tcpPort: UInt16 = CooCaaWireProtocol.tcpPort
    static let discoveryPort: UInt16 = CooCaaWireProtocol.discoveryPort
}
