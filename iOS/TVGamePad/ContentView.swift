import SwiftUI
import UIKit

private enum PadRoute: Equatable { case connect, choose, play, settings }

private enum ControllerKind: String, CaseIterable, Identifiable {
    case fc = "FC", md = "MD", sfc = "SFC", ps = "PS", xbox = "XBOX"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .fc: return "8-BIT CLASSIC"
        case .md: return "16-BIT ARCADE"
        case .sfc: return "SUPER 16-BIT"
        case .ps: return "PLAYSTATION"
        case .xbox: return "XBOX LAYOUT"
        }
    }
    var buttons: [String] {
        switch self {
        case .fc: return ["B", "A", "SELECT", "START"]
        case .md: return ["A", "B", "C", "X", "Y", "Z", "MODE", "START"]
        case .sfc: return ["B", "A", "Y", "X", "L", "R", "SELECT", "START"]
        case .ps: return ["□", "△", "×", "○", "L1", "L2", "R1", "R2", "SELECT", "START"]
        case .xbox: return ["X", "Y", "A", "B", "LB", "LT", "RB", "RT", "VIEW", "MENU"]
        }
    }
    var accent: Color {
        switch self {
        case .fc: return Color(red: 0.98, green: 0.31, blue: 0.29)
        case .md: return Color(red: 0.35, green: 0.64, blue: 1)
        case .sfc: return Color(red: 0.72, green: 0.52, blue: 1)
        case .ps: return Color(red: 0.38, green: 0.68, blue: 1)
        case .xbox: return Color(red: 0.35, green: 0.82, blue: 0.54)
        }
    }
}

private enum KeyChoices {
    static let values = ["A", "B", "C", "X", "Y", "Z", "L", "R", "L1", "R1", "L2", "R2", "LB", "RB", "LT", "RT", "START", "SELECT", "MODE", "VIEW", "MENU", "↑", "↓", "←", "→", "□", "△", "×", "○"]
}

private enum PadPalette {
    static let base = Color(red: 0.035, green: 0.047, blue: 0.067)
    static let panel = Color(red: 0.075, green: 0.09, blue: 0.12)
    static let raised = Color(red: 0.105, green: 0.125, blue: 0.16)
    static let muted = Color(red: 0.49, green: 0.55, blue: 0.64)
    static let line = Color.white.opacity(0.085)
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connection = CooCaaSession()
    @StateObject private var input = ControllerInputState()
    @AppStorage("tvpad.controller") private var savedController = "FC"
    @AppStorage("tvpad.haptics") private var hapticsEnabled = true
    @AppStorage("tvpad.hapticStrength") private var hapticStrength = 0.72
    @AppStorage("tvpad.buttonScale") private var buttonScale = 1.0
    @AppStorage("tvpad.buttonOpacity") private var buttonOpacity = 0.92
    @AppStorage("tvpad.leftHanded") private var leftHanded = false
    @AppStorage("tvpad.mappings") private var savedMappings = "{}"
    @AppStorage("tvpad.layoutOffsets") private var savedOffsets = "{}"
    @State private var route: PadRoute = .connect
    @State private var selected: ControllerKind = .fc
    @State private var mappings: [String: String] = [:]
    @State private var offsets: [String: CGSize] = [:]
    @State private var editingLayout = false
    @State private var showDisconnectConfirm = false
    @State private var lastHapticTime = Date.distantPast

