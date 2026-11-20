import SwiftUI
import Network

private enum ControllerKind: String, CaseIterable, Identifiable {
    case fc = "FC"
    case md = "MD"
    case sfc = "SFC"
    case playStation = "PS"
    case xbox = "Xbox"

    var id: String { rawValue }

    var buttons: [String] {
        switch self {
        case .fc: return ["B", "A", "SELECT", "START"]
        case .md: return ["A", "B", "C", "X", "Y", "Z", "MODE", "START"]
        case .sfc: return ["B", "A", "Y", "X", "L", "R", "SELECT", "START"]
        case .playStation: return ["□", "△", "×", "○", "L1", "L2", "R1", "R2", "SELECT", "START"]
        case .xbox: return ["X", "Y", "A", "B", "LB", "LT", "RB", "RT", "VIEW", "MENU"]
        }
    }
}

@MainActor
final class TVConnectionModel: ObservableObject {
    @Published var host = ""
    @Published private(set) var status = "未连接"
    @Published private(set) var isConnecting = false
    @Published private(set) var isConnected = false

    private var connection: NWConnection?

    func connect() {
        let address = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            status = "请先输入电视 IP 地址"
            return
        }

        disconnect(quiet: true)
        isConnecting = true
        status = "正在连接电视 TCP 62015…"

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(address),
            port: NWEndpoint.Port(rawValue: 62015)!
        )
        let candidate = NWConnection(to: endpoint, using: .tcp)
        connection = candidate

        candidate.stateUpdateHandler = { [weak self, weak candidate] state in
            Task { @MainActor in
                guard let self, let candidate, self.connection === candidate else { return }
                switch state {
                case .ready:
                    self.isConnecting = false
                    self.isConnected = true
                    self.status = "TCP 已连通 · 等待酷咖协议适配"
                case .failed(let error):
                    self.isConnecting = false
                    self.isConnected = false
                    self.status = "连接失败：\(error.localizedDescription)"
                    candidate.cancel()
                    self.connection = nil
                case .waiting(let error):
                    self.isConnecting = true
                    self.isConnected = false
                    self.status = "正在等待网络：\(error.localizedDescription)"
                case .cancelled:
                    self.isConnecting = false
                    self.isConnected = false
                default:
                    break
                }
            }
        }
        candidate.start(queue: .global(qos: .userInitiated))
    }

    func disconnect(quiet: Bool = false) {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        isConnecting = false
        isConnected = false
        if !quiet { status = "已断开" }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connection = TVConnectionModel()
    @StateObject private var input = ControllerInputState()
    @State private var selected: ControllerKind = .fc

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.065).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                controllerPicker
                controllerSurface
                connectionPanel
            }
            .padding(16)
        }
        .statusBarHidden()
        .onChange(of: scenePhase) { phase in
            if phase != .active { input.releaseAll() }
        }
        .onChange(of: selected) { _ in input.releaseAll() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TV GAMEPAD")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.cyan)
                Text("\(selected.rawValue) Controller")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(connection.isConnected ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 7, height: 7)
                Text(connection.isConnected ? "TCP CONNECTED" : "NOT CONNECTED")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
    }

    private var controllerPicker: some View {
        HStack(spacing: 8) {
            ForEach(ControllerKind.allCases) { kind in
                Button {
                    selected = kind
                } label: {
                    Text(kind.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected == kind ? Color.cyan.opacity(0.2) : Color.white.opacity(0.055))
                        .foregroundStyle(selected == kind ? .cyan : .white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controllerSurface: some View {
        HStack(spacing: 22) {
            VStack(spacing: 9) {
                inputButton("↑", diameter: 58, tint: .white.opacity(0.12))
                HStack(spacing: 9) {
                    inputButton("←", diameter: 58, tint: .white.opacity(0.12))
                    inputButton("↓", diameter: 58, tint: .white.opacity(0.12))
                    inputButton("→", diameter: 58, tint: .white.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text("按住按键 · 松开释放")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 9)], spacing: 9) {
                    ForEach(selected.buttons, id: \.self) { name in
                        inputButton(name, diameter: 54, tint: .cyan.opacity(0.16))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 21)
        )
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func inputButton(_ name: String, diameter: CGFloat, tint: Color) -> some View {
        let active = input.pressedButtons.contains(name)
        return Text(name)
            .font(.system(size: name.count > 3 ? 10 : 17, weight: .bold, design: .rounded))
            .foregroundStyle(active ? Color.black : Color.white)
            .frame(width: diameter, height: diameter)
            .background(active ? Color.cyan : tint, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(active ? 0 : 0.12), lineWidth: 1))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in input.update(name, pressed: true) }
                    .onEnded { _ in input.update(name, pressed: false) }
            )
            .accessibilityLabel(name)
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                TextField("输入电视 IP 地址", text: $connection.host)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 205)

                Button {
                    connection.connect()
                } label: {
                    if connection.isConnecting {
                        ProgressView().tint(.black)
                    } else {
                        Text("连接")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(connection.isConnecting || connection.isConnected)

                Button("断开") {
                    connection.disconnect()
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConnected && !connection.isConnecting)

                Spacer(minLength: 0)

                Text("输入事件：\(input.eventCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }

            HStack(spacing: 8) {
                Text(connection.status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(input.latestEvent)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))
            }
        }
    }
}
