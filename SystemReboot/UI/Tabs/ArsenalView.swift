import SwiftUI

// MARK: - System Menu Sheet (Arsenal + Settings)

struct SystemMenuSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ArsenalView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignColors.muted)
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

            Text("\(Int(`protocol`.firewallStats.damage))")
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

// MARK: - Arsenal View

struct ArsenalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedProtocol: Protocol?
    @State private var showCurrencyInfo: CurrencyInfoType? = nil
    @State private var showSettings = false
    @ObservedObject private var hintManager = TutorialHintManager.shared
    // Boss Arena state
    @State private var showBossFightSheet = false
    @State private var selectedBossType: String = "cyberboss"
    @State private var selectedDifficulty: BossDifficulty = .easy

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.Tabs.arsenal)
                    .font(DesignTypography.display(28))
                    .foregroundColor(.white)

                Spacer()

                // Settings gear icon
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignColors.muted)
                }
                .padding(.trailing, 12)

                // Hash balance - tappable for info
                HStack(spacing: 6) {
                    Text("Ħ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignColors.primary)
                    Text("\(appState.currentPlayer.hash)")
                        .font(DesignTypography.headline(18))
                        .foregroundColor(DesignColors.primary)
                }
                .onTapGesture { showCurrencyInfo = .hash }
            }
            .padding()
            .sheet(item: $showCurrencyInfo) { info in
                CurrencyInfoSheet(info: info)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }

            // Equipped protocol
            equippedSection

            Divider()
                .background(DesignColors.muted.opacity(0.3))
                .padding(.horizontal)

            // Protocol grid
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Compiled protocols
                    Text(L10n.Arsenal.compiled)
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

                    // Blueprints (owned but not compiled)
                    let ownedBlueprints = ProtocolLibrary.all.filter {
                        appState.currentPlayer.hasBlueprint($0.id) && !appState.currentPlayer.isProtocolCompiled($0.id)
                    }

                    if !ownedBlueprints.isEmpty {
                        Text(L10n.Arsenal.blueprints)
                            .font(DesignTypography.caption(12))
                            .foregroundColor(DesignColors.primary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(ownedBlueprints) { proto in
                                ProtocolCard(
                                    protocol: proto,
                                    level: 1,
                                    isBlueprint: true,
                                    onTap: {
                                        hintManager.markBlueprintSeen(proto.id)
                                        selectedProtocol = proto
                                    }
                                )
                                .tutorialGlow(
                                    color: RarityColors.color(for: proto.rarity),
                                    isActive: hintManager.unseenBlueprintIds.contains(proto.id)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Undiscovered (no blueprint, not compiled, not starter)
                    let undiscoveredProtocols = ProtocolLibrary.all.filter {
                        !appState.currentPlayer.isProtocolCompiled($0.id) &&
                        !appState.currentPlayer.hasBlueprint($0.id) &&
                        $0.id != ProtocolLibrary.starterProtocolId
                    }

                    if !undiscoveredProtocols.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Arsenal.undiscovered)
                                .font(DesignTypography.caption(12))
                                .foregroundColor(DesignColors.muted)

                            Text(L10n.Arsenal.defeatBossesHint)
                                .font(DesignTypography.caption(10))
                                .foregroundColor(DesignColors.muted.opacity(0.7))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(undiscoveredProtocols) { proto in
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

                    // Boss Arena Section
                    bossArenaSection
                        .padding(.top, 16)
                }
                .padding(.vertical)
            }
        }
        .sheet(item: $selectedProtocol) { proto in
            ProtocolDetailSheet(protocol: proto)
        }
        .fullScreenCover(isPresented: $showBossFightSheet) {
            bossArenaFightView
        }
    }

    // MARK: - Boss Arena Section

    private var bossArenaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text(L10n.Settings.bossArena)
                    .font(DesignTypography.caption(12))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text(L10n.Settings.bossArenaDesc)
                    .font(DesignTypography.caption(12))
                    .foregroundColor(DesignColors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Boss selection
                ForEach(availableBosses, id: \.0) { bossId, bossName in
                    bossRow(id: bossId, name: bossName)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "161b22") ?? Color.gray.opacity(0.2))
            )
            .padding(.horizontal)
        }
    }

    private var availableBosses: [(String, String)] {
        [
            ("cyberboss", L10n.Boss.cyberboss),
            ("void_harbinger", L10n.Boss.voidHarbinger)
        ]
    }

    private func bossRow(id: String, name: String) -> some View {
        let killRecord = appState.currentPlayer.bossKillRecords[id]
        let isDefeated = killRecord != nil && (killRecord?.totalKills ?? 0) > 0

        return HStack {
            // Boss icon
            Image(systemName: id == "cyberboss" ? "cpu.fill" : "tornado")
                .font(.system(size: 24))
                .foregroundColor(id == "cyberboss" ? .red : .purple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DesignTypography.headline(16))
                    .foregroundColor(.white)

                if isDefeated {
                    Text(L10n.Settings.defeated)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.success)
                } else {
                    Text(L10n.Settings.notEncountered)
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }

            Spacer()

            // Fight button
            Button {
                selectedBossType = id
                showBossFightSheet = true
            } label: {
                Text(L10n.Settings.fight)
                    .font(DesignTypography.caption(12))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(id == "cyberboss" ? Color.red : Color.purple)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var bossArenaFightView: some View {
        if let boss = BossEncounter.all.first(where: { $0.bossId == selectedBossType }) {
            BossGameView(
                boss: boss,
                difficulty: selectedDifficulty,
                protocol: appState.currentPlayer.equippedProtocol() ?? ProtocolLibrary.kernelPulse,
                onExit: {
                    showBossFightSheet = false
                }
            )
        } else {
            Color.black
                .ignoresSafeArea()
        }
    }

    private var equippedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Arsenal.equippedForDebug)
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

                        Text(L10n.Common.lv(equipped.level))
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
    var isBlueprint: Bool = false  // Owned blueprint, not yet compiled
    var onTap: () -> Void = {}

    // Rarity-based color for borders and effects
    private var rarityColor: Color {
        RarityColors.color(for: `protocol`.rarity)
    }

    private var iconColor: Color {
        if isLocked {
            return DesignColors.muted
        } else if isBlueprint {
            return (Color(hex: `protocol`.color) ?? .cyan).opacity(0.7)
        } else {
            return Color(hex: `protocol`.color) ?? .cyan
        }
    }

    // Border color based on state and rarity
    private var borderColor: Color {
        if isLocked {
            return DesignColors.muted.opacity(0.3)
        } else if isEquipped {
            return rarityColor
        } else if isBlueprint {
            return rarityColor.opacity(0.6)
        } else {
            // Compiled - show rarity outline
            return rarityColor.opacity(0.5)
        }
    }

    private var borderWidth: CGFloat {
        isEquipped ? 2.5 : 1.5
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Rarity glow effect for non-locked cards
                    if !isLocked {
                        Circle()
                            .fill(rarityColor.opacity(isEquipped ? 0.25 : 0.1))
                            .frame(width: 50, height: 50)
                    }

                    Image(systemName: isLocked ? "lock.fill" : `protocol`.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(iconColor)

                    // Blueprint badge
                    if isBlueprint {
                        Image(systemName: "doc.badge.gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundColor(rarityColor)
                            .offset(x: 18, y: -18)
                    }

                    // Rarity dot indicator (top-left corner)
                    if !isLocked {
                        Circle()
                            .fill(rarityColor)
                            .frame(width: 6, height: 6)
                            .offset(x: -20, y: -20)
                    }
                }
                .frame(width: 50, height: 50)

                Text(`protocol`.name)
                    .font(DesignTypography.caption(10))
                    .foregroundColor(isLocked ? DesignColors.muted : .white)
                    .lineLimit(1)

                if isLocked {
                    // Show which boss drops this
                    if let boss = BalanceConfig.BossLoot.bossesDropping(`protocol`.id).first {
                        Text(BalanceConfig.BossLoot.bossDisplayName(boss))
                            .font(DesignTypography.caption(8))
                            .foregroundColor(DesignColors.danger.opacity(0.7))
                    } else {
                        Text("Ħ\(`protocol`.compileCost)")
                            .font(DesignTypography.caption(10))
                            .foregroundColor(DesignColors.muted)
                    }
                } else if isBlueprint {
                    Text("Ħ\(`protocol`.compileCost)")
                        .font(DesignTypography.caption(10))
                        .foregroundColor(rarityColor)
                } else {
                    Text(L10n.Common.lv(level))
                        .font(DesignTypography.caption(10))
                        .foregroundColor(DesignColors.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isEquipped ? rarityColor.opacity(0.15) :
                    isBlueprint ? rarityColor.opacity(0.08) :
                    DesignColors.surface
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: isEquipped ? rarityColor.opacity(0.4) : .clear,
                radius: 8
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

    var hasBlueprint: Bool {
        let isStarter = `protocol`.id == ProtocolLibrary.starterProtocolId
        return isStarter || appState.currentPlayer.hasBlueprint(`protocol`.id)
    }

    /// Protocol with player's level applied for accurate stat display
    var leveledProtocol: Protocol {
        var proto = `protocol`
        proto.level = currentLevel
        return proto
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
                                Text(L10n.Common.lv(currentLevel))
                                    .font(DesignTypography.headline(18))
                                    .foregroundColor(DesignColors.primary)
                            }
                        }
                        .padding()

                        // Stats
                        HStack(spacing: 20) {
                            // Firewall stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Mode.firewall)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: L10n.Stats.damage, value: "\(Int(leveledProtocol.firewallStats.damage))")
                                ProtocolStatRow(label: L10n.Stats.range, value: "\(Int(leveledProtocol.firewallStats.range))")
                                ProtocolStatRow(label: L10n.Stats.fireRate, value: String(format: "%.1f/s", leveledProtocol.firewallStats.fireRate))
                                ProtocolStatRow(label: L10n.Stats.dps, value: String(format: "%.1f", leveledProtocol.firewallStats.damage * leveledProtocol.firewallStats.fireRate * CGFloat(leveledProtocol.firewallStats.projectileCount)))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DesignColors.surface)
                            .cornerRadius(12)

                            // Weapon stats
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Mode.weapon)
                                    .font(DesignTypography.caption(11))
                                    .foregroundColor(DesignColors.muted)

                                ProtocolStatRow(label: L10n.Stats.damage, value: "\(Int(leveledProtocol.weaponStats.damage))")
                                ProtocolStatRow(label: L10n.Stats.fireRate, value: String(format: "%.1f/s", leveledProtocol.weaponStats.fireRate))
                                ProtocolStatRow(label: L10n.Stats.projectiles, value: "\(leveledProtocol.weaponStats.projectileCount)")
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
                                if hasBlueprint {
                                    // Has blueprint - show compile button
                                    Button {
                                        compileProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "hammer.fill")
                                            Text(L10n.Arsenal.compile)
                                            Text("Ħ\(`protocol`.compileCost)")
                                                .foregroundColor(
                                                    appState.currentPlayer.hash >= `protocol`.compileCost ?
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
                                    .disabled(appState.currentPlayer.hash < `protocol`.compileCost)
                                } else {
                                    // No blueprint - show "Blueprint Required" message
                                    VStack(spacing: 8) {
                                        HStack {
                                            Image(systemName: "lock.fill")
                                            Text(L10n.Arsenal.blueprintRequired)
                                        }
                                        .font(DesignTypography.headline(16))
                                        .foregroundColor(DesignColors.muted)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DesignColors.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(DesignColors.muted.opacity(0.3), lineWidth: 1)
                                        )

                                        Text(L10n.Arsenal.defeatBossesHint)
                                            .font(DesignTypography.caption(12))
                                            .foregroundColor(DesignColors.muted.opacity(0.7))
                                    }
                                }
                            } else {
                                // Equip button
                                if appState.currentPlayer.equippedProtocolId != `protocol`.id {
                                    Button {
                                        equipProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text(L10n.Arsenal.equipForDebug)
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
                                if currentLevel < BalanceConfig.maxUpgradeLevel {
                                    // Uses centralized formula from BalanceConfig
                                    let cost = BalanceConfig.exponentialUpgradeCost(baseCost: `protocol`.baseUpgradeCost, currentLevel: currentLevel)
                                    Button {
                                        upgradeProtocol()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.circle.fill")
                                            Text(L10n.Arsenal.upgradeTo(currentLevel + 1))
                                            Text("Ħ\(cost)")
                                                .foregroundColor(
                                                    appState.currentPlayer.hash >= cost ?
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
                                    .disabled(appState.currentPlayer.hash < cost)
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
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                    .foregroundColor(DesignColors.primary)
                }
            }
        }
    }

    private func compileProtocol() {
        // Check blueprint ownership (starter protocol is always available)
        let isStarter = `protocol`.id == ProtocolLibrary.starterProtocolId
        guard isStarter || appState.currentPlayer.hasBlueprint(`protocol`.id) else {
            return
        }

        guard appState.currentPlayer.hash >= `protocol`.compileCost else { return }
        HapticsService.shared.play(.medium)
        AnalyticsService.shared.trackProtocolCompiled(protocolId: `protocol`.id, cost: `protocol`.compileCost)
        appState.updatePlayer { profile in
            profile.hash -= `protocol`.compileCost
            profile.compiledProtocols.append(`protocol`.id)
            profile.protocolLevels[`protocol`.id] = 1
            // Remove from blueprints (now compiled)
            profile.protocolBlueprints.removeAll { $0 == `protocol`.id }
        }
    }

    private func equipProtocol() {
        HapticsService.shared.play(.selection)
        appState.updatePlayer { profile in
            profile.equippedProtocolId = `protocol`.id
        }
    }

    private func upgradeProtocol() {
        // Uses centralized formula from BalanceConfig
        let cost = BalanceConfig.exponentialUpgradeCost(baseCost: `protocol`.baseUpgradeCost, currentLevel: currentLevel)
        guard appState.currentPlayer.hash >= cost else { return }
        HapticsService.shared.play(.medium)
        AnalyticsService.shared.trackProtocolUpgraded(protocolId: `protocol`.id, fromLevel: currentLevel, toLevel: currentLevel + 1)
        appState.updatePlayer { profile in
            profile.hash -= cost
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
