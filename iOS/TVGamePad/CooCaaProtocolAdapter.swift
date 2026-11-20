import Foundation

/// Transport boundary between the controller UI and a console-specific protocol.
/// The UI emits normalized button events; a verified adapter translates them.
protocol ControllerTransport {
    func send(_ event: ControllerInputEvent) throws
}

/// Explicitly unavailable until the CooKaa handshake and frame format are verified.
/// This implementation intentionally sends no bytes.
struct CooCaaProtocolAdapter: ControllerTransport {
    enum AdapterError: LocalizedError {
        case protocolNotVerified

        var errorDescription: String? {
            "CooCaa protocol is not verified. No controller data was sent."
        }
    }

    func send(_ event: ControllerInputEvent) throws {
        throw AdapterError.protocolNotVerified
    }
}

/// Facts that have been observed on the target TV. These values do not
/// describe the authentication protocol or packet format.
enum CooCaaObservedEndpoint {
    static let tcpPort: UInt16 = 62015
}
