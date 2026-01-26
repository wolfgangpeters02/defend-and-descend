import SwiftUI
import SpriteKit

// MARK: - System Tab View
// Main container with 4 tabs: BOARD, ARSENAL, UPGRADES, DEBUG

enum SystemTab: String, CaseIterable {
    case board = "BOARD"
    case arsenal = "ARSENAL"
    case upgrades = "UPGRADES"
    case debug = "DEBUG"

    var icon: String {
        switch self {
        case .board: return "cpu"
        case .arsenal: return "shield.lefthalf.filled"
        case .upgrades: return "arrow.up.circle.fill"
        case .debug: return "play.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .board: return DesignColors.primary
        case .arsenal: return DesignColors.secondary
        case .upgrades: return DesignColors.success
        case .debug: return DesignColors.warning
        }
    }
}

struct SystemTabView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: SystemTab = .board
    @State private var showDebugGame = false
    @State private var selectedSector: Sector?

    var body: some View {
        ZStack {
            // Background
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content area
                contentView

                // Custom tab bar
                customTabBar
            }
        }
        .fullScreenCover(isPresented: $showDebugGame) {
            if let sector = selectedSector {
                DebugGameView(
                    sector: sector,
                    protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                    onExit: {
                        showDebugGame = false
                        selectedSector = nil
                    }
                )
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .board:
            MotherboardView()
        case .arsenal:
            ArsenalView()
        case .upgrades:
            UpgradesView()
        case .debug:
            DebugView(
                onLaunch: { sector in
                    selectedSector = sector
                    showDebugGame = true
                }
            )
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SystemTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            DesignColors.surface
                .shadow(color: .black.opacity(0.5), radius: 10, y: -5)
        )
    }

    private func tabButton(for tab: SystemTab) -> some View {
        Button {
            HapticsService.shared.play(.selection)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .bold : .regular))
                    .foregroundColor(selectedTab == tab ? tab.color : DesignColors.muted)

                Text(tab.rawValue)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(selectedTab == tab ? tab.color : DesignColors.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == tab ?
                    tab.color.opacity(0.15) : Color.clear
            )
            .cornerRadius(8)
        }
    }
}

// MARK: - Motherboard View (BOARD Tab)

struct MotherboardView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showTDGame = false

    var body: some View {
        VStack(spacing: 0) {
            // Top HUD
            motherboardHUD

            // Main content - Motherboard status
            ZStack {
                // Background grid pattern
                GridPatternView()

                VStack(spacing: 20) {
                    Image(systemName: "cpu")
                        .font(.system(size: 80))
                        .foregroundColor(DesignColors.primary.opacity(0.5))

                    Text("MOTHERBOARD")
                        .font(DesignTypography.display(28))
                        .foregroundColor(DesignColors.primary)

                    // Efficiency display
                    VStack(spacing: 8) {
                        Text("SYSTEM EFFICIENCY")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)

                        Text("\(Int(appState.currentPlayer.motherboardEfficiency * 100))%")
                            .font(DesignTypography.display(48))
                            .foregroundColor(efficiencyColor)
                    }
                    .padding(.top, 10)

                    // Watts generation info
                    VStack(spacing: 4) {
                        Text("GENERATING")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(DesignColors.primary)
                            Text("+\(Int(appState.currentPlayer.globalUpgrades.wattsPerSecond * appState.currentPlayer.motherboardEfficiency))")
                                .font(DesignTypography.headline(20))
                                .foregroundColor(DesignColors.primary)
                            Text("/sec")
                                .font(DesignTypography.caption(12))
                                .foregroundColor(DesignColors.muted)
                        }
                    }

                    // Launch TD game button
                    Button {
                        HapticsService.shared.play(.medium)
                        showTDGame = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("ENTER SYSTEM DEFENSE")
                        }
                        .font(DesignTypography.headline(16))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DesignColors.primary)
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)

                    Text("Deploy firewalls to protect the CPU")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Build deck preview
            buildDeck
        }
        .fullScreenCover(isPresented: $showTDGame) {
            TDGameContainerView(mapId: "grasslands")
                .environmentObject(appState)
        }
    }

    private var motherboardHUD: some View {
        HStack {
            // Watts
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(DesignColors.primary)
                Text("\(appState.currentPlayer.watts)")
                    .font(DesignTypography.headline(18))
                    .foregroundColor(.white)
                Text("(+\(Int(appState.currentPlayer.globalUpgrades.wattsPerSecond))/s)")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(DesignColors.muted)
            }

            Spacer()

            // Efficiency bar
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(efficiencyColor)
                            .frame(width: geo.size.width * appState.currentPlayer.motherboardEfficiency)
                    }
                }
                .frame(width: 100, height: 8)

                Text("\(Int(appState.currentPlayer.motherboardEfficiency * 100))%")
                    .font(DesignTypography.caption(12))
                    .foregroundColor(efficiencyColor)
            }

            Spacer()

            // Settings
            Button {
                HapticsService.shared.play(.light)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignColors.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignColors.surface)
    }

    private var efficiencyColor: Color {
        let eff = appState.currentPlayer.motherboardEfficiency
        if eff >= 0.7 { return DesignColors.success }
        if eff >= 0.4 { return DesignColors.warning }
        return DesignColors.danger
    }

    private var buildDeck: some View {
        VStack(spacing: 8) {
            Text("BUILD FIREWALL")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.currentPlayer.compiledProtocols, id: \.self) { protocolId in
                        if let proto = ProtocolLibrary.get(protocolId) {
                            ProtocolBuildCard(protocol: proto)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(DesignColors.surface)
    }
}

// MARK: - Protocol Build Card

struct ProtocolBuildCard: View {
    let `protocol`: Protocol

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: `protocol`.iconName)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: `protocol`.color) ?? .cyan)

            Text("\(Int(`protocol`.firewallStats.damage))W")
                .font(DesignTypography.caption(10))
                .foregroundColor(DesignColors.muted)
        }
        .frame(width: 60, height: 60)
        .background(DesignColors.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: `protocol`.color)?.opacity(0.5) ?? .cyan.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Grid Pattern View

