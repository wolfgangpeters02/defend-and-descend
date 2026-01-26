import SwiftUI

// MARK: - Firewall Shop View
// System: Reboot - Purchase new Firewalls with Data currency
// Data is earned in Active/Debugger mode

struct FirewallShopView: View {
    @EnvironmentObject var appState: AppState
    let onBack: () -> Void

    @State private var selectedFirewall: FirewallDefinition?
    @State private var showPurchaseConfirm = false
    @State private var purchaseResult: PurchaseResult?

    enum PurchaseResult {
        case success(String)
        case insufficientData
        case alreadyOwned
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.12), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Currency display
                currencyBar

                // Firewall grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(FirewallUnlockSystem.getAllFirewalls()) { firewall in
                            FirewallCard(
                                firewall: firewall,
                                isUnlocked: isUnlocked(firewall),
                                canAfford: canAfford(firewall),
                                onTap: { selectedFirewall = firewall }
                            )
                        }
                    }
                    .padding()
                }
            }

            // Purchase confirmation modal
            if let firewall = selectedFirewall {
                FirewallDetailModal(
                    firewall: firewall,
                    isUnlocked: isUnlocked(firewall),
                    canAfford: canAfford(firewall),
                    currentData: appState.currentPlayer.data,
                    onPurchase: { purchaseFirewall(firewall) },
                    onDismiss: { selectedFirewall = nil }
                )
            }

            // Purchase result toast
            if let result = purchaseResult {
                purchaseResultToast(result)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("FIREWALL LAB")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Text("Unlock new defense protocols")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
        .padding()
    }

    // MARK: - Currency Bar

    private var currencyBar: some View {
        HStack(spacing: 24) {
            // Data balance
            HStack(spacing: 8) {
                Image(systemName: "memorychip")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DATA")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(appState.currentPlayer.data)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Hint
            Text("Earn Data in Debugger mode")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Helpers

    private func isUnlocked(_ firewall: FirewallDefinition) -> Bool {
        FirewallUnlockSystem.isUnlocked(
            weaponId: firewall.weaponId,
            unlockedWeapons: appState.currentPlayer.unlocks.weapons
        )
    }

    private func canAfford(_ firewall: FirewallDefinition) -> Bool {
        appState.currentPlayer.data >= firewall.dataCost
    }

    private func purchaseFirewall(_ firewall: FirewallDefinition) {
        appState.updatePlayer { profile in
            let success = FirewallUnlockSystem.purchaseFirewall(
                weaponId: firewall.weaponId,
                profile: &profile
            )
            if success {
                purchaseResult = .success(firewall.firewallName)
                HapticsService.shared.play(.success)
            } else if profile.unlocks.weapons.contains(firewall.weaponId) {
                purchaseResult = .alreadyOwned
            } else {
                purchaseResult = .insufficientData
                HapticsService.shared.play(.warning)
            }
        }

        selectedFirewall = nil

        // Clear result after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                purchaseResult = nil
            }
        }
    }

    private func purchaseResultToast(_ result: PurchaseResult) -> some View {
        VStack {
            HStack(spacing: 12) {
                switch result {
                case .success(let name):
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(name) UNLOCKED!")
                        .foregroundColor(.green)
                case .insufficientData:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not enough Data")
                        .foregroundColor(.red)
                case .alreadyOwned:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                    Text("Already unlocked")
                        .foregroundColor(.yellow)
                }
            }
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .padding()
            .background(Color.black.opacity(0.9))
            .cornerRadius(10)

            Spacer()
        }
        .padding(.top, 100)
    }
}

// MARK: - Firewall Card

struct FirewallCard: View {
    let firewall: FirewallDefinition
    let isUnlocked: Bool
    let canAfford: Bool
    let onTap: () -> Void

    private var tierColor: Color {
        switch firewall.tier {
        case 0: return .gray
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        case 4: return .red
        default: return .white
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isUnlocked ? tierColor.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: firewall.icon)
                        .font(.title)
                        .foregroundColor(isUnlocked ? tierColor : .gray)

                    // Lock overlay
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .offset(x: 20, y: 20)
                    }
                }

                // Name
                Text(firewall.firewallName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isUnlocked ? .white : .gray)
                    .lineLimit(1)

                // Status/Cost
                if isUnlocked {
                    Text("UNLOCKED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                } else if firewall.dataCost > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.caption2)
                        Text("\(firewall.dataCost)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(canAfford ? .green : .red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isUnlocked ? tierColor.opacity(0.5) : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - Firewall Detail Modal

struct FirewallDetailModal: View {
    let firewall: FirewallDefinition
    let isUnlocked: Bool
    let canAfford: Bool
    let currentData: Int
    let onPurchase: () -> Void
    let onDismiss: () -> Void

    private var tierColor: Color {
        switch firewall.tier {
        case 0: return .gray
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        case 4: return .red
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Modal content
            VStack(spacing: 20) {
                // Icon and name
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(tierColor.opacity(0.3))
                            .frame(width: 80, height: 80)

                        Image(systemName: firewall.icon)
                            .font(.system(size: 40))
                            .foregroundColor(tierColor)
                    }

                    Text(firewall.firewallName)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(firewall.tierName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(tierColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(tierColor.opacity(0.2))
                        .cornerRadius(4)
                }

                // Description
                Text(firewall.description)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Divider().background(Color.gray.opacity(0.3))

                // Cost/Status
                if isUnlocked {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("UNLOCKED")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "memorychip")
                                .foregroundColor(.green)
                            Text("COST: \(firewall.dataCost) DATA")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        Text("Your Data: \(currentData)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(canAfford ? .gray : .red)
                    }
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button(action: onDismiss) {
                        Text("CLOSE")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }

                    if !isUnlocked {
                        Button(action: onPurchase) {
                            Text("UNLOCK")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(canAfford ? .black : .gray)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(canAfford ? Color.green : Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .disabled(!canAfford)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tierColor.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    FirewallShopView(onBack: {})
        .environmentObject(AppState.shared)
}
