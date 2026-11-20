import SwiftUI

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

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connection = CooCaaSession()
    @StateObject private var input = ControllerInputState()
    @State private var selected: ControllerKind = .fc
    @State private var host = ""

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 520
            let sidePadding: CGFloat = compact ? 12 : 18

            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.065).ignoresSafeArea()

                VStack(spacing: compact ? 7 : 12) {
                    header(compact: compact)
                    controllerPicker(compact: compact)
                    controllerSurface(availableHeight: geometry.size.height, compact: compact)
                        .frame(maxHeight: .infinity)
                        .layoutPriority(1)
                    connectionPanel(compact: compact)
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, compact ? 8 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden()
        .onAppear {
            input.onEvent = { event in connection.send(event) }
            connection.startDiscovery()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                input.releaseAll()
            } else if !connection.isConnected {
                connection.startDiscovery()
            }
        }
        .onChange(of: selected) { _ in input.releaseAll() }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("TV GAMEPAD")
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.cyan)
                Text("\(selected.rawValue) Controller")
                    .font(.system(size: compact ? 17 : 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Circle()
                    .fill(connection.isPaired ? Color.green : (connection.isConnected ? Color.orange : Color.white.opacity(0.3)))
                    .frame(width: 7, height: 7)
                Text(connection.isPaired ? "PAIRED" : (connection.isConnected ? "APPROVAL" : "NOT CONNECTED"))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compact ? 6 : 8)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
        .frame(height: compact ? 30 : 42)
    }

    private func controllerPicker(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(ControllerKind.allCases) { kind in
                Button {
                    selected = kind
                } label: {
                    Text(kind.rawValue)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 34 : 42)
                        .background(selected == kind ? Color.cyan.opacity(0.2) : Color.white.opacity(0.055))
                        .foregroundStyle(selected == kind ? .cyan : .white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func controllerSurface(availableHeight: CGFloat, compact: Bool) -> some View {
        let diameter = min(compact ? 48 : 62, max(38, availableHeight * (compact ? 0.125 : 0.15)))
        let gap = compact ? 7.0 : 10.0
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: selected.buttons.count > 8 ? 5 : 4)

        return HStack(spacing: compact ? 12 : 22) {
            VStack(spacing: gap) {
                inputButton("↑", diameter: diameter, tint: .white.opacity(0.12))
                HStack(spacing: gap) {
                    inputButton("←", diameter: diameter, tint: .white.opacity(0.12))
                    inputButton("↓", diameter: diameter, tint: .white.opacity(0.12))
                    inputButton("→", diameter: diameter, tint: .white.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: compact ? 4 : 8) {
                if !compact {
                    Text("按住按键 · 松开释放")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
                LazyVGrid(columns: columns, spacing: gap) {
                    ForEach(selected.buttons, id: \.self) { name in
                        inputButton(name, diameter: min(diameter, compact ? 46 : 56), tint: .cyan.opacity(0.16))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(compact ? 10 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func inputButton(_ name: String, diameter: CGFloat, tint: Color) -> some View {
        let active = input.pressedButtons.contains(name)
        return Text(name)
            .font(.system(size: name.count > 3 ? 9 : 16, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
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

    private func connectionPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            HStack(spacing: 7) {
                TextField("电视 IP", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: compact ? 12 : 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 90, maxWidth: compact ? 210 : 250)

                Button("连接") {
                    connection.connect(hostPort: host)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(connection.isConnecting || connection.isConnected || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("搜索") {
                    connection.startDiscovery()
                }
                .buttonStyle(.bordered)
                .disabled(connection.isConnecting)

                if !compact {
                    Spacer(minLength: 0)
                    Text("事件 \(input.eventCount)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            HStack(spacing: 8) {
                if let tv = connection.discoveredTV {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tv.deviceName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(tv.address)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer(minLength: 4)
                    Button("连接电视") {
                        connection.connectDiscoveredTV()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(connection.isConnecting || connection.isConnected)
                } else {
                    Text("请在电视打开「连接虚拟手柄」等待页面")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                }

                Button("断开") {
                    input.releaseAll()
                    connection.disconnect()
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConnected && !connection.isConnecting)
            }

            HStack(spacing: 8) {
                Text(connection.status)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(connection.isPaired ? .green : .white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                if compact {
                    Text("事件 \(input.eventCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(input.latestEvent)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.top, compact ? 1 : 2)
    }
}
