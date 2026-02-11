import Foundation

// MARK: - Boss Loot Reward System
// Displayed after boss fights in the loot modal

struct BossLootReward {
    /// Individual reward item in the loot screen
    struct RewardItem: Identifiable {
        let id = UUID()

        enum ItemType {
            case hash(amount: Int)
            case protocolBlueprint(protocolId: String, rarity: Rarity)
            case sectorAccess(sectorId: String, displayName: String, themeColor: String)
        }

        let type: ItemType

        // MARK: - Display Helpers

        var iconName: String {
            switch type {
            case .hash:
                return "number.circle.fill"
            case .protocolBlueprint(let protocolId, _):
                return ProtocolLibrary.get(protocolId)?.iconName ?? "cpu"
            case .sectorAccess:
                return "lock.open.fill"
            }
        }

        var displayColor: String {
            switch type {
            case .hash:
                return "#00d4ff"  // Cyan
            case .protocolBlueprint(let protocolId, let rarity):
                // Use protocol color if available, fallback to rarity color
                if let proto = ProtocolLibrary.get(protocolId) {
                    return proto.color
                }
                // Fallback to rarity hex color
                switch rarity {
                case .common: return "#9ca3af"
                case .rare: return "#3b82f6"
                case .epic: return "#a855f7"
                case .legendary: return "#f59e0b"
                }
            case .sectorAccess(_, _, let themeColor):
                return themeColor
            }
        }

        var encryptedTitle: String {
            return "▓▓▓▓▓▓▓▓"
        }

        var decryptedTitle: String {
            switch type {
            case .hash(let amount):
                return "+\(amount) Ħ"
            case .protocolBlueprint(let protocolId, _):
                return ProtocolLibrary.get(protocolId)?.name ?? "UNKNOWN"
            case .sectorAccess(_, let displayName, _):
                return displayName
            }
        }

        var decryptedSubtitle: String {
            switch type {
            case .hash:
                return L10n.BossLoot.hashReward
            case .protocolBlueprint(_, let rarity):
                return L10n.BossLoot.protocolAcquired + " • " + rarity.rawValue.uppercased()
            case .sectorAccess:
                return L10n.BossLoot.sectorAccessGranted
            }
        }
    }

    let difficulty: BossDifficulty
    let items: [RewardItem]
    let isFirstKill: Bool

    // MARK: - Computed Properties

    var totalHashReward: Int {
        for item in items {
            if case .hash(let amount) = item.type {
                return amount
            }
        }
        return 0
    }

    var droppedProtocolId: String? {
        for item in items {
            if case .protocolBlueprint(let protocolId, _) = item.type {
                return protocolId
            }
        }
        return nil
    }

    var unlockedSectorId: String? {
        for item in items {
            if case .sectorAccess(let sectorId, _, _) = item.type {
                return sectorId
            }
        }
        return nil
    }

    // MARK: - Factory

    /// Create a BossLootReward from fight results
    static func create(
        difficulty: BossDifficulty,
        hashReward: Int,
        protocolId: String?,
        protocolRarity: Rarity?,
        unlockedSector: (id: String, name: String, themeColor: String)?,
        isFirstKill: Bool
    ) -> BossLootReward {
        var items: [RewardItem] = []

        // Hash is always first and guaranteed
        items.append(RewardItem(type: .hash(amount: hashReward)))

        // Protocol blueprint (if dropped)
        if let protocolId = protocolId, let rarity = protocolRarity {
            items.append(RewardItem(type: .protocolBlueprint(protocolId: protocolId, rarity: rarity)))
        }

        // Sector access (first kill only)
        if let sector = unlockedSector {
            items.append(RewardItem(type: .sectorAccess(
                sectorId: sector.id,
                displayName: sector.name,
                themeColor: sector.themeColor
            )))
        }

        return BossLootReward(
            difficulty: difficulty,
            items: items,
            isFirstKill: isFirstKill
        )
    }
}
