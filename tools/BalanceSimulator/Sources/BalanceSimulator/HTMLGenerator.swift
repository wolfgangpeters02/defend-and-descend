import Foundation
import CoreGraphics

// MARK: - HTML Balance Reference Generator
// Generates a comprehensive HTML reference dashboard from BalanceConfig values.
// All data comes from the real BalanceConfig.swift (symlinked), so it's always in sync.

struct HTMLGenerator {

    // Reference hash rates for time-to-afford columns
    static let rates: [(label: String, level: Int)] = [
        ("CPU 1", 1), ("CPU 5", 5), ("CPU 10", 10)
    ]

    // MARK: - Formatting

    static func fNum(_ n: Double) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", n / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", n / 1_000) }
        if n == floor(n) { return String(format: "%.0f", n) }
        return String(format: "%.2f", n)
    }

    static func fTime(_ seconds: Double) -> String {
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        if seconds < 3600 { return String(format: "%.1fm", seconds / 60) }
        if seconds < 86400 { return String(format: "%.1fh", seconds / 3600) }
        return String(format: "%.1fd", seconds / 86400)
    }

    static func tCls(_ seconds: Double) -> String {
        if seconds < 60 { return "t1" }       // trivial
        if seconds < 300 { return "t2" }      // easy
        if seconds < 1800 { return "t3" }     // moderate
        if seconds < 7200 { return "t4" }     // significant
        return "t5"                            // major
    }

    static func hps(_ level: Int) -> Double {
        Double(BalanceConfig.HashEconomy.hashPerSecond(at: level))
    }

    static func timeTd(_ cost: Double, _ rate: Double) -> String {
        let s = cost / rate
        return "<td class=\"\(tCls(s))\">\(fTime(s))</td>"
    }

    static func pct(_ v: Double) -> String {
        String(format: "%.0f%%", v * 100)
    }

    // MARK: - HTML Helpers

    static func th(_ headers: [String]) -> String {
        "<thead><tr>" + headers.map { "<th>\($0)</th>" }.joined() + "</tr></thead>"
    }

    static func td(_ cells: [String]) -> String {
        "<tr>" + cells.map { "<td>\($0)</td>" }.joined() + "</tr>"
    }

    static func h2(_ text: String) -> String { "<h2>\(text)</h2>" }
    static func h3(_ text: String) -> String { "<h3>\(text)</h3>" }
    static func note(_ text: String) -> String { "<p class=\"note\">\(text)</p>" }

    // MARK: - Generate

    static func generate() -> String {
        var s = ""
        s += preamble()
        s += "<header><h1>BALANCE REFERENCE</h1>"
        s += "<p>System: Reboot &mdash; Generated from BalanceConfig.swift</p></header>\n"
        s += tabNav()
        s += "<main>\n"
        s += panel("economy", "Economy", economyHTML())
        s += panel("components", "Components", componentsHTML())
        s += panel("towers", "Towers", towersHTML())
        s += panel("bosses", "Bosses", bossesHTML())
        s += panel("loot", "Loot", lootHTML())
        s += panel("scaling", "Scaling", scalingHTML())
        s += panel("sectors", "Sectors", sectorsHTML())
        s += panel("analysis", "Analysis", analysisHTML())
        s += "</main>\n"
        s += script()
        s += "</body></html>"
        return s
    }

    static func panel(_ id: String, _ title: String, _ content: String) -> String {
        "<section id=\"\(id)\" class=\"panel\">\(content)</section>\n"
    }

    static func tabNav() -> String {
        let tabs = [
            ("economy", "Economy"), ("components", "Components"), ("towers", "Towers"),
            ("bosses", "Bosses"), ("loot", "Loot"), ("scaling", "Scaling"),
            ("sectors", "Sectors"), ("analysis", "Analysis")
        ]
        var s = "<nav>"
        for (id, label) in tabs {
            s += "<button data-tab=\"\(id)\">\(label)</button>"
        }
        s += "</nav>\n"
        return s
    }

    // MARK: - Economy

    static func economyHTML() -> String {
        var s = h2("Hash Economy")

        // Hash rate formula
        s += h3("Active Hash Rate Formula")
        s += note("&#x210E;/sec = CPU_base(level) &times; CPU_Tier &times; Network(level) &times; (Efficiency / 100) [&times; Overclock if active]")

        // Hash generation table
        s += h3("Hash Generation by CPU Level")
        s += note("CPU base formula: \(fNum(Double(BalanceConfig.HashEconomy.baseHashPerSecond))) &times; \(Double(BalanceConfig.HashEconomy.cpuLevelScaling))^(level-1). Network and CPU Tier stack multiplicatively.")
        s += "<table>" + th(["CPU Lv", "&#x210E;/sec", "&#x210E;/min", "&#x210E;/hour", "Time to 1K", "Time to 10K", "Time to 100K"])
        s += "<tbody>"
        for lv in 1...BalanceConfig.Components.maxLevel {
            let r = hps(lv)
            s += "<tr><td>\(lv)</td><td>\(String(format: "%.2f", r))</td>"
            s += "<td>\(fNum(r * 60))</td><td>\(fNum(r * 3600))</td>"
            s += timeTd(1000, r) + timeTd(10000, r) + timeTd(100000, r)
            s += "</tr>"
        }
        s += "</tbody></table>"

        // CPU Tier upgrades
        s += h3("CPU Tier Upgrades")
        s += "<table>" + th(["Tier", "Multiplier", "Cost", "Cumulative"])
        s += "<tbody>"
        var cumCPU = 0
        for tier in 1...BalanceConfig.CPU.maxTier {
            let mult = Double(BalanceConfig.CPU.multiplier(tier: tier))
            let cost = BalanceConfig.CPU.upgradeCost(currentTier: tier)
            if let c = cost { cumCPU += c }
            s += td(["\(tier)", "\(mult)x",
                      cost != nil ? "\(fNum(Double(cost!)))" : "MAX",
                      tier > 1 ? fNum(Double(cumCPU)) : "-"])
        }
        s += "</tbody></table>"

        // Storage
        s += h3("Storage Capacity by Level")
        s += note("Formula: \(fNum(Double(BalanceConfig.Components.storageBaseCapacity))) &times; 2^(level-1)")
        s += "<table>" + th(["Level", "Capacity", "Offline Rate", "Upgrade Cost", "Fill @ CPU 1", "Fill @ CPU 5"])
        s += "<tbody>"
        for lv in 1...BalanceConfig.Components.maxLevel {
            let cap = BalanceConfig.Components.storageCapacity(at: lv)
            let offRate = Double(BalanceConfig.Components.storageOfflineRate(at: lv))
            let cost = lv < BalanceConfig.Components.maxLevel
                ? BalanceConfig.Components.upgradeCost(for: "storage", at: lv) ?? 0 : 0
            s += "<tr><td>\(lv)</td><td>\(fNum(Double(cap)))</td>"
            s += "<td>\(pct(offRate))</td>"
            s += "<td>\(lv < BalanceConfig.Components.maxLevel ? fNum(Double(cost)) : "MAX")</td>"
            s += timeTd(Double(cap), hps(1)) + timeTd(Double(cap), hps(5))
            s += "</tr>"
        }
        s += "</tbody></table>"

        // Overclock
        s += h3("Overclock")
        s += "<table>" + th(["Parameter", "Value"])
        s += "<tbody>"
        s += td(["Duration", "\(Int(BalanceConfig.Overclock.duration))s"])
        s += td(["Hash Multiplier", "\(Double(BalanceConfig.Overclock.hashMultiplier))x"])
        s += td(["Threat Multiplier", "\(Double(BalanceConfig.Overclock.threatMultiplier))x"])
        s += td(["Power Demand", "\(Double(BalanceConfig.Overclock.powerDemandMultiplier))x"])
        s += "</tbody></table>"

        // Offline
        s += h3("Offline Earnings")
        s += note("Offline &#x210E;/s = CPU_base &times; CPU_Tier &times; Network &times; (Efficiency/100) &times; \(Double(BalanceConfig.HashEconomy.offlineEarningsRate))")
        s += "<table>" + th(["CPU Level", "Online &#x210E;/s", "Offline &#x210E;/s", "Max \(Int(Double(BalanceConfig.HashEconomy.maxOfflineHours)))h Earnings"])
        s += "<tbody>"
        let offRate = Double(BalanceConfig.HashEconomy.offlineEarningsRate)
        let maxH = Double(BalanceConfig.HashEconomy.maxOfflineHours)
        for lv in [1, 3, 5, 7, 10] {
            let online = hps(lv)
            let offline = online * offRate
            let maxEarnings = offline * maxH * 3600
            s += td(["\(lv)", String(format: "%.2f", online), String(format: "%.2f", offline), fNum(maxEarnings)])
        }
        s += "</tbody></table>"
        s += note("Above rates assume CPU Tier 1 (1.0x) and Network Lv1 (1.0x). Multiply by CPU Tier and Network level for actual rates.")

        return s
    }

    // MARK: - Components

    static func componentsHTML() -> String {
        var s = h2("Component Upgrades")
        s += note("All costs use exponential formula: baseCost &times; 2^(level-1). Max level: \(BalanceConfig.Components.maxLevel)")

        // Summary table
        s += h3("Component Overview")
        s += "<table>" + th(["Component", "Sector", "Base Cost", "Total to Max", "Effect @ Lv1", "Effect @ Lv10"])
        s += "<tbody>"

        let comps: [(id: String, name: String, effect1: String, effect10: String)] = [
            ("psu", "PSU", "\(BalanceConfig.Components.psuCapacity(at: 1))W",
             "\(BalanceConfig.Components.psuCapacity(at: 10))W"),
            ("ram", "RAM", String(format: "%.2fx recovery", Double(BalanceConfig.Components.ramEfficiencyRegen(at: 1))),
             String(format: "%.2fx recovery", Double(BalanceConfig.Components.ramEfficiencyRegen(at: 10)))),
            ("gpu", "GPU", String(format: "%.2fx tower dmg", Double(BalanceConfig.Components.gpuDamageMultiplier(at: 1))),
             String(format: "%.2fx tower dmg", Double(BalanceConfig.Components.gpuDamageMultiplier(at: 10)))),
            ("cache", "Cache", String(format: "%.2fx atk speed", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 1))),
             String(format: "%.2fx atk speed", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 10)))),
            ("storage", "Storage", "\(fNum(Double(BalanceConfig.Components.storageCapacity(at: 1)))) cap",
             "\(fNum(Double(BalanceConfig.Components.storageCapacity(at: 10)))) cap"),
            ("expansion", "Expansion", "+\(BalanceConfig.Components.expansionExtraSlots(at: 1)) slots",
             "+\(BalanceConfig.Components.expansionExtraSlots(at: 10)) slots"),
            ("network", "Network", String(format: "%.2fx hash", Double(BalanceConfig.Components.networkHashMultiplier(at: 1))),
             String(format: "%.2fx hash", Double(BalanceConfig.Components.networkHashMultiplier(at: 10)))),
            ("io", "I/O", String(format: "%.2fx pickup", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: 1))),
             String(format: "%.2fx pickup", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: 10)))),
            ("cpu", "CPU", String(format: "%.1f &#x210E;/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: 1))),
             String(format: "%.1f &#x210E;/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: 10))))
        ]

        for c in comps {
            let base = BalanceConfig.Components.baseCost(for: c.id)
            var total = 0
            for lv in 1..<BalanceConfig.Components.maxLevel {
                total += BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: lv)
            }
            s += td([c.name, c.id.uppercased(), fNum(Double(base)), fNum(Double(total)), c.effect1, c.effect10])
        }
        s += "</tbody></table>"

        // Detailed per-component tables
        for c in comps {
            s += h3("\(c.name) Upgrade Costs & Effects")
            var headers = ["Level", "Cost", "Cumulative", "Effect"]
            for r in rates { headers.append("Time @ \(r.label)") }
            s += "<table>" + th(headers) + "<tbody>"

            let base = BalanceConfig.Components.baseCost(for: c.id)
            var cum = 0
            for lv in 1...BalanceConfig.Components.maxLevel {
                let cost = lv < BalanceConfig.Components.maxLevel
                    ? BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: lv) : 0
                cum += (lv > 1 ? BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: lv - 1) : 0)

                let effect: String
                switch c.id {
                case "psu": effect = "\(BalanceConfig.Components.psuCapacity(at: lv))W"
                case "ram": effect = String(format: "%.2fx", Double(BalanceConfig.Components.ramEfficiencyRegen(at: lv)))
                case "gpu": effect = String(format: "%.3fx", Double(BalanceConfig.Components.gpuDamageMultiplier(at: lv)))
                case "cache": effect = String(format: "%.3fx", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: lv)))
                case "storage": effect = fNum(Double(BalanceConfig.Components.storageCapacity(at: lv)))
                case "expansion": effect = "+\(BalanceConfig.Components.expansionExtraSlots(at: lv))"
                case "network": effect = String(format: "%.3fx", Double(BalanceConfig.Components.networkHashMultiplier(at: lv)))
                case "io": effect = String(format: "%.2fx", Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: lv)))
                case "cpu": effect = String(format: "%.2f &#x210E;/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: lv)))
                default: effect = "-"
                }

                var row = "<tr><td>\(lv)</td>"
                row += "<td>\(lv < BalanceConfig.Components.maxLevel ? fNum(Double(cost)) : "MAX")</td>"
                row += "<td>\(fNum(Double(cum)))</td><td>\(effect)</td>"
                for r in rates {
                    if lv < BalanceConfig.Components.maxLevel {
                        row += timeTd(Double(cost), hps(r.level))
                    } else {
                        row += "<td>-</td>"
                    }
                }
                row += "</tr>"
                s += row
            }
            s += "</tbody></table>"
        }

        // Component ROI per level ("sweet spot" analysis)
        s += h3("Component ROI per Level (Sweet Spots)")
        s += note("Cost-effectiveness decreases at higher levels due to exponential costs with linear gains. Green = best value, Red = diminishing returns.")
        s += "<table>" + th(["Component", "Lv1&rarr;2", "Lv2&rarr;3", "Lv3&rarr;4", "Lv4&rarr;5", "Lv5&rarr;6", "Best Value"])
        s += "<tbody>"

        let roiComps: [(id: String, name: String)] = [
            ("psu", "PSU"), ("gpu", "GPU"), ("cache", "Cache"),
            ("cpu", "CPU"), ("network", "Network"), ("storage", "Storage"),
            ("ram", "RAM"), ("io", "I/O"), ("expansion", "Expansion")
        ]

        for c in roiComps {
            let base = BalanceConfig.Components.baseCost(for: c.id)
            var cells = [c.name]

            // Calculate effect gain per level for first 5 upgrades
            var bestLevel = 1
            var bestRatio = Double.infinity

            for lv in 1...5 {
                let cost = BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: lv)
                let gain: Double
                switch c.id {
                case "psu":
                    gain = Double(BalanceConfig.Components.psuCapacity(at: lv + 1) - BalanceConfig.Components.psuCapacity(at: lv))
                case "gpu":
                    gain = Double(BalanceConfig.Components.gpuDamageMultiplier(at: lv + 1) - BalanceConfig.Components.gpuDamageMultiplier(at: lv)) * 1000
                case "cache":
                    gain = Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: lv + 1) - BalanceConfig.Components.cacheAttackSpeedMultiplier(at: lv)) * 1000
                case "cpu":
                    gain = Double(BalanceConfig.Components.cpuHashPerSecond(at: lv + 1) - BalanceConfig.Components.cpuHashPerSecond(at: lv))
                case "network":
                    gain = Double(BalanceConfig.Components.networkHashMultiplier(at: lv + 1) - BalanceConfig.Components.networkHashMultiplier(at: lv)) * 1000
                case "storage":
                    gain = Double(BalanceConfig.Components.storageCapacity(at: lv + 1) - BalanceConfig.Components.storageCapacity(at: lv))
                case "ram":
                    gain = Double(BalanceConfig.Components.ramEfficiencyRegen(at: lv + 1) - BalanceConfig.Components.ramEfficiencyRegen(at: lv)) * 1000
                case "io":
                    gain = Double(BalanceConfig.Components.ioPickupRadiusMultiplier(at: lv + 1) - BalanceConfig.Components.ioPickupRadiusMultiplier(at: lv)) * 1000
                case "expansion":
                    gain = Double(BalanceConfig.Components.expansionExtraSlots(at: lv + 1) - BalanceConfig.Components.expansionExtraSlots(at: lv))
                default: gain = 1
                }
                let ratio = gain > 0 ? Double(cost) / gain : Double.infinity
                if ratio < bestRatio { bestRatio = ratio; bestLevel = lv }

                let cls = lv == 1 ? "t1" : (lv <= 3 ? "t2" : (lv <= 4 ? "t3" : "t4"))
                cells.append("<span class=\"\(cls)\">\(fNum(Double(cost)))</span>")
            }
            cells.append("Lv\(bestLevel)&rarr;\(bestLevel + 1)")
            s += "<tr>" + cells.map { "<td>\($0)</td>" }.joined() + "</tr>"
        }
        s += "</tbody></table>"

        return s
    }

    // MARK: - Towers

    static func towersHTML() -> String {
        var s = h2("Towers & Protocols")

        // Placement & Power
        s += h3("Placement Cost & Power Draw")
        s += "<table>" + th(["Rarity", "Place Cost", "Power Draw", "Refund (50%)", "Base Upgrade Cost"])
        s += "<tbody>"
        let rarities: [(Rarity, String)] = [(.common, "Common"), (.rare, "Rare"), (.epic, "Epic"), (.legendary, "Legendary")]
        for (r, name) in rarities {
            let cost = BalanceConfig.Towers.placementCosts[r] ?? 50
            let power = BalanceConfig.TowerPower.powerDraw(for: r)
            let refund = Int(Double(cost) * Double(BalanceConfig.Towers.refundRate))
            s += td([name, "\(cost) &#x210E;", "\(power)W", "\(refund) &#x210E;", "\(cost) &#x210E;"])
        }
        s += "</tbody></table>"

        // Upgrade costs by level
        s += h3("Tower Upgrade Costs by Level")
        s += note("Formula: baseCost &times; 2^(level-1)")
        s += "<table>" + th(["Level", "Common", "Rare", "Epic", "Legendary", "Time @ CPU 5 (Common)"])
        s += "<tbody>"
        var totals: [Rarity: Int] = [.common: 0, .rare: 0, .epic: 0, .legendary: 0]
        for lv in 1..<BalanceConfig.maxUpgradeLevel {
            var cells = ["\(lv) &rarr; \(lv+1)"]
            for (r, _) in rarities {
                let cost = BalanceConfig.exponentialUpgradeCost(baseCost: BalanceConfig.Towers.placementCosts[r] ?? 50, currentLevel: lv)
                totals[r]! += cost
                cells.append(fNum(Double(cost)))
            }
            let cCost = BalanceConfig.exponentialUpgradeCost(baseCost: BalanceConfig.Towers.placementCosts[.common] ?? 50, currentLevel: lv)
            s += "<tr>" + cells.map { "<td>\($0)</td>" }.joined() + timeTd(Double(cCost), hps(5)) + "</tr>"
        }
        // Totals row
        s += "<tr class=\"totals\"><td><strong>TOTAL</strong></td>"
        for (r, _) in rarities { s += "<td><strong>\(fNum(Double(totals[r]!)))</strong></td>" }
        s += "<td></td></tr>"
        s += "</tbody></table>"

        // Stat scaling
        s += h3("Tower Stat Scaling per Level")
        s += "<table>" + th(["Level", "Damage &times;", "Range &times;", "Atk Speed &times;", "Combined DPS &times;"])
        s += "<tbody>"
        let dmgM = Double(BalanceConfig.TowerUpgrades.damageMultiplier)
        let rngM = Double(BalanceConfig.TowerUpgrades.rangeMultiplier)
        let asM = Double(BalanceConfig.TowerUpgrades.attackSpeedMultiplier)
        for lv in 1...BalanceConfig.maxUpgradeLevel {
            let dmg = pow(dmgM, Double(lv - 1))
            let rng = pow(rngM, Double(lv - 1))
            let atk = pow(asM, Double(lv - 1))
            let dps = dmg * atk  // DPS = damage * attack_speed
            s += td(["\(lv)", String(format: "%.2f", dmg), String(format: "%.2f", rng),
                      String(format: "%.2f", atk), String(format: "%.2f", dps)])
        }
        s += "</tbody></table>"

        // Per-protocol base stats (Firewall)
        typealias PBS = BalanceConfig.ProtocolBaseStats
        s += h3("Per-Protocol Base Stats (Firewall Mode)")
        s += note("Level 1 values before scaling. DPS = Damage &times; FireRate &times; ProjectileCount")
        s += "<table>" + th(["Protocol", "Rarity", "DMG", "Range", "Rate", "Proj", "Pierce", "Splash", "Slow", "Power", "DPS"])
        s += "<tbody>"

        let fwProtos: [(String, String, CGFloat, CGFloat, CGFloat, Int, Int, CGFloat, CGFloat, Int)] = [
            ("Kernel Pulse", "Common", PBS.KernelPulse.firewallDamage, PBS.KernelPulse.firewallRange, PBS.KernelPulse.firewallFireRate, PBS.KernelPulse.firewallProjectileCount, PBS.KernelPulse.firewallPierce, PBS.KernelPulse.firewallSplash, PBS.KernelPulse.firewallSlow, PBS.KernelPulse.firewallPowerDraw),
            ("Burst Protocol", "Common", PBS.BurstProtocol.firewallDamage, PBS.BurstProtocol.firewallRange, PBS.BurstProtocol.firewallFireRate, PBS.BurstProtocol.firewallProjectileCount, PBS.BurstProtocol.firewallPierce, PBS.BurstProtocol.firewallSplash, PBS.BurstProtocol.firewallSlow, PBS.BurstProtocol.firewallPowerDraw),
            ("Trace Route", "Rare", PBS.TraceRoute.firewallDamage, PBS.TraceRoute.firewallRange, PBS.TraceRoute.firewallFireRate, PBS.TraceRoute.firewallProjectileCount, PBS.TraceRoute.firewallPierce, PBS.TraceRoute.firewallSplash, PBS.TraceRoute.firewallSlow, PBS.TraceRoute.firewallPowerDraw),
            ("Ice Shard", "Rare", PBS.IceShard.firewallDamage, PBS.IceShard.firewallRange, PBS.IceShard.firewallFireRate, PBS.IceShard.firewallProjectileCount, PBS.IceShard.firewallPierce, PBS.IceShard.firewallSplash, PBS.IceShard.firewallSlow, PBS.IceShard.firewallPowerDraw),
            ("Fork Bomb", "Epic", PBS.ForkBomb.firewallDamage, PBS.ForkBomb.firewallRange, PBS.ForkBomb.firewallFireRate, PBS.ForkBomb.firewallProjectileCount, PBS.ForkBomb.firewallPierce, PBS.ForkBomb.firewallSplash, PBS.ForkBomb.firewallSlow, PBS.ForkBomb.firewallPowerDraw),
            ("Root Access", "Epic", PBS.RootAccess.firewallDamage, PBS.RootAccess.firewallRange, PBS.RootAccess.firewallFireRate, PBS.RootAccess.firewallProjectileCount, PBS.RootAccess.firewallPierce, PBS.RootAccess.firewallSplash, PBS.RootAccess.firewallSlow, PBS.RootAccess.firewallPowerDraw),
            ("Overflow", "Legendary", PBS.Overflow.firewallDamage, PBS.Overflow.firewallRange, PBS.Overflow.firewallFireRate, PBS.Overflow.firewallProjectileCount, PBS.Overflow.firewallPierce, PBS.Overflow.firewallSplash, PBS.Overflow.firewallSlow, PBS.Overflow.firewallPowerDraw),
            ("Null Pointer", "Legendary", PBS.NullPointer.firewallDamage, PBS.NullPointer.firewallRange, PBS.NullPointer.firewallFireRate, PBS.NullPointer.firewallProjectileCount, PBS.NullPointer.firewallPierce, PBS.NullPointer.firewallSplash, PBS.NullPointer.firewallSlow, PBS.NullPointer.firewallPowerDraw),
        ]

        for (name, rarity, dmg, rng, rate, proj, pierce, splash, slow, power) in fwProtos {
            let dps = dmg * rate * CGFloat(proj)
            let slowStr = slow > 0 ? pct(Double(slow)) : "-"
            let splashStr = splash > 0 ? fNum(Double(splash)) : "-"
            s += td([name, rarity, fNum(Double(dmg)), fNum(Double(rng)), String(format: "%.1f", Double(rate)),
                      "\(proj)", "\(pierce)", splashStr, slowStr, "\(power)W", String(format: "%.1f", Double(dps))])
        }
        s += "</tbody></table>"

        // Per-protocol base stats (Weapon)
        s += h3("Per-Protocol Base Stats (Weapon Mode)")
        s += note("Used in Boss/Debug mode. DPS = Damage &times; FireRate &times; ProjectileCount")
        s += "<table>" + th(["Protocol", "DMG", "Rate", "Proj Count", "Spread", "Pierce", "Proj Speed", "DPS"])
        s += "<tbody>"

        let wpProtos: [(String, CGFloat, CGFloat, Int, CGFloat, Int, CGFloat)] = [
            ("Kernel Pulse", PBS.KernelPulse.weaponDamage, PBS.KernelPulse.weaponFireRate, PBS.KernelPulse.weaponProjectileCount, PBS.KernelPulse.weaponSpread, PBS.KernelPulse.weaponPierce, PBS.KernelPulse.weaponProjectileSpeed),
            ("Burst Protocol", PBS.BurstProtocol.weaponDamage, PBS.BurstProtocol.weaponFireRate, PBS.BurstProtocol.weaponProjectileCount, PBS.BurstProtocol.weaponSpread, PBS.BurstProtocol.weaponPierce, PBS.BurstProtocol.weaponProjectileSpeed),
            ("Trace Route", PBS.TraceRoute.weaponDamage, PBS.TraceRoute.weaponFireRate, PBS.TraceRoute.weaponProjectileCount, PBS.TraceRoute.weaponSpread, PBS.TraceRoute.weaponPierce, PBS.TraceRoute.weaponProjectileSpeed),
            ("Ice Shard", PBS.IceShard.weaponDamage, PBS.IceShard.weaponFireRate, PBS.IceShard.weaponProjectileCount, PBS.IceShard.weaponSpread, PBS.IceShard.weaponPierce, PBS.IceShard.weaponProjectileSpeed),
            ("Fork Bomb", PBS.ForkBomb.weaponDamage, PBS.ForkBomb.weaponFireRate, PBS.ForkBomb.weaponProjectileCount, PBS.ForkBomb.weaponSpread, PBS.ForkBomb.weaponPierce, PBS.ForkBomb.weaponProjectileSpeed),
            ("Root Access", PBS.RootAccess.weaponDamage, PBS.RootAccess.weaponFireRate, PBS.RootAccess.weaponProjectileCount, PBS.RootAccess.weaponSpread, PBS.RootAccess.weaponPierce, PBS.RootAccess.weaponProjectileSpeed),
            ("Overflow", PBS.Overflow.weaponDamage, PBS.Overflow.weaponFireRate, PBS.Overflow.weaponProjectileCount, PBS.Overflow.weaponSpread, PBS.Overflow.weaponPierce, PBS.Overflow.weaponProjectileSpeed),
            ("Null Pointer", PBS.NullPointer.weaponDamage, PBS.NullPointer.weaponFireRate, PBS.NullPointer.weaponProjectileCount, PBS.NullPointer.weaponSpread, PBS.NullPointer.weaponPierce, PBS.NullPointer.weaponProjectileSpeed),
        ]

        for (name, dmg, rate, proj, spread, pierce, speed) in wpProtos {
            let dps = dmg * rate * CGFloat(proj)
            s += td([name, fNum(Double(dmg)), String(format: "%.1f", Double(rate)), "\(proj)",
                      String(format: "%.1f", Double(spread)), "\(pierce)", fNum(Double(speed)),
                      String(format: "%.1f", Double(dps))])
        }
        s += "</tbody></table>"

        // Compile & upgrade costs
        s += h3("Protocol Compile & Upgrade Costs")
        s += "<table>" + th(["Protocol", "Rarity", "Compile Cost", "Base Upgrade", "Total to Max", "Time @ CPU 5"])
        s += "<tbody>"

        let costProtos: [(String, String, Int, Int)] = [
            ("Kernel Pulse", "Common", PBS.KernelPulse.compileCost, PBS.KernelPulse.baseUpgradeCost),
            ("Burst Protocol", "Common", PBS.BurstProtocol.compileCost, PBS.BurstProtocol.baseUpgradeCost),
            ("Trace Route", "Rare", PBS.TraceRoute.compileCost, PBS.TraceRoute.baseUpgradeCost),
            ("Ice Shard", "Rare", PBS.IceShard.compileCost, PBS.IceShard.baseUpgradeCost),
            ("Fork Bomb", "Epic", PBS.ForkBomb.compileCost, PBS.ForkBomb.baseUpgradeCost),
            ("Root Access", "Epic", PBS.RootAccess.compileCost, PBS.RootAccess.baseUpgradeCost),
            ("Overflow", "Legendary", PBS.Overflow.compileCost, PBS.Overflow.baseUpgradeCost),
            ("Null Pointer", "Legendary", PBS.NullPointer.compileCost, PBS.NullPointer.baseUpgradeCost),
        ]

        for (name, rarity, compile, baseUpgrade) in costProtos {
            var total = compile
            for lv in 1..<BalanceConfig.maxUpgradeLevel {
                total += BalanceConfig.exponentialUpgradeCost(baseCost: baseUpgrade, currentLevel: lv)
            }
            s += "<tr><td>\(name)</td><td>\(rarity)</td><td>\(compile > 0 ? fNum(Double(compile)) + " &#x210E;" : "FREE")</td>"
            s += "<td>\(fNum(Double(baseUpgrade))) &#x210E;</td><td>\(fNum(Double(total))) &#x210E;</td>"
            s += timeTd(Double(total), hps(5)) + "</tr>"
        }
        s += "</tbody></table>"

        // Protocol abilities
        s += h3("Protocol Special Abilities")
        s += "<table>" + th(["Protocol", "Effect", "Value", "Duration", "Notes"])
        s += "<tbody>"
        s += td(["Throttler (Ice Shard)", "Slow", "\(pct(Double(BalanceConfig.Throttler.slowAmount)))",
                  "\(BalanceConfig.Throttler.slowDuration)s",
                  "\(pct(Double(BalanceConfig.Throttler.stunChance))) stun chance (\(BalanceConfig.Throttler.stunDuration)s)"])
        s += td(["Pinger (Trace Route)", "Tag for bonus dmg", "+\(pct(Double(BalanceConfig.Pinger.tagDamageBonus)))",
                  "\(BalanceConfig.Pinger.tagDuration)s", "All sources deal bonus damage"])
        s += td(["Garbage Collector (Null Ptr)", "Mark for hash", "+\(BalanceConfig.GarbageCollector.hashBonus) &#x210E;",
                  "\(BalanceConfig.GarbageCollector.markDuration)s", "Bonus hash on marked kill"])
        s += td(["Fragmenter (Burst Proto)", "Burn DoT",
                  "\(pct(Double(BalanceConfig.Fragmenter.burnDamagePercent))) of hit",
                  "\(BalanceConfig.Fragmenter.burnDuration)s",
                  "Ticks every \(BalanceConfig.Fragmenter.burnTickInterval)s"])
        s += td(["Recursion (Fork Bomb)", "Split projectiles", "\(BalanceConfig.Recursion.childCount) children",
                  "-", "Child dmg: \(pct(Double(BalanceConfig.Recursion.childDamagePercent))) of parent"])
        s += "</tbody></table>"

        return s
    }

    // MARK: - Bosses

    static func bossesHTML() -> String {
        var s = h2("Boss Fights")

        // Boss overview
        s += h3("Boss Overview")
        s += "<table>" + th(["Boss", "Base HP", "Phase 2", "Phase 3", "Phase 4", "Signature Mechanic"])
        s += "<tbody>"
        s += td(["Cyberboss", fNum(Double(BalanceConfig.Cyberboss.baseHealth)),
                  "\(pct(Double(BalanceConfig.Cyberboss.phase2Threshold))) HP",
                  "\(pct(Double(BalanceConfig.Cyberboss.phase3Threshold))) HP",
                  "\(pct(Double(BalanceConfig.Cyberboss.phase4Threshold))) HP",
                  "Laser beams + acid puddles"])
        s += td(["Void Harbinger", fNum(Double(BalanceConfig.VoidHarbinger.baseHealth)),
                  "\(pct(Double(BalanceConfig.VoidHarbinger.phase2Threshold))) HP",
                  "\(pct(Double(BalanceConfig.VoidHarbinger.phase3Threshold))) HP",
                  "\(pct(Double(BalanceConfig.VoidHarbinger.phase4Threshold))) HP",
                  "Void zones + shrinking arena"])
        s += td(["Overclocker", fNum(Double(BalanceConfig.Overclocker.baseHealth)),
                  "\(pct(Double(BalanceConfig.Overclocker.phase2Threshold))) HP",
                  "\(pct(Double(BalanceConfig.Overclocker.phase3Threshold))) HP",
                  "\(pct(Double(BalanceConfig.Overclocker.phase4Threshold))) HP",
                  "Lava grid + suction"])
        s += td(["Trojan Wyrm", fNum(Double(BalanceConfig.TrojanWyrm.baseHealth)),
                  "\(pct(Double(BalanceConfig.TrojanWyrm.phase2Threshold))) HP",
                  "\(pct(Double(BalanceConfig.TrojanWyrm.phase3Threshold))) HP",
                  "\(pct(Double(BalanceConfig.TrojanWyrm.phase4Threshold))) HP",
                  "Snake body + sub-worms"])
        s += "</tbody></table>"

        // Difficulty scaling
        s += h3("Difficulty Scaling")
        s += "<table>" + th(["Difficulty", "Boss HP &times;", "Boss DMG &times;", "Player HP &times;",
                              "Player DMG &times;", "Hash Reward", "Boss Hash Bonus", "Threat Reduction"])
        s += "<tbody>"
        let diffs: [(String, BossDifficulty)] = [("Easy", .easy), ("Normal", .normal), ("Hard", .hard), ("Nightmare", .nightmare)]
        for (name, diff) in diffs {
            let bHP = BalanceConfig.BossDifficultyConfig.healthMultipliers[name] ?? 1
            let bDMG = BalanceConfig.BossDifficultyConfig.damageMultipliers[name] ?? 1
            let pHP = BalanceConfig.BossDifficultyConfig.playerHealthMultipliers[name] ?? 1
            let pDMG = BalanceConfig.BossDifficultyConfig.playerDamageMultipliers[name] ?? 1
            let hash = BalanceConfig.BossDifficultyConfig.hashRewards[name] ?? 0
            let bonus = BalanceConfig.BossRewards.difficultyHashBonus[diff] ?? 0
            let threatReduction = BalanceConfig.TDBoss.threatReduction[name] ?? 0
            s += td([name, "\(Double(bHP))x", "\(Double(bDMG))x", "\(Double(pHP))x",
                      "\(Double(pDMG))x", "\(fNum(Double(hash))) &#x210E;",
                      "\(fNum(Double(bonus))) &#x210E;", pct(Double(threatReduction))])
        }
        s += "</tbody></table>"

        // TD Boss milestones
        s += h3("TD Boss Spawn Milestones")
        s += note("Bosses spawn every \(BalanceConfig.TDBoss.threatMilestoneInterval) threat levels. Immune to towers, player must engage manually. After victory, \(Int(BalanceConfig.TDBoss.cooldownAfterVictory))s cooldown before next boss can spawn.")
        s += "<table>" + th(["Parameter", "Value"])
        s += "<tbody>"
        s += td(["Spawn Interval", "Every \(BalanceConfig.TDBoss.threatMilestoneInterval) threat"])
        s += td(["Post-Victory Cooldown", "\(Int(BalanceConfig.TDBoss.cooldownAfterVictory))s"])
        s += td(["Walk Speed", "\(Int(Double(BalanceConfig.TDBoss.walkSpeed)))"])
        s += td(["Path Duration", "\(Int(BalanceConfig.TDBoss.pathDuration))s"])
        s += td(["Efficiency Loss (ignored)", "\(BalanceConfig.TDBoss.efficiencyLossOnIgnore) leaks"])
        s += "</tbody></table>"

        return s
    }

    // MARK: - Loot

    static func lootHTML() -> String {
        var s = h2("Loot & Drop System")

        // Per-difficulty drop rates
        s += h3("Blueprint Drop Rates by Difficulty")
        let lootRarities: [(Rarity, String)] = [(.common, "Common"), (.rare, "Rare"), (.epic, "Epic"), (.legendary, "Legendary")]
        s += "<table>" + th(["Rarity", "Easy", "Normal", "Hard", "Nightmare"])
        s += "<tbody>"
        for (r, name) in lootRarities {
            let easy = BalanceConfig.BossLoot.dropRates["Easy"]?[r] ?? 0
            let normal = BalanceConfig.BossLoot.dropRates["Normal"]?[r] ?? 0
            let hard = BalanceConfig.BossLoot.dropRates["Hard"]?[r] ?? 0
            let nightmare = BalanceConfig.BossLoot.dropRates["Nightmare"]?[r] ?? 0
            s += td([name, pct(easy), pct(normal), pct(hard), pct(nightmare)])
        }
        // Totals row
        let easyTotal = lootRarities.reduce(0.0) { $0 + (BalanceConfig.BossLoot.dropRates["Easy"]?[$1.0] ?? 0) }
        let normalTotal = lootRarities.reduce(0.0) { $0 + (BalanceConfig.BossLoot.dropRates["Normal"]?[$1.0] ?? 0) }
        let hardTotal = lootRarities.reduce(0.0) { $0 + (BalanceConfig.BossLoot.dropRates["Hard"]?[$1.0] ?? 0) }
        let nightmareTotal = lootRarities.reduce(0.0) { $0 + (BalanceConfig.BossLoot.dropRates["Nightmare"]?[$1.0] ?? 0) }
        s += "<tr style=\"font-weight:bold\"><td>Total</td><td>\(pct(easyTotal))</td><td>\(pct(normalTotal))</td><td>\(pct(hardTotal))</td><td>\(pct(nightmareTotal))</td></tr>"
        s += "</tbody></table>"
        s += note("Pity system: guaranteed drop every \(BalanceConfig.BossLoot.pityThreshold) kills without a drop. Diminishing factor: \(BalanceConfig.BossLoot.diminishingFactor).")

        // Boss loot tables
        s += h3("Boss Loot Tables")
        s += "<table>" + th(["Boss", "Protocol", "Weight", "First Kill Guaranteed"])
        s += "<tbody>"
        for table in BalanceConfig.BossLoot.all {
            let bossName = BalanceConfig.BossLoot.bossDisplayName(table.bossId)
            for (i, entry) in table.entries.enumerated() {
                s += td([i == 0 ? bossName : "", entry.protocolId.replacingOccurrences(of: "_", with: " ").capitalized,
                          "\(entry.weight)", entry.isFirstKillGuarantee ? "Yes" : "No"])
            }
        }
        s += "</tbody></table>"

        // XP per enemy
        s += h3("XP per Enemy Type")
        s += "<table>" + th(["Enemy Type", "XP Value"])
        s += "<tbody>"
        s += td(["Basic", "\(BalanceConfig.XPSystem.basicEnemyXP)"])
        s += td(["Fast", "\(BalanceConfig.XPSystem.fastEnemyXP)"])
        s += td(["Tank", "\(BalanceConfig.XPSystem.tankEnemyXP)"])
        s += td(["Boss (mini)", "\(BalanceConfig.XPSystem.bossEnemyXP)"])
        s += td(["Cyberboss", "\(BalanceConfig.XPSystem.cyberbossXP)"])
        s += td(["Void Harbinger", "\(BalanceConfig.XPSystem.voidHarbingerXP)"])
        s += "</tbody></table>"

        // Loot box tiers
        s += h3("Loot Box Tier Weights")
        s += "<table>" + th(["Tier", "XP Threshold", "Common", "Rare", "Epic", "Legendary"])
        s += "<tbody>"
        s += td(["Wooden", "&lt; \(pct(Double(BalanceConfig.XPSystem.tier1Threshold)))",
                  "\(Int(BalanceConfig.XPSystem.woodenCommonWeight))", "\(Int(BalanceConfig.XPSystem.woodenRareWeight))",
                  "\(Int(BalanceConfig.XPSystem.woodenEpicWeight))", "\(Int(BalanceConfig.XPSystem.woodenLegendaryWeight))"])
        s += td(["Silver", "\(pct(Double(BalanceConfig.XPSystem.tier1Threshold))) - \(pct(Double(BalanceConfig.XPSystem.tier2Threshold)))",
                  "\(Int(BalanceConfig.XPSystem.silverCommonWeight))", "\(Int(BalanceConfig.XPSystem.silverRareWeight))",
                  "\(Int(BalanceConfig.XPSystem.silverEpicWeight))", "\(Int(BalanceConfig.XPSystem.silverLegendaryWeight))"])
        s += td(["Golden", "&ge; \(pct(Double(BalanceConfig.XPSystem.tier2Threshold)))",
                  "\(Int(BalanceConfig.XPSystem.goldenCommonWeight))", "\(Int(BalanceConfig.XPSystem.goldenRareWeight))",
                  "\(Int(BalanceConfig.XPSystem.goldenEpicWeight))", "\(Int(BalanceConfig.XPSystem.goldenLegendaryWeight))"])
        s += "</tbody></table>"

        // Weapon leveling
        s += h3("Weapon Mastery Leveling")
        s += note("XP required: \(BalanceConfig.Leveling.baseXPRequired) + (level-1) &times; \(BalanceConfig.Leveling.xpPerLevel). Max level: \(BalanceConfig.Leveling.maxWeaponLevel)")
        s += "<table>" + th(["Level", "XP Required", "Cumulative XP", "Damage Multiplier"])
        s += "<tbody>"
        var cumXP = 0
        for lv in 1...BalanceConfig.Leveling.maxWeaponLevel {
            let xp = BalanceConfig.xpRequired(level: lv)
            cumXP += xp
            let dmg = Double(BalanceConfig.levelStatMultiplier(level: lv))
            s += td(["\(lv)", "\(xp)", "\(cumXP)", String(format: "%.2fx", dmg)])
        }
        s += "</tbody></table>"

        return s
    }

    // MARK: - Scaling

    static func scalingHTML() -> String {
        var s = h2("Threat & Wave Scaling")

        // Threat level milestones
        s += h3("Threat Level &mdash; Enemy Unlocks")
        s += note("Online growth: \(Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate))/sec, Offline: \(Double(BalanceConfig.ThreatLevel.offlineThreatGrowthRate))/sec, Max: \(Int(Double(BalanceConfig.ThreatLevel.maxThreatLevel)))")
        s += "<table>" + th(["Enemy Type", "Unlock Threat", "Time to Unlock", "HP &times;", "Speed &times;", "DMG &times;"])
        s += "<tbody>"
        let onlineRate = Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate)
        let hpS = Double(BalanceConfig.ThreatLevel.healthScaling)
        let spdS = Double(BalanceConfig.ThreatLevel.speedScaling)
        let dmgS = Double(BalanceConfig.ThreatLevel.damageScaling)

        let enemies: [(String, Double)] = [
            ("Basic", 0), ("Fast", Double(BalanceConfig.ThreatLevel.fastEnemyThreshold)),
            ("Swarm", Double(BalanceConfig.ThreatLevel.swarmEnemyThreshold)),
            ("Tank", Double(BalanceConfig.ThreatLevel.tankEnemyThreshold)),
            ("Elite", Double(BalanceConfig.ThreatLevel.eliteEnemyThreshold)),
            ("Mini-Boss", Double(BalanceConfig.ThreatLevel.bossEnemyThreshold))
        ]
        for (name, thr) in enemies {
            let time = thr > 0 ? thr / onlineRate : 0
            let hp = thr > 1 ? 1 + (thr - 1) * hpS : 1.0
            let spd = thr > 1 ? 1 + (thr - 1) * spdS : 1.0
            let dmg = thr > 1 ? 1 + (thr - 1) * dmgS : 1.0
            s += td([name, thr > 0 ? String(format: "%.1f", thr) : "Start",
                      thr > 0 ? fTime(time) : "-",
                      String(format: "%.2fx", hp), String(format: "%.2fx", spd), String(format: "%.2fx", dmg)])
        }
        s += "</tbody></table>"

        // Threat progression table
        s += h3("Threat Level Stat Scaling (every 10 levels)")
        s += "<table>" + th(["Threat", "HP &times;", "Speed &times;", "DMG &times;", "Time Online"])
        s += "<tbody>"
        for thr in stride(from: 10, through: Int(Double(BalanceConfig.ThreatLevel.maxThreatLevel)), by: 10) {
            let t = Double(thr)
            s += td(["\(thr)", String(format: "%.1fx", 1 + (t-1) * hpS),
                      String(format: "%.2fx", 1 + (t-1) * spdS),
                      String(format: "%.1fx", 1 + (t-1) * dmgS),
                      fTime(t / onlineRate)])
        }
        s += "</tbody></table>"

        // Wave scaling (TD mode)
        s += h3("Wave Scaling (TD Mode)")
        s += note("HP: +\(Int(Double(BalanceConfig.Waves.healthScalingPerWave)*100))%/wave, Speed: +\(Int(Double(BalanceConfig.Waves.speedScalingPerWave)*100))%/wave, Boss every \(BalanceConfig.Waves.bossWaveInterval) waves")
        s += "<table>" + th(["Wave", "HP &times;", "Speed &times;", "Enemies", "Spawn Delay", "Hash Bonus", "Cumul. Hash", "Composition"])
        s += "<tbody>"
        var cumHash = 0
        for w in 1...BalanceConfig.TDSession.totalWaves {
            let hpM = 1.0 + Double(w - 1) * Double(BalanceConfig.Waves.healthScalingPerWave)
            let spdM = 1.0 + Double(w - 1) * Double(BalanceConfig.Waves.speedScalingPerWave)
            let count = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
            let delay = max(Double(BalanceConfig.Waves.minSpawnDelay),
                           Double(BalanceConfig.Waves.baseSpawnDelay) - Double(w) * Double(BalanceConfig.Waves.spawnDelayReductionPerWave))
            let bonus = w * BalanceConfig.Waves.hashBonusPerWave
            cumHash += bonus
            let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0

            let comp: String
            if w <= BalanceConfig.Waves.earlyWaveMax { comp = "Basic only" }
            else if w <= BalanceConfig.Waves.midEarlyWaveMax { comp = "Basic + Fast" }
            else if w <= BalanceConfig.Waves.midWaveMax { comp = "Basic + Fast + Tank" }
            else { comp = "All types" }

            s += td([isBoss ? "<strong>\(w) (BOSS)</strong>" : "\(w)",
                      String(format: "%.2f", hpM), String(format: "%.2f", spdM),
                      "\(count)", String(format: "%.2fs", delay),
                      "\(bonus) &#x210E;", "\(cumHash) &#x210E;", comp])
        }
        s += "</tbody></table>"

        // DPS Requirements per wave
        let baseHP = BalanceConfig.EnemyDefaults.health
        let dmgMult = Double(BalanceConfig.TowerUpgrades.damageMultiplier)
        let asMult = Double(BalanceConfig.TowerUpgrades.attackSpeedMultiplier)
        typealias PBS = BalanceConfig.ProtocolBaseStats
        let kpBaseDPS = Double(PBS.KernelPulse.firewallDamage * PBS.KernelPulse.firewallFireRate)

        s += h3("Wave DPS Requirements")
        s += note("Total wave HP / wave duration. Compare against tower DPS (Kernel Pulse shown as reference).")
        s += "<table>" + th(["Wave", "Total HP", "Duration", "DPS Required", "3&times; KP Lv1", "3&times; KP Lv5", "3&times; KP Lv10", "Verdict"])
        s += "<tbody>"
        for w in 1...BalanceConfig.TDSession.totalWaves {
            let hpM = 1.0 + Double(w - 1) * Double(BalanceConfig.Waves.healthScalingPerWave)
            let count = BalanceConfig.Waves.baseEnemyCount + w * BalanceConfig.Waves.enemiesPerWave
            let delay = max(Double(BalanceConfig.Waves.minSpawnDelay),
                           Double(BalanceConfig.Waves.baseSpawnDelay) - Double(w) * Double(BalanceConfig.Waves.spawnDelayReductionPerWave))
            let isBoss = w % BalanceConfig.Waves.bossWaveInterval == 0
            var totalHP = Double(count) * baseHP * hpM
            if isBoss { totalHP += baseHP * hpM * Double(BalanceConfig.Waves.bossHealthMultiplier) }
            let waveDur = delay * Double(count)
            let dpsReq = totalHP / waveDur
            let kp1 = kpBaseDPS * 3
            let kp5 = kpBaseDPS * 3 * pow(dmgMult, 4) * pow(asMult, 4)
            let kp10 = kpBaseDPS * 3 * pow(dmgMult, 9) * pow(asMult, 9)
            let verdict = kp1 >= dpsReq ? "OK" : (kp5 >= dpsReq ? "Lv5+" : "Lv10+")
            let verdictClass = kp1 >= dpsReq ? "t1" : (kp5 >= dpsReq ? "t3" : "t5")
            s += "<tr><td>\(isBoss ? "<strong>\(w)</strong>" : "\(w)")</td><td>\(fNum(totalHP))</td>"
            s += "<td>\(fTime(waveDur))</td><td>\(String(format: "%.1f", dpsReq))</td>"
            s += "<td>\(String(format: "%.1f", kp1))</td><td>\(String(format: "%.1f", kp5))</td>"
            s += "<td>\(String(format: "%.1f", kp10))</td>"
            s += "<td class=\"\(verdictClass)\">\(verdict)</td></tr>"
        }
        s += "</tbody></table>"

        return s
    }

    // MARK: - Sectors

    static func sectorsHTML() -> String {
        var s = h2("Sector Progression")

        s += h3("Sector Unlock Costs & Bonuses")
        var headers = ["#", "Sector", "Unlock Cost", "Cumulative", "Hash Bonus"]
        for r in rates { headers.append("Time @ \(r.label)") }
        s += "<table>" + th(headers) + "<tbody>"

        var cum = 0
        for (i, sector) in BalanceConfig.SectorUnlock.unlockOrder.enumerated() {
            let cost = i < BalanceConfig.SectorUnlock.hashCosts.count ? BalanceConfig.SectorUnlock.hashCosts[i] : 0
            cum += cost
            let bonus = Double(BalanceConfig.SectorHashBonus.multiplier(for: sector))

            var row = "<tr><td>\(i)</td><td>\(sector.uppercased())</td>"
            row += "<td>\(cost > 0 ? fNum(Double(cost)) + " &#x210E;" : "FREE")</td>"
            row += "<td>\(fNum(Double(cum))) &#x210E;</td>"
            row += "<td>\(String(format: "%.1f", bonus))x</td>"
            for r in rates {
                row += cost > 0 ? timeTd(Double(cost), hps(r.level)) : "<td>-</td>"
            }
            row += "</tr>"
            s += row
        }
        s += "</tbody></table>"
        s += note("Total unlock cost: \(fNum(Double(BalanceConfig.SectorUnlock.totalUnlockCost))) &#x210E;")

        return s
    }

    // MARK: - Analysis

    static func analysisHTML() -> String {
        var s = h2("Cross-System Analysis")

        // Time to afford tower upgrades
        s += h3("Time to Afford Tower Upgrades (Common Rarity)")
        s += note("Shows how long each upgrade takes at different income levels")
        let commonBase = BalanceConfig.Towers.placementCosts[.common] ?? 50
        s += "<table>" + th(["Upgrade", "Cost", "Time @ CPU 1", "Time @ CPU 3", "Time @ CPU 5", "Time @ CPU 10"])
        s += "<tbody>"
        for lv in 1..<BalanceConfig.maxUpgradeLevel {
            let cost = BalanceConfig.exponentialUpgradeCost(baseCost: commonBase, currentLevel: lv)
            s += "<tr><td>Lv\(lv) &rarr; Lv\(lv+1)</td><td>\(fNum(Double(cost)))</td>"
            for cpuLv in [1, 3, 5, 10] {
                s += timeTd(Double(cost), hps(cpuLv))
            }
            s += "</tr>"
        }
        s += "</tbody></table>"

        // Component ROI
        s += h3("Component Upgrade ROI (first upgrade)")
        s += note("Cost of level 1&rarr;2 vs the benefit gained. Lower cost-per-benefit = better ROI.")
        s += "<table>" + th(["Component", "Lv1&rarr;2 Cost", "Benefit Gained", "Time @ CPU 5"])
        s += "<tbody>"
        let compROI: [(String, Int, String)] = [
            ("PSU", BalanceConfig.Components.psuBaseCost,
             "+\(BalanceConfig.Components.psuCapacity(at: 2) - BalanceConfig.Components.psuCapacity(at: 1))W"),
            ("RAM", BalanceConfig.Components.ramBaseCost,
             String(format: "+%.2fx recovery", Double(BalanceConfig.Components.ramEfficiencyRegen(at: 2) - BalanceConfig.Components.ramEfficiencyRegen(at: 1)))),
            ("GPU", BalanceConfig.Components.gpuBaseCost,
             String(format: "+%.3fx tower dmg", Double(BalanceConfig.Components.gpuDamageMultiplier(at: 2) - BalanceConfig.Components.gpuDamageMultiplier(at: 1)))),
            ("Cache", BalanceConfig.Components.cacheBaseCost,
             String(format: "+%.3fx atk speed", Double(BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 2) - BalanceConfig.Components.cacheAttackSpeedMultiplier(at: 1)))),
            ("Storage", BalanceConfig.Components.storageBaseCost,
             "+\(fNum(Double(BalanceConfig.Components.storageCapacity(at: 2) - BalanceConfig.Components.storageCapacity(at: 1)))) cap"),
            ("Network", BalanceConfig.Components.networkBaseCost,
             String(format: "+%.3fx hash", Double(BalanceConfig.Components.networkHashMultiplier(at: 2) - BalanceConfig.Components.networkHashMultiplier(at: 1)))),
            ("CPU", BalanceConfig.Components.cpuBaseCost,
             String(format: "+%.2f &#x210E;/s", Double(BalanceConfig.Components.cpuHashPerSecond(at: 2) - BalanceConfig.Components.cpuHashPerSecond(at: 1))))
        ]
        for (name, cost, benefit) in compROI {
            s += "<tr><td>\(name)</td><td>\(fNum(Double(cost)))</td><td>\(benefit)</td>"
            s += timeTd(Double(cost), hps(5))
            s += "</tr>"
        }
        s += "</tbody></table>"

        // Key balance checkpoints
        s += h3("Key Balance Checkpoints")
        s += "<table>" + th(["Checkpoint", "Value", "Implication"])
        s += "<tbody>"

        let hash5min = hps(1) * 300
        let epicCost = Double(BalanceConfig.Towers.placementCosts[.epic] ?? 200)
        s += td(["Hash in 5min (CPU 1)", "\(fNum(hash5min)) &#x210E;",
                  hash5min >= epicCost ? "Can afford epic tower" : "Cannot afford epic tower"])

        let timeToBoss = Double(BalanceConfig.ThreatLevel.bossEnemyThreshold) / onlineRate
        s += td(["Time to first mini-boss", fTime(timeToBoss),
                  "Player earns \(fNum(hps(1) * timeToBoss)) &#x210E; by then"])

        let maxPower = BalanceConfig.Components.psuCapacity(at: 10)
        let legPower = BalanceConfig.TowerPower.powerDraw(for: .legendary)
        s += td(["Max legendary towers (PSU 10)", "\(maxPower / legPower)",
                  "\(maxPower)W budget / \(legPower)W each"])

        let totalSectorCost = Double(BalanceConfig.SectorUnlock.totalUnlockCost)
        s += td(["Time to unlock all sectors (CPU 5)", fTime(totalSectorCost / hps(5)),
                  "Total: \(fNum(totalSectorCost)) &#x210E;"])

        let commonMaxCost = Double(totals(for: .common))
        s += td(["Time to max common tower (CPU 1)", fTime(commonMaxCost / hps(1)),
                  "Total: \(fNum(commonMaxCost)) &#x210E;"])

        let legendaryMaxCost = Double(totals(for: .legendary))
        s += td(["Time to max legendary tower (CPU 5)", fTime(legendaryMaxCost / hps(5)),
                  "Total: \(fNum(legendaryMaxCost)) &#x210E;"])

        s += "</tbody></table>"

        // Rewards summary
        s += h3("Reward Summary")
        s += "<table>" + th(["Source", "Reward", "Notes"])
        s += "<tbody>"
        s += td(["TD Wave Completion", "\(BalanceConfig.Waves.hashBonusPerWave) &times; wave# &#x210E;", "Wave 20 = \(20 * BalanceConfig.Waves.hashBonusPerWave) &#x210E;"])
        s += td(["TD Victory", "\(BalanceConfig.TDRewards.victoryHashPerWave) &times; waves &#x210E; + \(BalanceConfig.TDRewards.victoryXPBonus) XP", "20 waves = \(20 * BalanceConfig.TDRewards.victoryHashPerWave) &#x210E;"])
        // ZeroDay removed from BalanceConfig
        s += td(["Boss (Easy)", "\(fNum(Double(BalanceConfig.BossDifficultyConfig.hashRewards["Easy"] ?? 0))) &#x210E;", ""])
        s += td(["Boss (Normal)", "\(fNum(Double(BalanceConfig.BossDifficultyConfig.hashRewards["Normal"] ?? 0))) &#x210E;", ""])
        s += td(["Boss (Hard)", "\(fNum(Double(BalanceConfig.BossDifficultyConfig.hashRewards["Hard"] ?? 0))) &#x210E;", ""])
        s += td(["Boss (Nightmare)", "\(fNum(Double(BalanceConfig.BossDifficultyConfig.hashRewards["Nightmare"] ?? 0))) &#x210E;", ""])
        s += "</tbody></table>"

        return s
    }

    // Helper: total upgrade cost for a rarity
    static func totals(for rarity: Rarity) -> Int {
        let base = BalanceConfig.Towers.placementCosts[rarity] ?? 50
        var total = 0
        for lv in 1..<BalanceConfig.maxUpgradeLevel {
            total += BalanceConfig.exponentialUpgradeCost(baseCost: base, currentLevel: lv)
        }
        return total
    }

    // Global needed for analysis section
    static let onlineRate = Double(BalanceConfig.ThreatLevel.onlineThreatGrowthRate)

    // MARK: - CSS & JS

    static func preamble() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Balance Reference - System: Reboot</title>
        <style>
        :root {
            --bg: #0a0a0f; --card: #12121a; --border: #1e1e2e;
            --text: #e4e4e7; --text2: #a1a1aa; --accent: #00d4ff;
            --t1: #22c55e; --t2: #84cc16; --t3: #eab308; --t4: #f97316; --t5: #ef4444;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: var(--bg); color: var(--text); font-family: 'SF Mono', 'Fira Code', 'Consolas', monospace; font-size: 13px; line-height: 1.5; }
        header { text-align: center; padding: 24px; border-bottom: 1px solid var(--border); }
        header h1 { color: var(--accent); font-size: 24px; letter-spacing: 4px; }
        header p { color: var(--text2); margin-top: 4px; }
        nav { display: flex; flex-wrap: wrap; gap: 4px; padding: 12px; justify-content: center; border-bottom: 1px solid var(--border); position: sticky; top: 0; background: var(--bg); z-index: 10; }
        nav button { background: var(--card); color: var(--text2); border: 1px solid var(--border); padding: 8px 16px; cursor: pointer; font-family: inherit; font-size: 12px; border-radius: 4px; transition: all 0.15s; }
        nav button:hover { border-color: var(--accent); color: var(--text); }
        nav button.active { background: var(--accent); color: #000; border-color: var(--accent); font-weight: bold; }
        main { max-width: 1400px; margin: 0 auto; padding: 16px; }
        .panel { display: none; }
        .panel.active { display: block; }
        h2 { color: var(--accent); font-size: 18px; margin: 24px 0 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border); }
        h3 { color: var(--text); font-size: 14px; margin: 20px 0 8px; }
        .note { color: var(--text2); font-size: 11px; margin: 4px 0 8px; font-style: italic; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 24px; background: var(--card); border-radius: 4px; overflow: hidden; }
        th { background: #1a1a2e; color: var(--accent); padding: 8px 12px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; white-space: nowrap; }
        td { padding: 6px 12px; border-top: 1px solid var(--border); white-space: nowrap; }
        tr:hover td { background: rgba(0, 212, 255, 0.03); }
        .totals td { background: #1a1a2e; font-weight: bold; }
        .t1 { color: var(--t1); } .t2 { color: var(--t2); } .t3 { color: var(--t3); } .t4 { color: var(--t4); } .t5 { color: var(--t5); }
        @media (max-width: 900px) { table { font-size: 11px; } td, th { padding: 4px 6px; } }
        </style>
        </head>
        <body>
        """
    }

    static func script() -> String {
        return """
        <script>
        const tabs = document.querySelectorAll('nav button');
        const panels = document.querySelectorAll('.panel');
        function activate(id) {
            tabs.forEach(t => t.classList.toggle('active', t.dataset.tab === id));
            panels.forEach(p => p.classList.toggle('active', p.id === id));
            location.hash = id;
        }
        tabs.forEach(t => t.addEventListener('click', () => activate(t.dataset.tab)));
        const hash = location.hash.slice(1);
        activate(hash && document.getElementById(hash) ? hash : 'economy');
        </script>
        """
    }
}