    var body: some View {
        ZStack {
            PadPalette.base.ignoresSafeArea()
            switch route {
            case .connect: connectionHome
            case .choose: controllerLibrary
            case .play: controllerPlay
            case .settings: settingsHome
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            selected = ControllerKind(rawValue: savedController) ?? .fc
            mappings = decodeMappings(savedMappings)
            offsets = decodeOffsets(savedOffsets)
            input.onEvent = { event in connection.send(event) }
            if !connection.isPaired { connection.startDiscovery() }
        }
        .onChange(of: connection.isPaired) { paired in
            if paired {
                route = .choose
                connection.stopDiscovery()
                tactile(.success)
            } else if route == .play {
                route = .connect
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { input.releaseAll() }
            else if !connection.isPaired { connection.startDiscovery() }
        }
        .onChange(of: selected) { value in
            savedController = value.rawValue
            input.releaseAll()
        }
    }

    private var connectionHome: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 430
            VStack(alignment: .leading, spacing: 0) {
                topBar
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("YOUR TV.\nYOUR CONTROLLER.")
                            .font(.system(size: compact ? 31 : 40, weight: .bold, design: .rounded))
                            .tracking(-1.5).foregroundStyle(.white)
                        Text("让 iPhone 成为客厅里的专业游戏手柄。连接同一 Wi-Fi 网络中的酷开电视，即可开始。")
                            .font(.system(size: 14, weight: .regular)).lineSpacing(5)
                            .foregroundStyle(PadPalette.muted).frame(maxWidth: 390, alignment: .leading)
                        HStack(spacing: 9) {
                            featurePill("自动发现", icon: "dot.radiowaves.left.and.right")
                            featurePill("低延迟输入", icon: "bolt.fill")
                            featurePill("触感反馈", icon: "waveform")
                        }
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.055)).frame(width: compact ? 180 : 245)
                        Circle().stroke(Color.cyan.opacity(0.13), lineWidth: 1).frame(width: compact ? 155 : 215)
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: compact ? 76 : 104, weight: .light))
                            .foregroundStyle(LinearGradient(colors: [.white, Color.cyan.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: .cyan.opacity(0.18), radius: 30)
                    }
                    .frame(width: compact ? 190 : 260)
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("NEARBY DEVICES").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(PadPalette.muted)
                                Text(connection.discoveredTV == nil ? "正在搜索局域网电视" : "发现可用设备")
                                    .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                            }
                            Spacer()
                            HStack(spacing: 7) {
                                Circle().fill(connection.discoveredTV == nil ? Color.orange : Color.green).frame(width: 7, height: 7)
                                Text(connection.discoveredTV == nil ? "SCANNING" : "ONLINE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                                    .foregroundStyle(connection.discoveredTV == nil ? .orange : .green)
                            }
                        }
                        if let tv = connection.discoveredTV {
                            HStack(spacing: 13) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13).fill(Color.cyan.opacity(0.11)).frame(width: 48, height: 48)
                                    Image(systemName: "tv").font(.system(size: 22)).foregroundStyle(.cyan)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tv.deviceName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    Text(tv.address).font(.system(size: 11, design: .monospaced)).foregroundStyle(PadPalette.muted)
                                }
                                Spacer()
                                Button {
                                    connection.connectDiscoveredTV()
                                } label: {
                                    HStack(spacing: 7) {
                                        if connection.isConnecting { ProgressView().tint(.black) }
                                        Text(connection.isConnecting ? "连接中" : "连接设备")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(PadPalette.base)
                                    .padding(.horizontal, 18).frame(height: 42)
                                    .background(Color.cyan, in: Capsule())
                                }
                                .buttonStyle(.plain).disabled(connection.isConnecting)
                            }
                            .padding(13)
                            .background(PadPalette.raised, in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(PadPalette.line, lineWidth: 1))
                        } else {
                            HStack(spacing: 12) {
                                ProgressView().tint(.cyan)
                                Text(connection.status).font(.system(size: 12)).foregroundStyle(PadPalette.muted).lineLimit(2)
                                Spacer()
                                Button("重新搜索") { connection.startDiscovery() }
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.cyan)
                                    .buttonStyle(.plain)
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(PadPalette.raised, in: RoundedRectangle(cornerRadius: 17))
                        }
                        if connection.status.contains("拒绝") {
                            Text("电视端拒绝了注册请求。请确认电视上的虚拟手柄服务处于等待连接状态；TCP 连通不代表授权成功。")
                                .font(.system(size: 11)).foregroundStyle(.orange).lineSpacing(3)
                        }
                    }
                    .frame(maxWidth: 520)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("CONNECTION STATUS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(PadPalette.muted)
                        Text(connection.isPaired ? "已获得电视授权" : connection.isConnected ? "正在等待电视授权" : "等待连接")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text("仅在电视返回授权成功后开放手柄。不会把单纯的网络连通误报为已配对。")
                            .font(.system(size: 11)).foregroundStyle(PadPalette.muted).lineSpacing(3)
                    }
                    .padding(18).frame(width: 225, alignment: .leading)
                    .background(PadPalette.panel, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(PadPalette.line, lineWidth: 1))
                }
                .padding(.bottom, 14)
                bottomBrand
            }
            .padding(.horizontal, max(22, geo.size.width * 0.045))
            .padding(.top, 13).padding(.bottom, 9)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var controllerLibrary: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 390
            let cardWidth = min(geo.size.width * 0.30, 340)
            let cardHeight = min(geo.size.height * 0.62, 310)

            ScrollViewReader { proxy in
                VStack(spacing: compact ? 9 : 15) {
                    topBar
                        .frame(height: compact ? 28 : 34)
                        .padding(.horizontal, 26)

                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONTROLLER LIBRARY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(2.5).foregroundStyle(.cyan)
                            Text("选择你的手柄")
                                .font(.system(size: compact ? 23 : 29, weight: .semibold, design: .rounded))
                                .tracking(-0.7).foregroundStyle(.white)
                        }
                        Spacer()
                        HStack(spacing: 7) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("已连接")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 28)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(ControllerKind.allCases) { kind in
                                Button {
                                    selected = kind
                                    tactile(.selection)
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                        proxy.scrollTo(kind.id, anchor: .center)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack {
                                            Text(kind.subtitle)
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .tracking(1.7).foregroundStyle(PadPalette.muted)
                                            Spacer()
                                            if selected == kind {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(kind.accent)
                                            }
                                        }
                                        .padding(.bottom, 13)

                                        controllerMiniature(kind)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: cardHeight * 0.49)
                                            .background(PadPalette.base.opacity(0.9),
                                                        in: RoundedRectangle(cornerRadius: 15))
                                            .padding(.bottom, 15)

                                        HStack(alignment: .firstTextBaseline) {
                                            Text(kind.rawValue)
                                                .font(.system(size: compact ? 23 : 28, weight: .semibold, design: .rounded))
                                                .tracking(-0.6).foregroundStyle(.white)
                                            Spacer()
                                            Text(selected == kind ? "已选择" : "选择")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(selected == kind ? kind.accent : PadPalette.muted)
                                        }
                                        Spacer(minLength: 0)
                                        Rectangle().fill(selected == kind ? kind.accent : Color.white.opacity(0.08))
                                            .frame(height: 2)
                                            .padding(.top, 14)
                                    }
                                    .padding(.horizontal, 19)
                                    .padding(.vertical, 16)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(PadPalette.panel)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selected == kind ? kind.accent.opacity(0.8) : PadPalette.line,
                                                    lineWidth: selected == kind ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(kind.id)
                            }
                        }
                        .padding(.horizontal, max(20, (geo.size.width - cardWidth) / 2))
                    }
                    .frame(height: cardHeight + 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            proxy.scrollTo(selected.id, anchor: .center)
                        }
                    }
                    .onChange(of: selected) { kind in
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            proxy.scrollTo(kind.id, anchor: .center)
                        }
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(selected.rawValue)  /  \(selected.subtitle)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("左右滑动浏览 · 选择后进入完整按键界面")
                                .font(.system(size: 10)).foregroundStyle(PadPalette.muted)
                        }
                        Spacer()
                        Button {
                            input.releaseAll()
                            route = .play
                            tactile(.success)
                        } label: {
                            HStack(spacing: 10) {
                                Text("进入手柄")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PadPalette.base)
                            .padding(.horizontal, 24)
                            .frame(height: compact ? 40 : 46)
                            .background(selected.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 28)

                    bottomBrand.padding(.horizontal, 26)
                }
                .padding(.top, compact ? 7 : 12)
                .padding(.bottom, 8)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(PadPalette.base)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var controllerPlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let compact = h < 390
            let unit = min(h * (compact ? 0.14 : 0.17), w * 0.105) * buttonScale
            VStack(spacing: 5) {
                HStack(spacing: 10) {
                    Button { route = .choose; input.releaseAll() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 30).background(PadPalette.raised, in: Capsule())
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TV GAMEPAD").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(.cyan)
                        Text("\(selected.rawValue) CONTROLLER").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(connection.isPaired ? .green : .orange).frame(width: 6, height: 6)
                        Text(connection.isPaired ? "CONNECTED" : "LINK LOST")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(PadPalette.muted)
                    }
                    Button { editingLayout.toggle(); tactile(.selection) } label: {
                        Image(systemName: editingLayout ? "checkmark" : "move.3d")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(editingLayout ? .black : .white)
                            .frame(width: 34, height: 30).background(editingLayout ? selected.accent : PadPalette.raised, in: Capsule())
                    }.buttonStyle(.plain)
                    Button { route = .settings; input.releaseAll() } label: {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 30).background(PadPalette.raised, in: Capsule())
                    }.buttonStyle(.plain)
                }
                .foregroundStyle(.white).padding(.horizontal, 13)
                HStack(spacing: 0) {
                    if leftHanded {
                        playActionSide(unit: unit)
                        playDirectionSide(unit: unit)
                    } else {
                        playDirectionSide(unit: unit)
                        playActionSide(unit: unit)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                HStack {
                    Text(editingLayout ? "拖动按键调整位置 · 点击完成保存" : "按住操作 · 松开自动释放")
                    Spacer()
                    Text("INPUT  \(input.eventCount)")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(PadPalette.muted)
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(PadPalette.muted)
                .padding(.horizontal, 15).padding(.bottom, 5)
            }
            .frame(width: w, height: h)
            .background(PadPalette.base)
        }
        .ignoresSafeArea()
    }

    private var settingsHome: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Button { route = connection.isPaired ? .play : .connect } label: {
                        Label("返回", systemImage: "chevron.left").font(.system(size: 13, weight: .semibold)).foregroundStyle(PadPalette.muted)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("CONTROL\nCENTER").font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-1).foregroundStyle(.white)
                    Text("手柄控制中心").font(.system(size: 14, weight: .medium)).foregroundStyle(.cyan)
                    Spacer()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DEVICE").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(PadPalette.muted)
                        Text(connection.discoveredTV?.deviceName ?? "未连接电视").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .padding(24).frame(width: geo.size.width * 0.28, height: geo.size.height, alignment: .leading)
                .background(PadPalette.panel)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 17) {
                        settingsSection("触觉反馈", detail: "按键触发时由 iPhone Taptic Engine 提供即时触感")
                        settingsToggle("按键触感", detail: "轻触、按住和选择操作的触觉反馈", value: $hapticsEnabled)
                        settingsSlider("触感强度", value: $hapticStrength, range: 0.15...1, valueText: "\(Int(hapticStrength * 100))%")
                        settingsSection("手柄外观", detail: "调整触控区域的视觉与操作尺寸")
                        settingsSlider("按键尺寸", value: $buttonScale, range: 0.72...1.28, valueText: "\(Int(buttonScale * 100))%")
                        settingsSlider("按键不透明度", value: $buttonOpacity, range: 0.35...1, valueText: "\(Int(buttonOpacity * 100))%")
                        settingsToggle("左手模式", detail: "交换方向区与功能区的位置", value: $leftHanded)
                        settingsSection("按键映射", detail: "点击右侧当前指令，在可用指令间循环切换")
                        mappingEditor
                        settingsSection("连接与布局", detail: "管理电视连接和自定义布局")
                        HStack(spacing: 10) {
                            settingsAction("重新搜索电视", icon: "dot.radiowaves.left.and.right") {
                                input.releaseAll(); connection.disconnect(); connection.startDiscovery(); route = .connect
                            }
                            settingsAction("重置按键位置", icon: "arrow.counterclockwise") {
                                offsets = [:]; savedOffsets = "{}"
                            }
                        }
                        HStack(spacing: 10) {
                            settingsAction("恢复默认键位", icon: "arrow.uturn.backward") {
                                mappings = [:]; savedMappings = "{}"
                            }
                            settingsAction("断开电视", icon: "link.badge.minus") {
                                input.releaseAll(); connection.disconnect(); route = .connect
                            }
                        }
                    }
                    .padding(22).frame(maxWidth: 720, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var mappingEditor: some View {
        VStack(spacing: 0) {
            ForEach(selected.buttons, id: \.self) { key in
                HStack {
                    Text(key).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white).frame(width: 62, alignment: .leading)
                    Spacer()
                    Button {
                        let choices = KeyChoices.values
                        let current = mappings[key] ?? key
                        let index = choices.firstIndex(of: current) ?? -1
                        mappings[key] = choices[(index + 1) % choices.count]
                        savedMappings = encodeMappings(mappings)
                        tactile(.selection)
                    } label: {
                        HStack(spacing: 8) {
                            Text(mappings[key] ?? key).font(.system(size: 12, weight: .bold, design: .monospaced))
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 10))
                        }
                        .foregroundStyle(.cyan).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.09), in: Capsule())
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
                if key != selected.buttons.last { Rectangle().fill(PadPalette.line).frame(height: 1).padding(.leading, 13) }
            }
        }
        .background(PadPalette.panel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(PadPalette.line, lineWidth: 1))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.13)).frame(width: 34, height: 34)
                Image(systemName: "gamecontroller.fill").font(.system(size: 17)).foregroundStyle(.cyan)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("NEXTPAD").font(.system(size: 13, weight: .black, design: .rounded)).tracking(2.2).foregroundStyle(.white)
                Text("TV GAME CONTROLLER").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(PadPalette.muted)
            }
            Spacer()
            Button { route = .settings } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8)).frame(width: 36, height: 36)
                    .background(PadPalette.raised, in: RoundedRectangle(cornerRadius: 11))
            }.buttonStyle(.plain)
        }
    }

    private var bottomBrand: some View {
        HStack {
            Text("NEXTPAD  /  PRECISION IN YOUR HANDS").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(PadPalette.muted.opacity(0.75))
            Spacer()
            Text("LOCAL NETWORK · PRIVATE").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(PadPalette.muted.opacity(0.55))
        }
    }

    private func featurePill(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundStyle(.cyan)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(PadPalette.panel, in: Capsule())
        .overlay(Capsule().stroke(PadPalette.line, lineWidth: 1))
    }

    private func controllerMiniature(_ kind: ControllerKind) -> some View {
        HStack(spacing: 15) {
            VStack(spacing: 3) {
                miniKey("↑", color: .white.opacity(0.22))
                HStack(spacing: 3) { miniKey("←", color: .white.opacity(0.22)); miniKey("↓", color: .white.opacity(0.22)); miniKey("→", color: .white.opacity(0.22)) }
            }
            Spacer(minLength: 0)
            if kind == .md {
                VStack(spacing: 4) {
                    HStack(spacing: 4) { miniKey("Y", color: kind.accent); miniKey("X", color: kind.accent); miniKey("Z", color: kind.accent) }
                    HStack(spacing: 4) { miniKey("A", color: kind.accent); miniKey("B", color: kind.accent); miniKey("C", color: kind.accent) }
                }
            } else {
                HStack(spacing: 5) {
                    miniKey(kind == .ps ? "□" : kind == .xbox ? "X" : "B", color: kind.accent)
                    miniKey(kind == .ps ? "△" : kind == .xbox ? "Y" : "A", color: kind.accent)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private func miniKey(_ title: String, color: Color) -> some View {
        Text(title).font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white)
            .frame(width: 22, height: 22).background(color.opacity(0.32), in: Circle())
    }

    private func dpad(size: CGFloat) -> some View {
        let s = max(30, size * 0.82)
        return VStack(spacing: 3) {
            pressKey("↑", width: s, height: s * 0.82, color: Color.white.opacity(0.16))
            HStack(spacing: 3) {
                pressKey("←", width: s, height: s * 0.82, color: Color.white.opacity(0.16))
                RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)).frame(width: s, height: s * 0.82)
                pressKey("→", width: s, height: s * 0.82, color: Color.white.opacity(0.16))
            }
            pressKey("↓", width: s, height: s * 0.82, color: Color.white.opacity(0.16))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    private func playDirectionSide(unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            if selected == .ps || selected == .xbox {
                HStack(spacing: 12) {
                    shoulderButton(selected == .ps ? "L2" : "LT", size: unit * 0.9)
                    shoulderButton(selected == .ps ? "L1" : "LB", size: unit * 0.9)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
            } else if selected == .sfc {
                HStack(spacing: 12) { shoulderButton("L", size: unit * 0.9) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
            }
            Spacer(minLength: 3)
            dpad(size: unit)
            Spacer(minLength: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playActionSide(unit: CGFloat) -> some View {
        VStack(spacing: 8) {
            if selected == .md {
                HStack(spacing: 6) {
                    actionButton("Y", size: unit * 0.78)
                    actionButton("X", size: unit * 0.78)
                    actionButton("Z", size: unit * 0.78)
                }
            }
            HStack(spacing: 14) {
                utilityButton(selected == .xbox ? "VIEW" : selected == .md ? "MODE" : "SELECT", size: unit * 0.58)
                utilityButton(selected == .xbox ? "MENU" : "START", size: unit * 0.58)
            }
            if selected == .sfc || selected == .ps || selected == .xbox {
                HStack(spacing: 12) {
                    if selected == .sfc {
                        shoulderButton("R", size: unit * 0.9)
                    } else {
                        shoulderButton(selected == .ps ? "R1" : "RB", size: unit * 0.9)
                        shoulderButton(selected == .ps ? "R2" : "RT", size: unit * 0.9)
                    }
                }
            }
            Spacer(minLength: 0)
            actionCluster(size: unit)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func actionCluster(size: CGFloat) -> some View {
        switch selected {
        case .fc:
            return AnyView(HStack(spacing: 15) {
                actionButton("B", size: size)
                actionButton("A", size: size)
            })
        case .md:
            return AnyView(HStack(spacing: 9) {
                actionButton("A", size: size * 0.78)
                actionButton("B", size: size * 0.78)
                actionButton("C", size: size * 0.78)
            })
        case .sfc:
            return AnyView(VStack(spacing: 6) {
                HStack(spacing: 10) { actionButton("Y", size: size * 0.85); actionButton("X", size: size * 0.85) }
                HStack(spacing: 10) { actionButton("B", size: size * 0.85); actionButton("A", size: size * 0.85) }
            })
        case .ps:
            return AnyView(VStack(spacing: 7) {
                HStack(spacing: 10) { actionButton("△", size: size * 0.82); actionButton("○", size: size * 0.82) }
                HStack(spacing: 10) { actionButton("□", size: size * 0.82); actionButton("×", size: size * 0.82) }
            })
        case .xbox:
            return AnyView(VStack(spacing: 7) {
                HStack(spacing: 10) { actionButton("Y", size: size * 0.82); actionButton("B", size: size * 0.82) }
                HStack(spacing: 10) { actionButton("X", size: size * 0.82); actionButton("A", size: size * 0.82) }
            })
        }
    }

    private func pressKey(_ name: String, width: CGFloat, height: CGFloat, color: Color) -> some View {
        let active = input.pressedButtons.contains(name)
        return RoundedRectangle(cornerRadius: 8)
            .fill(active ? selected.accent : color)
            .overlay(Text(name).font(.system(size: 18, weight: .bold)).foregroundStyle(active ? .black : .white.opacity(0.9)))
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.09), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if editingLayout { return }
                    if !input.pressedButtons.contains(name) {
                        input.update(name, eventButton: mapped(name), pressed: true)
                        tactile(.press)
                    }
                }
                .onEnded { _ in input.update(name, eventButton: mapped(name), pressed: false) })
    }

    private func actionButton(_ name: String, size: CGFloat) -> some View {
        let active = input.pressedButtons.contains(name)
        let color = selected.accent
        return Text(name)
            .font(.system(size: max(12, size * 0.31), weight: .black, design: .rounded))
            .foregroundStyle(active ? .black : .white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(active ? color : color.opacity(buttonOpacity * 0.34))
                    .overlay(Circle().stroke(color.opacity(0.85), lineWidth: 1.2))
                    .shadow(color: color.opacity(active ? 0.28 : 0.08), radius: active ? 10 : 4, y: 3)
            )
            .contentShape(Circle())
            .offset(offsets[name] ?? .zero)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if editingLayout {
                        offsets[name] = CGSize(width: value.translation.width, height: value.translation.height)
                        return
                    }
                    if !input.pressedButtons.contains(name) {
                        input.update(name, eventButton: mapped(name), pressed: true)
                        tactile(.press)
                    }
                }
                .onEnded { _ in
                    if editingLayout { savedOffsets = encodeOffsets(offsets) }
                    else { input.update(name, eventButton: mapped(name), pressed: false) }
                })
    }

    private func utilityButton(_ name: String, size: CGFloat) -> some View {
        Text(name).font(.system(size: max(8, size * 0.2), weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85)).frame(width: size * 1.3, height: size * 0.52)
            .background(PadPalette.raised, in: Capsule()).overlay(Capsule().stroke(PadPalette.line, lineWidth: 1))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !input.pressedButtons.contains(name) {
                        input.update(name, eventButton: mapped(name), pressed: true)
                        tactile(.press)
                    }
                }
                .onEnded { _ in input.update(name, eventButton: mapped(name), pressed: false) })
    }

    private func shoulderButton(_ name: String, size: CGFloat) -> some View {
        Text(name).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.white)
            .frame(width: size * 1.35, height: max(25, size * 0.43))
            .background(PadPalette.raised, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(PadPalette.line, lineWidth: 1))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !input.pressedButtons.contains(name) {
                        input.update(name, eventButton: mapped(name), pressed: true)
                        tactile(.press)
                    }
                }
                .onEnded { _ in input.update(name, eventButton: mapped(name), pressed: false) })
    }

    private func settingsSection(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(detail).font(.system(size: 10)).foregroundStyle(PadPalette.muted)
        }
        .padding(.top, 4)
    }

    private func settingsToggle(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 10)).foregroundStyle(PadPalette.muted)
            }
            Spacer()
            Button { value.wrappedValue.toggle(); tactile(.selection) } label: {
                Capsule().fill(value.wrappedValue ? Color.cyan : Color.white.opacity(0.12))
                    .frame(width: 43, height: 25)
                    .overlay(Circle().fill(.white).frame(width: 19, height: 19).offset(x: value.wrappedValue ? 9 : -9))
            }.buttonStyle(.plain)
        }
        .padding(14).background(PadPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PadPalette.line, lineWidth: 1))
    }

    private func settingsSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(valueText).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
            }
            GeometryReader { g in
                let progress = (value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.11)).frame(height: 5)
                    Capsule().fill(Color.cyan).frame(width: max(0, g.size.width * progress), height: 5)
                    Circle().fill(.white).frame(width: 17, height: 17).shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: max(0, min(g.size.width - 17, g.size.width * progress - 8.5)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { p in
                    let t = min(1, max(0, p.location.x / g.size.width))
                    value.wrappedValue = range.lowerBound + (range.upperBound - range.lowerBound) * t
                })
            }.frame(height: 22)
        }
        .padding(14).background(PadPalette.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PadPalette.line, lineWidth: 1))
    }

    private func settingsAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(0.88)).padding(13)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(PadPalette.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PadPalette.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func mapped(_ key: String) -> String { mappings[key] ?? key }

    private func tactile(_ kind: TactileKind) {
        guard hapticsEnabled else { return }
        let now = Date()
        if kind == .press && now.timeIntervalSince(lastHapticTime) < 0.045 { return }
        lastHapticTime = now
        switch kind {
        case .press:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(hapticStrength))
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    private enum TactileKind { case press, selection, success }

    private func decodeMappings(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }
    private func encodeMappings(_ value: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    private func decodeOffsets(_ raw: String) -> [String: CGSize] {
        guard let data = raw.data(using: .utf8),
              let rawValues = try? JSONDecoder().decode([String: [Double]].self, from: data) else { return [:] }
        return rawValues.compactMapValues { v in v.count == 2 ? CGSize(width: v[0], height: v[1]) : nil }
    }
    private func encodeOffsets(_ value: [String: CGSize]) -> String {
        let raw = value.mapValues { [Double($0.width), Double($0.height)] }
        guard let data = try? JSONEncoder().encode(raw) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
