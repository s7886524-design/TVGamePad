import SwiftUI

private enum ControllerKind: String, CaseIterable, Identifiable {
    case fc = "FC", md = "MD", sfc = "SFC", playStation = "PS", xbox = "Xbox"
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

private enum KeyChoices {
    static let values = ["A", "B", "C", "X", "Y", "Z", "L", "R", "L1", "R1", "L2", "R2", "LB", "RB", "LT", "RT", "START", "SELECT", "MODE", "VIEW", "MENU", "↑", "↓", "←", "→"]
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connection = CooCaaSession()
    @StateObject private var input = ControllerInputState()
    @State private var selected: ControllerKind = .fc
    @State private var host = ""
    @State private var isSettingsPresented = false
    @State private var mappings: [String: String] = [:]
    @State private var isSearching = false
    @FocusState private var ipFieldFocused: Bool
    @AppStorage("tvgamepad.buttonMappings.v2") private var savedMappings = "{}"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compact = size.height < 500
            let pad = max(7, min(14, size.width * 0.012))

            ZStack {
                Color(red: 0.025, green: 0.033, blue: 0.048).ignoresSafeArea()
                VStack(spacing: compact ? 6 : 10) {
                    header(compact: compact)
                    controllerPicker(compact: compact)
                    controllerSurface(size: size, compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    connectionPanel(compact: compact)
                }
                .padding(.horizontal, pad)
                .padding(.top, compact ? 5 : 12)
                .padding(.bottom, compact ? 5 : 12)
                .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(Color(red: 0.025, green: 0.033, blue: 0.048).ignoresSafeArea())
        .statusBarHidden()
        .onAppear {
            mappings = decodeMappings(savedMappings)
            input.onEvent = { event in connection.send(event) }
            connection.startDiscovery()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { input.releaseAll() }
            else if !connection.isConnected { connection.startDiscovery() }
        }
        .onChange(of: selected) { _ in input.releaseAll() }
        .sheet(isPresented: $isSettingsPresented) {
            KeySettingsView(kind: selected, mappings: mappings) { updated in
                mappings = updated
                savedMappings = encodeMappings(updated)
            }
            .preferredColorScheme(.dark)
        }
    }

    private func decodeMappings(_ value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }

    private func encodeMappings(_ value: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func mapped(_ label: String) -> String { mappings[label] ?? label }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("TV GAMEPAD")
                    .font(.system(size: compact ? 9 : 11, weight: .bold, design: .rounded))
                    .tracking(3).foregroundStyle(.cyan)
                Text("\(selected.rawValue) Controller")
                    .font(.system(size: compact ? 17 : 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Circle().fill(connection.isPaired ? .green : (connection.isConnected ? .orange : .gray)).frame(width: 7, height: 7)
                Text(connection.isPaired ? "已连接" : (connection.isConnected ? "等待电视确认" : "未连接"))
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.78)).lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.075), in: Capsule())
            Button { isSettingsPresented = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("键位设置")
        }
        .frame(height: compact ? 34 : 46)
    }