struct GridPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let gridSize: CGFloat = 40
                let dotSize: CGFloat = 2

                for x in stride(from: 0, to: size.width, by: gridSize) {
                    for y in stride(from: 0, to: size.height, by: gridSize) {
                        let rect = CGRect(
                            x: x - dotSize/2,
                            y: y - dotSize/2,
                            width: dotSize,
                            height: dotSize
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.1))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Arsenal View (ARSENAL Tab)

struct ArsenalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedProtocol: Protocol?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ARSENAL")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }
            }
            .padding()

            // Equipped protocol
            equippedSection

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Protocol grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Compiled protocols
                    Text("COMPILED PROTOCOLS")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ProtocolLibrary.all.filter { appState.currentPlayer.isProtocolCompiled($0.id) }) { proto in
                            ProtocolCard(
                                protocol: proto,
                                level: appState.currentPlayer.protocolLevel(proto.id),
                                isEquipped: appState.currentPlayer.equippedProtocolId == proto.id,
                                onTap: { selectedProtocol = proto }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Blueprints
                    Text("BLUEPRINTS")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(ProtocolLibrary.all.filter { !appState.currentPlayer.isProtocolCompiled($0.id) }) { proto in
                            ProtocolCard(
                                protocol: proto,
                                level: 1,
                                isLocked: true,
                                onTap: { selectedProtocol = proto }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .sheet(item: $selectedProtocol) { proto in
            ProtocolDetailSheet(protocol: proto)
        }
    }

    private var equippedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EQUIPPED FOR DEBUG")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(18))
                            .foregroundColor(.white)

                        Text("LV \(equipped.level)")
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Protocol Card

struct ProtocolCard: View {
    let `protocol`: Protocol
    var level: Int = 1
    var isEquipped: Bool = false
    var isLocked: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: isLocked ? "lock.fill" : `protocol`.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(
                            isLocked ? DesignColors.muted :
                                (Color(hex: `protocol`.color) ?? .cyan)
                        )
                }
                .frame(width: 50, height: 50)

                Text(`protocol`.name)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(isLocked ? DesignColors.muted : .white)
                    .lineLimit(1)

                if isLocked {
                    Text("\(`protocol`.compileCost)◈")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                } else {
                    Text("LV \(level)")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isEquipped ? DesignColors.primary.opacity(0.2) : DesignColors.surface
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEquipped ? DesignColors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Protocol Detail Sheet

struct ProtocolDetailSheet: View {
    let `protocol`: Protocol
    @ObservedObject var appState = AppState.shared
    @Environment(\.dismiss) var dismiss

    var currentLevel: Int {
        appState.currentPlayer.protocolLevel(`protocol`.id)
    }

    var isCompiled: Bool {
        appState.currentPlayer.isProtocolCompiled(`protocol`.id)
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: `protocol`.iconName)
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: `protocol`.color) ?? .cyan)

                            Text(`protocol`.name)
                                .font(DesignTypography.display(28))
                                .foregroundColor(.white)

                            Text(`protocol`.description)
                                .font(DesignTypography.body(14))
                                .foregroundColor(DesignColors.muted)
                                .multilineTextAlignment(.center)

                            if isCompiled {
                                Text("LV \(currentLevel)")
                                    .font(DesignTypography.headline(18))
                                    .foregroundColor(DesignColors.primary)
                            }
                        }
                        .padding()

                        // Stats
                        HStack(spacing: 20) {
                            // Firewall stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FIREWALL MODE")
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: "Damage", value: "\(Int(`protocol`.firewallStats.damage))")
                                ProtocolStatRow(label: "Range", value: "\(Int(`protocol`.firewallStats.range))")
                                ProtocolStatRow(label: "Fire Rate", value: String(format: "%.1f/s", `protocol`.firewallStats.fireRate))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)

                            // Weapon stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WEAPON MODE")
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: "Damage", value: "\(Int(`protocol`.weaponStats.damage))")
                                ProtocolStatRow(label: "Fire Rate", value: String(format: "%.1f/s", `protocol`.weaponStats.fireRate))
                                ProtocolStatRow(label: "Projectiles", value: "\(`protocol`.weaponStats.projectileCount)")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        // Actions
                        VStack(spacing: 12) {
                            if !isCompiled {
                                // Compile button
                                Button {
                                    compileProtocol()
                                } label: {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                        Text("COMPILE")
                                        Text("\(`protocol`.compileCost)◈")
                                            .foregroundColor(
                                                appState.currentPlayer.data >= `protocol`.compileCost ?
                                                    DesignColors.success : DesignColors.danger
                                            )
                                    }
                                    .font(DesignTypography.headline(16))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(DesignColors.primary)
                                    .cornerRadius(12)
                                }
                                .disabled(appState.currentPlayer.data < `protocol`.compileCost)
                            } else {
                                // Equip button
                                if appState.currentPlayer.equippedProtocolId != `protocol`.id {
                                    Button {
                                        equipProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("EQUIP FOR DEBUG")
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.primary)
                                        .cornerRadius(12)
                                    }
                                }

                                // Upgrade button
                                if currentLevel < 10 {
                                    let cost = `protocol`.baseUpgradeCost * currentLevel
                                    Button {
                                        upgradeProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.circle.fill")
                                            Text("UPGRADE TO LV \(currentLevel + 1)")
                                            Text("\(cost)◈")
                                                .foregroundColor(
                                                    appState.currentPlayer.data >= cost ?
                                                        DesignColors.success : DesignColors.danger
                                                )
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignColors.primary, lineWidth: 1)
                                        )
                                    }
                                    .disabled(appState.currentPlayer.data < cost)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignColors.primary)
                }
            }
        }
    }

    private func compileProtocol() {
        guard appState.currentPlayer.data >= `protocol`.compileCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= `protocol`.compileCost
            profile.compiledProtocols.append(`protocol`.id)
            profile.protocolLevels[`protocol`.id] = 1
        }
    }

    private func equipProtocol() {
        HapticsService.shared.play(.selection)
        appState.updatePlayer { profile in
            profile.equippedProtocolId = `protocol`.id
        }
    }

    private func upgradeProtocol() {
        let cost = `protocol`.baseUpgradeCost * currentLevel
        guard appState.currentPlayer.data >= cost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= cost
            profile.protocolLevels[`protocol`.id] = currentLevel + 1
        }
    }
}

