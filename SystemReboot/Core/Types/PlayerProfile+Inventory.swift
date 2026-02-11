import Foundation

// MARK: - Inventory (Protocols, Blueprints, Equipment)

extension PlayerProfile {

    // MARK: - Protocol Helpers

    /// Check if a protocol is compiled (unlocked)
    func isProtocolCompiled(_ protocolId: String) -> Bool {
        return compiledProtocols.contains(protocolId)
    }

    /// Get the level of a protocol (1 if not leveled)
    func protocolLevel(_ protocolId: String) -> Int {
        return protocolLevels[protocolId] ?? 1
    }

    /// Check if player has a blueprint for a protocol
    func hasBlueprint(_ protocolId: String) -> Bool {
        return protocolBlueprints.contains(protocolId)
    }

    /// Get the currently equipped protocol
    func equippedProtocol() -> Protocol? {
        guard var proto = ProtocolLibrary.get(equippedProtocolId) else { return nil }
        proto.level = protocolLevel(equippedProtocolId)
        proto.isCompiled = true
        return proto
    }

    // MARK: - Boss Kill Tracking (Blueprint System)

    /// Get kill count for a specific boss
    func bossKillCount(_ bossId: String) -> Int {
        return bossKillRecords[bossId]?.totalKills ?? 0
    }

    /// Track a boss kill
    mutating func recordBossKill(_ bossId: String, difficulty: BossDifficulty) {
        var record = bossKillRecords[bossId] ?? BossKillRecord(bossId: bossId)
        record.totalKills += 1
        record.killsByDifficulty[difficulty.rawValue, default: 0] += 1
        record.lastKillDate = Date()
        bossKillRecords[bossId] = record
    }

    /// Track a blueprint drop from a boss
    mutating func recordBlueprintDrop(_ bossId: String, protocolId: String) {
        if var record = bossKillRecords[bossId] {
            record.blueprintsEarnedFromBoss.append(protocolId)
            bossKillRecords[bossId] = record
        }
    }

    /// Get kills since last blueprint drop from a boss
    func killsSinceLastDrop(_ bossId: String) -> Int {
        guard let record = bossKillRecords[bossId] else { return 0 }
        return record.totalKills - record.blueprintsEarnedFromBoss.count
    }
}
