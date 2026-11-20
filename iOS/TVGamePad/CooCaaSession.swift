import Foundation
import Network

/// Owns UDP discovery, TCP registration, TV-side approval and sequenced input.
@MainActor
final class CooCaaSession: ObservableObject {
    @Published private(set) var status = "等待电视"
    @Published private(set) var discoveredTV: CooCaaWireProtocol.Advertisement?
    @Published private(set) var isPaired = false

    var onStatusChange: ((String) -> Void)?

    private var discoveryListener: NWListener?
    private var tcpConnection: NWConnection?
    private var adapter: CooCaaProtocolAdapter?
    private var receiveBuffer = Data()
    private var sequence: UInt32 = 1
    private var isRegistering = false

    func startDiscovery() {
        stopDiscovery()
        status = "正在搜索电视 · UDP 64315"
        do {
            let listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: CooCaaWireProtocol.discoveryPort)!)
            discoveryListener = listener
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    if case .failed(let error) = state {
                        self.status = "搜索失败：\(error.localizedDescription)"
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] datagram in
                datagram.start(queue: .global(qos: .userInitiated))
                datagram.receiveMessage { data, _, _, error in
                    guard let data, error == nil else { return }
                    Task { @MainActor in
                        guard let self,
                              let advertisement = try? CooCaaWireProtocol.decodeAdvertisement(data) else { return }
                        self.discoveredTV = advertisement
                        self.status = "发现电视：\(advertisement.deviceName) · \(advertisement.address)"
                        self.onStatusChange?(self.status)
                    }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            status = "无法启动局域网搜索：\(error.localizedDescription)"
        }
    }

    func stopDiscovery() {
        discoveryListener?.newConnectionHandler = nil
        discoveryListener?.cancel()
        discoveryListener = nil
    }

    func connectDiscoveredTV() {
        guard let advertisement = discoveredTV else {
            status = "尚未发现电视"
            return
        }
        connect(hostPort: advertisement.address)
    }

    func connect(hostPort: String) {
        let parts = Self.splitHostPort(hostPort)
        guard let (host, port) = parts else {
            status = "电视地址格式无效"
            return
        }
        disconnect(quiet: true)
        status = "正在连接电视 TCP \(port)…"

        let connection = NWConnection(
            to: .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!),
            using: .tcp
        )
        tcpConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, let connection, self.tcpConnection === connection else { return }
                switch state {
                case .ready:
                    self.status = "TCP 已连接 · 正在请求电视授权"
                    self.beginRegistration()
                    self.receiveNext()
                case .waiting(let error):
                    self.status = "等待电视网络：\(error.localizedDescription)"
                case .failed(let error):
                    self.isPaired = false
                    self.status = "连接失败：\(error.localizedDescription)"
                case .cancelled:
                    self.isPaired = false
                default:
                    break
                }
                self.onStatusChange?(self.status)
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    func send(_ event: ControllerInputEvent) {
        guard isPaired, let connection = tcpConnection, let adapter else { return }
        do {
            let frame = try adapter.frame(for: event, sequence: nextSequence())
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.status = "按键发送失败：\(error.localizedDescription)"
                    self?.isPaired = false
                }
            })
        } catch {
            status = error.localizedDescription
        }
    }

    func disconnect(quiet: Bool = false) {
        stopDiscovery()
        tcpConnection?.stateUpdateHandler = nil
        tcpConnection?.cancel()
        tcpConnection = nil
        adapter = nil
        receiveBuffer.removeAll()
        isPaired = false
        isRegistering = false
        if !quiet {
            status = "已断开"
            onStatusChange?(status)
        }
    }

    private func beginRegistration() {
        guard let connection = tcpConnection, !isRegistering else { return }
        isRegistering = true
        let newAdapter = CooCaaProtocolAdapter()
        adapter = newAdapter
        let frame = newAdapter.registrationFrame(sequence: nextSequence())
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.status = "注册请求发送失败：\(error.localizedDescription)"
                self?.isRegistering = false
            }
        })
        status = "已发送配对请求 · 请在电视上确认"
        onStatusChange?(status)
    }

    private func receiveNext() {
        guard let connection = tcpConnection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, self.tcpConnection === connection else { return }
                if let data, !data.isEmpty {
                    self.receiveBuffer.append(data)
                    self.consumeFrames()
                }
                if let error {
                    self.status = "电视连接中断：\(error.localizedDescription)"
                    self.isPaired = false
                    return
                }
                if isComplete {
                    self.status = "电视已关闭连接"
                    self.isPaired = false
                    return
                }
                self.receiveNext()
            }
        }
    }

    private func consumeFrames() {
        while let frameLength = CooCaaWireProtocol.frameLength(in: receiveBuffer),
              receiveBuffer.count >= frameLength {
            let frame = receiveBuffer.prefix(frameLength)
            let data = Data(frame)
            receiveBuffer.removeFirst(frameLength)
            guard let message = CooCaaWireProtocol.decodeMessage(data) else { continue }
            if message.method == CooCaaWireProtocol.responseOK {
                isPaired = true
                isRegistering = false
                status = "电视已授权 · 手柄已连接"
                onStatusChange?(status)
            } else if message.method == 0xFC {
                isPaired = false
                isRegistering = false
                status = "电视拒绝了配对请求"
                onStatusChange?(status)
            }
        }
    }

    private func nextSequence() -> UInt32 {
        defer { sequence &+= 1 }
        return sequence
    }

    private static func splitHostPort(_ value: String) -> (String, UInt16)? {
        if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
            let host = String(value[value.index(after: value.startIndex)..<close])
            let suffix = value[value.index(after: close)...]
            guard suffix.first == ":", let port = UInt16(suffix.dropFirst()) else { return nil }
            return (host, port)
        }
        guard let colon = value.lastIndex(of: ":"),
              let port = UInt16(value[value.index(after: colon)...]) else { return nil }
        return (String(value[..<colon]), port)
    }
}