// MARK: - Protocol Stat Row

struct ProtocolStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignTypography.body(14))
                .foregroundColor(DesignColors.muted)
            Spacer()
            Text(value)
                .font(DesignTypography.headline(14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Upgrades View (UPGRADES Tab)

struct UpgradesView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SYSTEM UPGRADES")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Watts balance
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.watts)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(GlobalUpgradeType.allCases, id: \.self) { upgradeType in
                        UpgradeCard(upgradeType: upgradeType)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Upgrade Card

struct UpgradeCard: View {
    let upgradeType: GlobalUpgradeType
    @ObservedObject var appState = AppState.shared

    private var upgrades: GlobalUpgrades {
        appState.currentPlayer.globalUpgrades
    }

    private var level: Int {
        upgrades.level(for: upgradeType)
    }

    private var cost: Int? {
        upgrades.upgradeCost(for: upgradeType)
    }

    private var isMaxed: Bool {
        upgrades.isMaxed(upgradeType)
    }

    private var canAfford: Bool {
        guard let c = cost else { return false }
        return appState.currentPlayer.watts >= c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: upgradeType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: upgradeType.color) ?? .cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(upgradeType.rawValue)
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.white)

                    Text(upgradeType.description)
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                }

                Spacer()

                Text("LV \(level)")
                    .font(DesignTypography.headline(20))
                    .foregroundColor(Color(hex: upgradeType.color) ?? .cyan)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: upgradeType.color) ?? .cyan)
                        .frame(width: geo.size.width * (CGFloat(level) / CGFloat(GlobalUpgrades.maxLevel)))
                }
            }
            .frame(height: 8)

            // Current value
            Text(upgradeType.valueDescription(at: level))
                .font(DesignTypography.body(14))
                .foregroundColor(.white)

            // Upgrade button
            if isMaxed {
                Text("MAX LEVEL")
                    .font(DesignTypography.headline(16))
                    .foregroundColor(DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
            } else if let upgradeCost = cost {
                Button {
                    performUpgrade()
                } label: {
                    HStack {
                        if let nextValue = upgradeType.nextValueDescription(at: level) {
                            Text("Next: \(nextValue)")
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("\(upgradeCost)⚡")
                            .foregroundColor(canAfford ? DesignColors.primary : DesignColors.danger)
                    }
                    .font(DesignTypography.headline(14))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
    }

    private func performUpgrade() {
        guard let upgradeCost = cost, canAfford else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.watts -= upgradeCost
            profile.globalUpgrades.upgrade(upgradeType)
        }
    }
}

// MARK: - Debug View (DEBUG Tab)

struct DebugView: View {
    @ObservedObject var appState = AppState.shared
    let onLaunch: (Sector) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DEBUG MODE")
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Data balance
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(appState.currentPlayer.data)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.success)
                }
            }
            .padding()

            // Loadout preview
            loadoutPreview

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Sector selection
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SELECT SECTOR")
                        .font(DesignTypography.caption(12))
                        .foregroundColor(DesignColors.muted)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(SectorLibrary.all) { sector in
                            SectorCard(
                                sector: sector,
                                isUnlocked: appState.currentPlayer.isSectorUnlocked(sector.id),
                                bestTime: appState.currentPlayer.sectorBestTime(sector.id),
                                onSelect: { onLaunch(sector) },
                                onUnlock: { unlockSector(sector) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }

    private var loadoutPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOADOUT")
                .font(DesignTypography.caption(12))
                .foregroundColor(DesignColors.muted)

            if let equipped = appState.currentPlayer.equippedProtocol() {
                HStack {
                    Image(systemName: equipped.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: equipped.color) ?? .cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(equipped.name)
                            .font(DesignTypography.headline(16))
                            .foregroundColor(.white)

                        Text("DMG: \(Int(equipped.weaponStats.damage)) | RATE: \(String(format: "%.1f", equipped.weaponStats.fireRate))/s")
                            .font(DesignTypography.caption(11))
                            .foregroundColor(DesignColors.muted)
                    }

                    Spacer()

                    Text("LV \(equipped.level)")
                        .font(DesignTypography.headline(16))
                        .foregroundColor(DesignColors.primary)
                }
                .padding()
                .background(DesignColors.surface)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private func unlockSector(_ sector: Sector) {
        guard appState.currentPlayer.data >= sector.unlockCost else { return }
        HapticsService.shared.play(.medium)
        appState.updatePlayer { profile in
            profile.data -= sector.unlockCost
            profile.unlockedSectors.append(sector.id)
        }
    }
}

// MARK: - Sector Card

struct SectorCard: View {
    let sector: Sector
    let isUnlocked: Bool
    var bestTime: TimeInterval?
    let onSelect: () -> Void
    let onUnlock: () -> Void

    @ObservedObject var appState = AppState.shared

    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 4) {
                Text(sector.name)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(isUnlocked ? .white : DesignColors.muted)

                Text(sector.subtitle)
                    .font(DesignTypography.caption(11))
                    .foregroundColor(DesignColors.muted)
            }

            // Difficulty badge
            Text(sector.difficulty.displayName)
                .font(DesignTypography.caption(10))
                .foregroundColor(Color(hex: sector.difficulty.color) ?? .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: sector.difficulty.color)?.opacity(0.2) ?? .green.opacity(0.2))
                .cornerRadius(4)

            // Data multiplier
            Text("◈ x\(String(format: "%.1f", sector.dataMultiplier))")
                .font(DesignTypography.caption(11))
                .foregroundColor(DesignColors.success)

            // Best time or lock status
            if isUnlocked {
                if let time = bestTime {
                    Text("Best: \(formatTime(time))")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }

                Button(action: onSelect) {
                    Text("LAUNCH")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignColors.success)
                        .cornerRadius(8)
                }
            } else {
                let canAfford = appState.currentPlayer.data >= sector.unlockCost
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("\(sector.unlockCost)◈")
                    }
                    .font(DesignTypography.headline(14))
                    .foregroundColor(canAfford ? .white : DesignColors.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canAfford ? DesignColors.surface : DesignColors.surface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(canAfford ? DesignColors.primary : DesignColors.muted, lineWidth: 1)
                    )
                }
                .disabled(!canAfford)
            }
        }
        .padding()
        .background(DesignColors.surface)
        .cornerRadius(16)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Debug Game View (Full Active Mode with Protocol Weapon)

