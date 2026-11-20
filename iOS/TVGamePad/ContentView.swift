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
    @Published var status = "未连接"
    @Published var isChecking = false

    private var connection: NWConnection?

    func checkConnection() {
        let address = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            status = "请先输入电视 IP 地址"
            return
        }

        connection?.cancel()
        isChecking = true
        status = "正在检查 TCP 62015…"

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(address),
            port: NWEndpoint.Port(rawValue: 62015)!
        )
        let candidate = NWConnection(to: endpoint, using: .tcp)
        connection = candidate
        candidate.stateUpdateHandler = { [weak self, weak candidate] state in
            Task { @MainActor in
                guard let self, self.connection === candidate else { return }
                self.isChecking = false
                switch state {
                case .ready:
                    self.status = "端口可连接；协议认证尚未实现"
                    candidate?.cancel()
                case .failed(let error):
                    self.status = "连接失败：\(error.localizedDescription)"
                    candidate?.cancel()
                case .waiting(let error):
                    self.status = "等待网络：\(error.localizedDescription)"
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        candidate.start(queue: .global(qos: .userInitiated))
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isChecking = false
        status = "未连接"
    }
}

struct ContentView: View {
    @StateObject private var connection = TVConnectionModel()
    @State private var selected: ControllerKind = .fc
    @State private var pressedButtons: Set<String> = []

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.065).ignoresSafeArea()
            VStack(spacing: 14) {
                header
                HStack(spacing: 8) {
                    ForEach(ControllerKind.allCases) { kind in
                        Button {
                            selected = kind
                            pressedButtons.removeAll()
                        } label: {
                            Text(kind.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selected == kind ? Color.cyan.opacity(0.22) : Color.white.opacity(0.055))
                                .foregroundStyle(selected == kind ? .cyan : .white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                controllerSurface
                connectionPanel
            }
            .padding(18)
        }
        .statusBarHidden()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("TV GAMEPAD")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.cyan)
                Text("\(selected.rawValue) Controller")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("LAN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var controllerSurface: some View {
        HStack(spacing: 24) {
            VStack(spacing: 12) {
                directionButton("↑")
                HStack(spacing: 12) {
                    directionButton("←")
                    directionButton("↓")
                    directionButton("→")
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text("按住操作 · 松开即释放")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 10)], spacing: 10) {
                    ForEach(selected.buttons, id: \.self) { name in
                        actionButton(name)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func directionButton(_ title: String) -> some View {
        holdButton(title, size: 58, tint: .white.opacity(0.12))
    }

    private func actionButton(_ title: String) -> some View {
        holdButton(title, size: 58, tint: .cyan.opacity(0.16))
    }

    private func holdButton(_ title: String, size: CGFloat, tint: Color) -> some View {
        let active = pressedButtons.contains(title)
        return Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(active ? Color.black : Color.white)
            .frame(width: size, height: size)
            .background(active ? Color.cyan : tint, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(active ? 0.0 : 0.12), lineWidth: 1))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressedButtons.insert(title) }
                    .onEnded { _ in pressedButtons.remove(title) }
            )
    }

    private var connectionPanel: some View {
        HStack(spacing: 10) {
            TextField("电视 IP 地址", text: $connection.host)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(maxWidth: 210)
            Button {
                connection.checkConnection()
            } label: {
                if connection.isChecking {
                    ProgressView().tint(.black)
                } else {
                    Text("检查电视")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(connection.isChecking)
            Text(connection.status)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}