    private func controllerPicker(compact: Bool) -> some View {
        HStack(spacing: 5) {
            ForEach(ControllerKind.allCases) { kind in
                Button {
                    input.releaseAll()
                    selected = kind
                } label: {
                    Text(kind.rawValue)
                        .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity).frame(height: compact ? 34 : 42)
                        .background(selected == kind ? Color.cyan.opacity(0.2) : Color.white.opacity(0.055))
                        .foregroundStyle(selected == kind ? .cyan : .white.opacity(0.68))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
        }
    }

    private func controllerSurface(size: CGSize, compact: Bool) -> some View {
        let diameter = min(compact ? 58 : 72, max(compact ? 39 : 48, size.height * (compact ? 0.145 : 0.16)))
        let gap: CGFloat = compact ? 7 : 11
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: selected.buttons.count > 8 ? 5 : 4)

        return HStack(spacing: compact ? 8 : 18) {
            VStack(spacing: gap) {
                inputButton("↑", diameter: diameter, compact: compact)
                HStack(spacing: gap) {
                    inputButton("←", diameter: diameter, compact: compact)
                    inputButton("↓", diameter: diameter, compact: compact)
                    inputButton("→", diameter: diameter, compact: compact)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: compact ? 2 : 7) {
                if !compact {
                    Text("按住按键 · 松开释放")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                LazyVGrid(columns: columns, spacing: gap) {
                    ForEach(selected.buttons, id: \.self) { name in
                        inputButton(name, diameter: min(diameter, compact ? 54 : 66), compact: compact)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(compact ? 9 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: compact ? 17 : 22)
        )
        .overlay(RoundedRectangle(cornerRadius: compact ? 17 : 22).stroke(Color.white.opacity(0.075), lineWidth: 1))
    }

    private func inputButton(_ name: String, diameter: CGFloat, compact: Bool) -> some View {
        let active = input.pressedButtons.contains(name)
        return Text(name)
            .font(.system(size: name.count > 3 ? (compact ? 9 : 11) : (compact ? 17 : 20), weight: .bold, design: .rounded))
            .minimumScaleFactor(0.65).lineLimit(1)
            .foregroundStyle(active ? Color.black : Color.white)
            .frame(width: diameter, height: diameter)
            .background(active ? Color.cyan : (["↑", "↓", "←", "→"].contains(name) ? Color.white.opacity(0.12) : Color.cyan.opacity(0.16)), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(active ? 0 : 0.13), lineWidth: 1))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in input.update(name, eventButton: mapped(name), pressed: true) }
                .onEnded { _ in input.update(name, eventButton: mapped(name), pressed: false) })
            .accessibilityLabel(name)
    }

    private func connectionPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 8) {
            HStack(spacing: 6) {
                TextField("电视 IP 地址", text: $host)
                    .font(.system(size: compact ? 13 : 15))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 11).frame(height: compact ? 38 : 44)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($ipFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { ipFieldFocused = false }
                    .frame(maxWidth: .infinity)
                Button("连接") {
                    ipFieldFocused = false
                    connection.connect(hostPort: host.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .buttonStyle(.borderedProminent).tint(.cyan)
                .frame(height: compact ? 38 : 44)
                .disabled(connection.isConnecting || connection.isConnected || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button {
                    ipFieldFocused = false
                    connection.startDiscovery()
                } label: {
                    Image(systemName: "wifi.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                }.buttonStyle(.bordered).disabled(connection.isConnecting)
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let tv = connection.discoveredTV {
                        Text(tv.deviceName).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(tv.address).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                    } else {
                        Text(connection.status).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    }
                }
                Spacer(minLength: 3)
                Text("事件 \(input.eventCount)")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.38))
                Button("断开") {
                    input.releaseAll()
                    connection.disconnect()
                }.buttonStyle(.bordered).controlSize(.small)
                .disabled(!connection.isConnected && !connection.isConnecting)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { ipFieldFocused = false }
                    .fontWeight(.semibold)
            }
        }
    }
}

private struct KeySettingsView: View {
    let kind: ControllerKind
    let mappings: [String: String]
    let onSave: ([String: String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("为当前手柄的每个实体按键指定发送给电视的按键指令。修改会自动保存到本机。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("\(kind.rawValue) 按键映射") {
                    ForEach(kind.buttons, id: \.self) { button in
                        HStack {
                            Text(button).font(.system(.body, design: .rounded).weight(.semibold)).frame(width: 72, alignment: .leading)
                            Spacer()
                            Picker("映射", selection: Binding(
                                get: { draft[button] ?? button },
                                set: { draft[button] = $0 }
                            )) {
                                ForEach(KeyChoices.values, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .labelsHidden().pickerStyle(.menu)
                        }
                    }
                }
                Section {
                    Button("恢复当前手柄默认键位", role: .destructive) {
                        for key in kind.buttons { draft.removeValue(forKey: key) }
                    }
                }
            }
            .navigationTitle("自定义键位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(draft); dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear { draft = mappings }
        }
    }
}