struct DebugGameView: View {
    let sector: Sector
    let `protocol`: Protocol
    let onExit: () -> Void

    @ObservedObject var appState = AppState.shared
    @State private var gameState: GameState?
    @State private var gameScene: GameScene?
    @State private var showGameOver = false
    @State private var showVictory = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Game scene
                if let scene = gameScene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // HUD overlay
                VStack {
                    debugHUD
                    Spacer()
                }

                // Game over overlay
                if showGameOver || showVictory {
                    debugGameOverOverlay
                }
            }
            .onAppear {
                setupDebugGame(screenSize: geometry.size)
            }
        }
    }

    private var debugHUD: some View {
        HStack {
            // Health
            if let state = gameState {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(state.player.health))/\(Int(state.player.maxHealth))")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Sector name
            Text(sector.name)
                .font(DesignTypography.headline(16))
                .foregroundColor(DesignColors.success)

            Spacer()

            // Data collected
            if let state = gameState {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundColor(DesignColors.success)
                    Text("\(Int(CGFloat(state.stats.enemiesKilled) * sector.dataMultiplier))")
                        .font(DesignTypography.headline(14))
                        .foregroundColor(DesignColors.success)
                }
            }

            Spacer()

            // Time
            if let state = gameState {
                Text(formatTime(state.timeElapsed))
                    .font(DesignTypography.headline(14))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
    }

    private var debugGameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(showVictory ? "SECTOR CLEANSED" : "DEBUG FAILED")
                    .font(DesignTypography.display(32))
                    .foregroundColor(showVictory ? DesignColors.success : DesignColors.danger)

                // Stats
                if let state = gameState {
                    VStack(spacing: 12) {
                        let baseData = state.stats.enemiesKilled
                        let multipliedData = Int(CGFloat(baseData) * sector.dataMultiplier)
                        let finalData = showVictory ? multipliedData : multipliedData / 2

                        HStack {
                            Text("Viruses Eliminated")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text("\(state.stats.enemiesKilled)")
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("Data Collected")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .foregroundColor(DesignColors.success)
                                Text("+\(finalData)")
                                    .foregroundColor(DesignColors.success)
                            }
                        }

                        HStack {
                            Text("Time Survived")
                                .foregroundColor(DesignColors.muted)
                            Spacer()
                            Text(formatTime(state.timeElapsed))
                                .foregroundColor(.white)
                        }
                    }
                    .font(DesignTypography.body(16))
                    .padding()
                    .background(DesignColors.surface)
                    .cornerRadius(12)
                    .frame(maxWidth: 300)
                }

                // Exit button
                Button {
                    // Award Data before exiting
                    if let state = gameState {
                        let baseData = state.stats.enemiesKilled
                        let multipliedData = Int(CGFloat(baseData) * sector.dataMultiplier)
                        let finalData = showVictory ? multipliedData : multipliedData / 2
                        appState.updatePlayer { profile in
                            profile.data += max(1, finalData)
                        }
                    }
                    onExit()
                } label: {
                    Text("COLLECT & EXIT")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(DesignColors.primary)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    private func setupDebugGame(screenSize: CGSize) {
        // Create game state from Protocol
        let state = GameStateFactory.shared.createDebugGameState(
            gameProtocol: `protocol`,
            sector: sector,
            playerProfile: appState.currentPlayer
        )
        gameState = state

        // Create and configure scene
        let scene = GameScene()
        scene.configure(gameState: state, screenSize: screenSize)
        scene.onGameOver = { finalState in
            gameState = finalState
            if finalState.victory {
                showVictory = true
            } else {
                showGameOver = true
            }
            HapticsService.shared.play(finalState.victory ? .success : .warning)
        }
        scene.onStateUpdate = { updatedState in
            gameState = updatedState
        }

        gameScene = scene
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#Preview {
    SystemTabView()
}
