import SwiftUI

// MARK: - TDGameContainerView Panels
// Pause overlay, game over overlay, sector unlock, sector management

extension TDGameContainerView {

    // MARK: - Pause Overlay

    var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text(L10n.TD.systemPaused)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text(L10n.TD.protocolsSuspended)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                }

                // CPU Upgrade Section
                cpuUpgradeSection

                VStack(spacing: 16) {
                    Button(action: {
                        isPaused = false
                        HapticsService.shared.play(.light)
                    }) {
                        Text(L10n.Common.resume)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 220, height: 56)
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    // Sector Management button
                    Button(action: {
                        HapticsService.shared.play(.light)
                        showSectorManagementPanel = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                            Text(L10n.Sector.manageSectors)
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 220, height: 48)
                        .background(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(10)
                    }

                    Button(action: {
                        HapticsService.shared.play(.light)
                        dismiss()
                    }) {
                        Text(L10n.Common.abort)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 220, height: 56)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Game Over Overlay

    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Victory/Defeat title - System: Reboot themed
                VStack(spacing: 8) {
                    Text(gameState?.victory == true ? L10n.TD.systemSecure : L10n.TD.systemBreach)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(gameState?.victory == true ? .green : .red)

                    Text(gameState?.victory == true ? L10n.TD.threatsNeutralized : L10n.TD.cpuCompromised)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                }

                // Stats card
                if let state = gameState {
                    VStack(spacing: 16) {
                        GameEndStatRow(label: L10n.TD.waves, value: "\(state.wavesCompleted)/20", icon: "waveform.path", color: .purple)
                        GameEndStatRow(label: L10n.TD.viruses, value: "\(state.stats.enemiesKilled)", icon: "ladybug.fill", color: .red)
                        GameEndStatRow(label: L10n.Common.hash, value: "Ħ\(state.stats.hashEarned)", icon: "number.circle.fill", color: .cyan)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }

                Button(action: {
                    HapticsService.shared.play(.light)
                    dismiss()
                }) {
                    Text(L10n.Common.exit)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 220, height: 56)
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Sector Unlock Panel (Mega-Board)

    func sectorUnlockPanel(sectorId: String) -> some View {
        let status = SectorUnlockSystem.shared.getUnlockStatus(for: sectorId, profile: appState.currentPlayer)

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    showSectorUnlockPanel = false
                    selectedSectorForUnlock = nil
                }

            // Panel
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text(L10n.Sector.encrypted)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(status?.displayName ?? L10n.Common.unknown)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Description
                if let desc = status?.description {
                    Text(desc)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Cost display
                if let status = status {
                    VStack(spacing: 12) {
                        // Cost
                        HStack(spacing: 8) {
                            Text(L10n.Sector.decryptCost)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignColors.textSecondary)

                            Text("Ħ \(status.unlockCost)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Current balance
                        HStack(spacing: 8) {
                            Text(L10n.Sector.yourBalance)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignColors.textSecondary)

                            Text("Ħ \(status.currentHash)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(status.canAfford ? .green : .orange)
                        }

                        // Status message
                        Text(status.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(status.canUnlock ? .green : .orange)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(status.canUnlock ? Color.cyan.opacity(0.5) : Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                // Buttons
                HStack(spacing: 16) {
                    // Cancel
                    Button(action: {
                        HapticsService.shared.play(.light)
                        showSectorUnlockPanel = false
                        selectedSectorForUnlock = nil
                    }) {
                        Text(L10n.Common.cancel)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 50)
                            .background(DesignColors.muted.opacity(0.3))
                            .cornerRadius(8)
                    }

                    // Decrypt
                    Button(action: {
                        unlockSelectedSector()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                            Text(L10n.Sector.decrypt)
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(status?.canUnlock == true ? .black : DesignColors.muted)
                        .frame(width: 140, height: 50)
                        .background(status?.canUnlock == true ? DesignColors.primary : DesignColors.muted.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .disabled(status?.canUnlock != true)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(24)
        }
    }

    // MARK: - Sector Management Panel (Pause/Unpause)

    var sectorManagementPanel: some View {
        let unlockedSectorIds = appState.currentPlayer.unlockedSectorIds

        return ZStack {
            // Dimmed background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    showSectorManagementPanel = false
                }

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 36))
                        .foregroundColor(.cyan)

                    Text(L10n.Sector.management)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Text(L10n.Sector.pauseDescription)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(DesignColors.textSecondary)
                }

                // Sector list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(MotherboardLaneConfig.createAllLanes(), id: \.id) { lane in
                            let isUnlocked = lane.isStarterLane || unlockedSectorIds.contains(lane.sectorId)

                            if isUnlocked {
                                sectorRow(lane: lane)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 300)

                // Warning message
                if let state = gameState, !state.pausedSectorIds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(L10n.Sector.pausedWarning)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Close button
                Button(action: {
                    HapticsService.shared.play(.light)
                    showSectorManagementPanel = false
                }) {
                    Text(L10n.Common.done)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.cyan)
                        .cornerRadius(10)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                    )
            )
            .padding(20)
        }
    }

    private func sectorRow(lane: SectorLane) -> some View {
        let isPaused = gameState?.pausedSectorIds.contains(lane.sectorId) ?? false
        let themeColor = Color(hex: lane.themeColorHex) ?? .cyan

        return HStack(spacing: 16) {
            // Sector color indicator
            Circle()
                .fill(isPaused ? DesignColors.muted : themeColor)
                .frame(width: 12, height: 12)

            // Sector name
            VStack(alignment: .leading, spacing: 2) {
                Text(lane.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(isPaused ? DesignColors.muted : .white)

                Text(isPaused ? L10n.Common.paused : L10n.Common.active)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isPaused ? .orange : .green)
            }

            Spacer()

            // Toggle button
            Button(action: {
                toggleSectorPause(sectorId: lane.sectorId)
            }) {
                Text(isPaused ? L10n.Common.resume : L10n.Common.pause)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isPaused ? .green : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isPaused ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    )
            }
            // Don't allow pausing the starter lane (PSU)
            .disabled(lane.isStarterLane)
            .opacity(lane.isStarterLane ? 0.5 : 1.0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isPaused ? Color.orange.opacity(0.3) : themeColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func toggleSectorPause(sectorId: String) {
        guard var state = gameState else { return }

        if state.pausedSectorIds.contains(sectorId) {
            state.pausedSectorIds.remove(sectorId)
            HapticsService.shared.play(.light)
        } else {
            state.pausedSectorIds.insert(sectorId)
            HapticsService.shared.play(.warning)
        }

        // Update state - scene will pick up changes on next update cycle
        gameState = state
    }

    func unlockSelectedSector() {
        guard let sectorId = selectedSectorForUnlock else { return }

        let result = SectorUnlockSystem.shared.performUnlockTransaction(sectorId, appState: appState)

        if result.success {
            // Play celebration
            HapticsService.shared.play(.legendary)

            // Refresh mega-board visuals
            scene?.refreshMegaBoardVisuals()

            // Close panel
            showSectorUnlockPanel = false
            selectedSectorForUnlock = nil
        } else {
            HapticsService.shared.play(.error)
        }
    }
}
