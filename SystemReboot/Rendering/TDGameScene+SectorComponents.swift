import SpriteKit
import SwiftUI

extension TDGameScene {

    // MARK: - Shared Lane Exclusion

    /// Shared lane exclusion check for sector component placement.
    /// Returns true if the local-coordinate position overlaps standard enemy lane paths.
    static func isNearLane(_ x: CGFloat, _ y: CGFloat) -> Bool {
        if y > 500 && y < 900 && x > 300 && x < 1100 { return true }
        if x > 1000 && y > 400 && y < 700 { return true }
        return false
    }

    /// Add heat sink pattern for GPU sector
    func addHeatSinkPattern(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Batched paths for GPU sector
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3

        let heatSinkColor = UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0)
        let vramColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let thermalPadColor = UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 0.6)
        let copperColor = UIColor(hex: "#b87333") ?? .orange

        // Pre-generate positions
        var vramPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var thermalPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var vrmPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        var heatSinkData: [(x: CGFloat, y: CGFloat, finCount: Int, finW: CGFloat, finH: CGFloat)] = []

        for _ in 0..<25 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            if !Self.isNearLane(x, y) {
                vramPositions.append((x, y, CGFloat.random(in: 28...42), CGFloat.random(in: 22...32)))
            }
        }
        for _ in 0..<20 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            if !Self.isNearLane(x, y) {
                thermalPositions.append((x, y, CGFloat.random(in: 18...35), CGFloat.random(in: 18...35)))
            }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            if !Self.isNearLane(x, y) { vrmPositions.append((x, y)) }
        }
        for _ in 0..<50 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            if !Self.isNearLane(x, y) { capPositions.append((x, y, CGFloat.random(in: 4...7))) }
        }
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            if !Self.isNearLane(x, y) {
                heatSinkData.append((x, y, Int.random(in: 10...14), CGFloat.random(in: 4...5), CGFloat.random(in: 50...80)))
            }
        }

        // ========== BATCHED THERMAL PADS ==========
        let thermalPath = CGMutablePath()
        for pos in thermalPositions {
            thermalPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let thermalNode = SKShapeNode(path: thermalPath)
        thermalNode.fillColor = thermalPadColor
        thermalNode.strokeColor = .clear
        thermalNode.zPosition = zPos - 0.2
        node.addChild(thermalNode)

        // ========== BATCHED VRAM CHIPS ==========
        let vramPath = CGMutablePath()
        for pos in vramPositions {
            vramPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let vramNode = SKShapeNode(path: vramPath)
        vramNode.fillColor = vramColor
        vramNode.strokeColor = color.withAlphaComponent(0.4)
        vramNode.lineWidth = 0.5
        vramNode.zPosition = zPos - 0.1
        node.addChild(vramNode)

        // ========== BATCHED VRMs ==========
        let vrmPath = CGMutablePath()
        for pos in vrmPositions {
            vrmPath.addRect(CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 12, width: 16, height: 24))
        }
        let vrmNode = SKShapeNode(path: vrmPath)
        vrmNode.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        vrmNode.strokeColor = copperColor.withAlphaComponent(0.3)
        vrmNode.lineWidth = 0.5
        vrmNode.zPosition = zPos - 0.1
        node.addChild(vrmNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addEllipse(in: CGRect(x: baseX + pos.x - pos.r, y: baseY + pos.y - pos.r, width: pos.r * 2, height: pos.r * 2))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        capNode.strokeColor = color.withAlphaComponent(0.15)
        capNode.lineWidth = 0.5
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== HEAT SINKS (batched fins per sink) ==========
        for hs in heatSinkData {
            let finsPath = CGMutablePath()
            let spacing = hs.finW + 3
            let totalW = CGFloat(hs.finCount) * spacing
            for f in 0..<hs.finCount {
                let fx = baseX + hs.x - totalW/2 + CGFloat(f) * spacing
                finsPath.addRect(CGRect(x: fx, y: baseY + hs.y - hs.finH/2, width: hs.finW, height: hs.finH))
            }
            let finsNode = SKShapeNode(path: finsPath)
            finsNode.fillColor = heatSinkColor
            finsNode.strokeColor = color.withAlphaComponent(0.2)
            finsNode.lineWidth = 0.5
            finsNode.zPosition = zPos
            node.addChild(finsNode)
        }

        // ========== GPU DIE (individual - 2 units) ==========
        let gpuDiePositions: [(x: CGFloat, y: CGFloat, label: String)] = [(350, 300, "GPU"), (900, 950, "VRAM")]
        for pos in gpuDiePositions {
            if !Self.isNearLane(pos.x, pos.y) {
                let dieSize: CGFloat = 90
                let die = SKShapeNode(rect: CGRect(x: -dieSize/2, y: -dieSize/2, width: dieSize, height: dieSize), cornerRadius: 3)
                die.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                die.fillColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
                die.strokeColor = color
                die.lineWidth = 2
                die.zPosition = zPos + 0.2
                node.addChild(die)

                let label = SKLabelNode(text: pos.label)
                label.fontName = "Menlo-Bold"
                label.fontSize = 12
                label.fontColor = color.withAlphaComponent(0.7)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }
    }

    /// Add memory chip rows for RAM/Cache sectors - Dense "memory city"
    func addMemoryChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3


        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let pcbGreen = UIColor(red: 0.05, green: 0.12, blue: 0.08, alpha: 1.0)

        // Pre-generate positions for batching
        var dimmSlots: [(y: CGFloat, slotW: CGFloat, index: Int)] = []
        var contactPositions: [(x: CGFloat, y: CGFloat)] = []
        var dramChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pinPositions: [(x: CGFloat, y: CGFloat)] = []
        var spdPositions: [(x: CGFloat, y: CGFloat)] = []
        var capPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate DIMM slot positions ==========
        let dimmSlotY: [CGFloat] = [150, 300, 450, 850, 1000, 1150]
        for (index, slotY) in dimmSlotY.enumerated() {
            if !Self.isNearLane(width/2, slotY) {
                let slotW: CGFloat = width - 200
                dimmSlots.append((y: slotY, slotW: slotW, index: index))
                let contactCount = Int(slotW / 8)
                for c in 0..<contactCount {
                    contactPositions.append((x: 105 + CGFloat(c) * 8, y: slotY + 4))
                }
            }
        }

        // ========== Generate DRAM chip positions ==========
        for _ in 0..<50 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !Self.isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 30...60)
            let chipH = CGFloat.random(in: 20...35)
            dramChips.append((x: x, y: y, w: chipW, h: chipH))
            let pinCount = Int(chipW / 6)
            for p in 0..<pinCount {
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y + chipH/2))
                pinPositions.append((x: x - chipW/2 + 3 + CGFloat(p) * 6, y: y - chipH/2 - 4))
            }
        }

        // ========== Generate SPD positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            spdPositions.append((x: x, y: y))
        }

        // ========== Generate capacitor positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !Self.isNearLane(x, y) else { continue }
            let capW = CGFloat.random(in: 4...8)
            let capH = CGFloat.random(in: 3...5)
            capPositions.append((x: x, y: y, w: capW, h: capH))
        }

        // ========== BATCHED DIMM SLOTS ==========
        let slotPath = CGMutablePath()
        for slot in dimmSlots {
            slotPath.addRoundedRect(in: CGRect(x: baseX + 100, y: baseY + slot.y, width: slot.slotW, height: 20), cornerWidth: 2, cornerHeight: 2)
        }
        let slotNode = SKShapeNode(path: slotPath)
        slotNode.fillColor = pcbGreen
        slotNode.strokeColor = color.withAlphaComponent(0.4)
        slotNode.lineWidth = 1
        slotNode.zPosition = zPos - 0.2
        node.addChild(slotNode)

        // ========== BATCHED GOLD CONTACTS ==========
        let contactPath = CGMutablePath()
        for pos in contactPositions {
            contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let contactNode = SKShapeNode(path: contactPath)
        contactNode.fillColor = goldColor.withAlphaComponent(0.5)
        contactNode.strokeColor = .clear
        contactNode.zPosition = zPos - 0.1
        node.addChild(contactNode)

        // ========== BATCHED DRAM CHIPS ==========
        let chipPath = CGMutablePath()
        for chip in dramChips {
            chipPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 2, cornerHeight: 2)
        }
        let chipNode = SKShapeNode(path: chipPath)
        chipNode.fillColor = chipColor
        chipNode.strokeColor = color.withAlphaComponent(0.4)
        chipNode.lineWidth = 1
        chipNode.zPosition = zPos
        node.addChild(chipNode)

        // ========== BATCHED CHIP PINS ==========
        let pinPath = CGMutablePath()
        for pos in pinPositions {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 4))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.3)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED SPD CHIPS ==========
        let spdPath = CGMutablePath()
        for pos in spdPositions {
            spdPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 8, y: baseY + pos.y - 5, width: 16, height: 10), cornerWidth: 1, cornerHeight: 1)
        }
        let spdNode = SKShapeNode(path: spdPath)
        spdNode.fillColor = chipColor
        spdNode.strokeColor = color.withAlphaComponent(0.3)
        spdNode.lineWidth = 0.5
        spdNode.zPosition = zPos - 0.1
        node.addChild(spdNode)

        // ========== BATCHED CAPACITORS ==========
        let capPath = CGMutablePath()
        for pos in capPositions {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.4)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== DIMM LABELS (individual - few nodes) ==========
        for slot in dimmSlots {
            let label = SKLabelNode(text: "DIMM\(slot.index + 1)")
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + 80, y: baseY + slot.y + 5)
            label.horizontalAlignmentMode = .right
            label.zPosition = zPos
            node.addChild(label)
        }

        // ========== DDR5 LABELS (individual - few nodes) ==========
        let labels = ["DDR5", "16GB", "4800", "CL40", "1.1V"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: labels[i % labels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 8...12)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.4))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zRotation = CGFloat.random(in: -0.1...0.1)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add SSD chip outlines for Storage sector - Dense "storage city"
    func addStorageChips(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3


        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let controllerColor = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)

        // Pre-generate positions for batching
        var nandChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, hasLabel: Bool)] = []
        var cacheChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var pmicChips: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicCaps: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var resistors: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var m2Contacts: [(x: CGFloat, y: CGFloat)] = []

        // ========== Generate NAND positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            let chipW = CGFloat.random(in: 50...90)
            let chipH = CGFloat.random(in: 40...70)
            nandChips.append((x: x, y: y, w: chipW, h: chipH, hasLabel: Bool.random()))
        }

        // ========== Generate cache chip positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !Self.isNearLane(x, y) else { continue }
            let cacheW: CGFloat = CGFloat.random(in: 25...40)
            let cacheH: CGFloat = CGFloat.random(in: 18...28)
            cacheChips.append((x: x, y: y, w: cacheW, h: cacheH))
        }

        // ========== Generate M.2 contact positions ==========
        let m2Y: CGFloat = 100
        if !Self.isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            for c in 0..<Int(connW / 5) {
                m2Contacts.append((x: 205 + CGFloat(c) * 5, y: m2Y + 5))
            }
        }

        // ========== Generate PMIC positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 60...(width - 60))
            let y = CGFloat.random(in: 60...(height - 60))
            guard !Self.isNearLane(x, y) else { continue }
            let pmicW: CGFloat = CGFloat.random(in: 12...20)
            let pmicH: CGFloat = CGFloat.random(in: 10...16)
            pmicChips.append((x: x, y: y, w: pmicW, h: pmicH))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 30...(width - 30))
            let y = CGFloat.random(in: 30...(height - 30))
            guard !Self.isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...7)
            let compH = CGFloat.random(in: 2...5)
            if Bool.random() {
                ceramicCaps.append((x: x, y: y, w: compW, h: compH))
            } else {
                resistors.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED NAND CHIPS ==========
        let nandPath = CGMutablePath()
        for chip in nandChips {
            nandPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 3, cornerHeight: 3)
        }
        let nandNode = SKShapeNode(path: nandPath)
        nandNode.fillColor = chipColor
        nandNode.strokeColor = color.withAlphaComponent(0.5)
        nandNode.lineWidth = 1.5
        nandNode.zPosition = zPos
        node.addChild(nandNode)

        // NAND labels (individual - few nodes)
        for chip in nandChips where chip.hasLabel {
            let label = SKLabelNode(text: ["NAND", "3D", "TLC", "QLC"].randomElement() ?? "NAND")
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.5)
            label.position = CGPoint(x: baseX + chip.x, y: baseY + chip.y)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== SSD CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(250, 250), (900, 350), (400, 950)]
        for pos in controllerPositions {
            if !Self.isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 60...80)
                let controller = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 4)
                controller.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                controller.fillColor = controllerColor
                controller.strokeColor = color
                controller.lineWidth = 2
                controller.zPosition = zPos + 0.2
                node.addChild(controller)

                let label = SKLabelNode(text: "CTRL")
                label.fontName = "Menlo-Bold"
                label.fontSize = 10
                label.fontColor = color.withAlphaComponent(0.6)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.3
                node.addChild(label)
            }
        }

        // ========== BATCHED CACHE CHIPS ==========
        let cachePath = CGMutablePath()
        for chip in cacheChips {
            cachePath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = chipColor
        cacheNode.strokeColor = UIColor.cyan.withAlphaComponent(0.3)
        cacheNode.lineWidth = 1
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // ========== M.2 CONNECTOR (single node) ==========
        if !Self.isNearLane(width/2, m2Y) {
            let connW: CGFloat = 300
            let connH: CGFloat = 25
            let connector = SKShapeNode(rect: CGRect(x: 0, y: 0, width: connW, height: connH), cornerRadius: 2)
            connector.position = CGPoint(x: baseX + 200, y: baseY + m2Y)
            connector.fillColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
            connector.strokeColor = goldColor.withAlphaComponent(0.5)
            connector.lineWidth = 1
            connector.zPosition = zPos - 0.1
            node.addChild(connector)
        }

        // ========== BATCHED M.2 CONTACTS ==========
        if !m2Contacts.isEmpty {
            let contactPath = CGMutablePath()
            for pos in m2Contacts {
                contactPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 3, height: 15))
            }
            let contactNode = SKShapeNode(path: contactPath)
            contactNode.fillColor = goldColor.withAlphaComponent(0.4)
            contactNode.strokeColor = .clear
            contactNode.zPosition = zPos
            node.addChild(contactNode)
        }

        // ========== BATCHED PMIC CHIPS ==========
        let pmicPath = CGMutablePath()
        for chip in pmicChips {
            pmicPath.addRoundedRect(in: CGRect(x: baseX + chip.x - chip.w/2, y: baseY + chip.y - chip.h/2, width: chip.w, height: chip.h), cornerWidth: 1, cornerHeight: 1)
        }
        let pmicNode = SKShapeNode(path: pmicPath)
        pmicNode.fillColor = chipColor
        pmicNode.strokeColor = color.withAlphaComponent(0.2)
        pmicNode.lineWidth = 0.5
        pmicNode.zPosition = zPos - 0.1
        node.addChild(pmicNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let capPath = CGMutablePath()
        for pos in ceramicCaps {
            capPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let capNode = SKShapeNode(path: capPath)
        capNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        capNode.strokeColor = .clear
        capNode.zPosition = zPos - 0.3
        node.addChild(capNode)

        // ========== BATCHED RESISTORS ==========
        let resPath = CGMutablePath()
        for pos in resistors {
            resPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let resNode = SKShapeNode(path: resPath)
        resNode.fillColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.4)
        resNode.strokeColor = .clear
        resNode.zPosition = zPos - 0.3
        node.addChild(resNode)

        // ========== STORAGE LABELS (individual - few nodes) ==========
        let storageLabels = ["1TB", "2TB", "NVMe", "PCIe", "Gen4", "7000MB/s"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: storageLabels[i % storageLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add I/O connector outlines - Dense "I/O hub city"
    func addIOConnectors(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3


        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let blueUSB = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.6)

        // Pre-generate positions for batching
        var usbAPorts: [(x: CGFloat, y: CGFloat)] = []
        var usbATongues: [(x: CGFloat, y: CGFloat)] = []
        var usbCPorts: [(x: CGFloat, y: CGFloat)] = []
        var hdmiPorts: [(x: CGFloat, y: CGFloat)] = []
        var audioPorts: [(x: CGFloat, y: CGFloat, colorIndex: Int)] = []
        var diodePositions: [(x: CGFloat, y: CGFloat)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate USB-A positions ==========
        let usbARows: [(y: CGFloat, count: Int)] = [(150, 5), (250, 4), (1050, 5), (1150, 4)]
        for row in usbARows {
            if !Self.isNearLane(400, row.y) {
                for i in 0..<row.count {
                    usbAPorts.append((x: 100 + CGFloat(i) * 80, y: row.y))
                    usbATongues.append((x: 105 + CGFloat(i) * 80, y: row.y + 9))
                }
            }
        }

        // ========== Generate USB-C positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 350...500)
            guard !Self.isNearLane(x, y) else { continue }
            usbCPorts.append((x: x, y: y))
        }

        // ========== Generate HDMI positions ==========
        let hdmiPositions: [(x: CGFloat, y: CGFloat)] = [(150, 400), (250, 400), (1050, 400), (1150, 400), (200, 900), (300, 900)]
        for pos in hdmiPositions {
            if !Self.isNearLane(pos.x, pos.y) {
                hdmiPorts.append(pos)
            }
        }

        // ========== Generate audio jack positions ==========
        for i in 0..<8 {
            let x = CGFloat.random(in: 600...(width - 100))
            let y = CGFloat.random(in: 200...400)
            guard !Self.isNearLane(x, y) else { continue }
            audioPorts.append((x: x, y: y, colorIndex: i % 6))
        }

        // ========== Generate diode positions ==========
        for _ in 0..<30 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !Self.isNearLane(x, y) else { continue }
            diodePositions.append((x: x, y: y))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !Self.isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED USB-A PORTS ==========
        let usbAPath = CGMutablePath()
        for pos in usbAPorts {
            usbAPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 55, height: 30), cornerWidth: 2, cornerHeight: 2)
        }
        let usbANode = SKShapeNode(path: usbAPath)
        usbANode.fillColor = portColor
        usbANode.strokeColor = blueUSB
        usbANode.lineWidth = 1.5
        usbANode.zPosition = zPos
        node.addChild(usbANode)

        // ========== BATCHED USB-A TONGUES ==========
        let tonguePath = CGMutablePath()
        for pos in usbATongues {
            tonguePath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 45, height: 12))
        }
        let tongueNode = SKShapeNode(path: tonguePath)
        tongueNode.fillColor = blueUSB.withAlphaComponent(0.3)
        tongueNode.strokeColor = .clear
        tongueNode.zPosition = zPos + 0.1
        node.addChild(tongueNode)

        // ========== BATCHED USB-C PORTS ==========
        let usbCPath = CGMutablePath()
        for pos in usbCPorts {
            usbCPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 17.5, y: baseY + pos.y - 7, width: 35, height: 14), cornerWidth: 7, cornerHeight: 7)
        }
        let usbCNode = SKShapeNode(path: usbCPath)
        usbCNode.fillColor = portColor
        usbCNode.strokeColor = color.withAlphaComponent(0.6)
        usbCNode.lineWidth = 1
        usbCNode.zPosition = zPos
        node.addChild(usbCNode)

        // ========== BATCHED HDMI PORTS ==========
        let hdmiPath = CGMutablePath()
        for pos in hdmiPorts {
            hdmiPath.addRoundedRect(in: CGRect(x: baseX + pos.x - 30, y: baseY + pos.y - 12.5, width: 60, height: 25), cornerWidth: 3, cornerHeight: 3)
        }
        let hdmiNode = SKShapeNode(path: hdmiPath)
        hdmiNode.fillColor = portColor
        hdmiNode.strokeColor = color.withAlphaComponent(0.5)
        hdmiNode.lineWidth = 1.5
        hdmiNode.zPosition = zPos
        node.addChild(hdmiNode)

        // ========== AUDIO JACKS (individual - few nodes with different colors) ==========
        let audioColors: [UIColor] = [.green, .blue, .systemPink, .orange, .gray, .black]
        for port in audioPorts {
            let jack = SKShapeNode(circleOfRadius: 12)
            jack.position = CGPoint(x: baseX + port.x, y: baseY + port.y)
            jack.fillColor = portColor
            jack.strokeColor = audioColors[port.colorIndex].withAlphaComponent(0.5)
            jack.lineWidth = 2
            jack.zPosition = zPos
            node.addChild(jack)
        }

        // ========== BATCHED AUDIO HOLES ==========
        let holePath = CGMutablePath()
        for port in audioPorts {
            holePath.addEllipse(in: CGRect(x: baseX + port.x - 5, y: baseY + port.y - 5, width: 10, height: 10))
        }
        let holeNode = SKShapeNode(path: holePath)
        holeNode.fillColor = .black
        holeNode.strokeColor = .clear
        holeNode.zPosition = zPos + 0.1
        node.addChild(holeNode)

        // ========== USB CONTROLLER ICs (individual - large labeled) ==========
        let controllerPositions: [(x: CGFloat, y: CGFloat)] = [(400, 200), (800, 250), (500, 1000), (900, 950)]
        for (index, pos) in controllerPositions.enumerated() {
            if !Self.isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 45...65)
                let ctrl = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                ctrl.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                ctrl.fillColor = chipColor
                ctrl.strokeColor = color
                ctrl.lineWidth = 1.5
                ctrl.zPosition = zPos + 0.1
                node.addChild(ctrl)

                let label = SKLabelNode(text: ["USB", "HUB", "xHCI", "PHY"][index % 4])
                label.fontName = "Menlo"
                label.fontSize = 8
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED ESD DIODES ==========
        let diodePath = CGMutablePath()
        for pos in diodePositions {
            diodePath.addRoundedRect(in: CGRect(x: baseX + pos.x - 6, y: baseY + pos.y - 4, width: 12, height: 8), cornerWidth: 1, cornerHeight: 1)
        }
        let diodeNode = SKShapeNode(path: diodePath)
        diodeNode.fillColor = chipColor
        diodeNode.strokeColor = color.withAlphaComponent(0.2)
        diodeNode.lineWidth = 0.5
        diodeNode.zPosition = zPos - 0.1
        node.addChild(diodeNode)

        // ========== BATCHED FERRITE BEADS ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMIC CAPS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== I/O LABELS (individual - few nodes) ==========
        let ioLabels = ["USB 3.2", "USB-C", "HDMI", "DP", "AUDIO", "10Gbps"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: ioLabels[i % ioLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add network jack outline
    func addNetworkJack(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3


        let portColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        let goldColor = UIColor(hex: "#d4a600") ?? .yellow
        let chipColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        let greenLED = UIColor.green
        let orangeLED = UIColor.orange

        // Pre-generate positions for batching
        var rj45Jacks: [(x: CGFloat, y: CGFloat)] = []
        var rj45Pins: [(x: CGFloat, y: CGFloat)] = []
        var greenLEDs: [(x: CGFloat, y: CGFloat)] = []
        var orangeLEDs: [(x: CGFloat, y: CGFloat)] = []
        var transformerPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var smallICPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var statusLEDs: [(x: CGFloat, y: CGFloat, r: CGFloat, colorType: Int)] = []
        var ferritePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var ceramicPositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate RJ45 positions ==========
        let jackPositions: [(x: CGFloat, y: CGFloat)] = [
            (150, 200), (280, 200), (410, 200),
            (150, 350), (280, 350),
            (150, 950), (280, 950), (410, 950)
        ]
        let jackW: CGFloat = 70
        let jackH: CGFloat = 55
        for pos in jackPositions {
            if !Self.isNearLane(pos.x, pos.y) {
                rj45Jacks.append(pos)
                for p in 0..<8 {
                    rj45Pins.append((x: pos.x + 8 + CGFloat(p) * 7, y: pos.y + jackH - 15))
                }
                greenLEDs.append((x: pos.x + 12, y: pos.y + 8))
                orangeLEDs.append((x: pos.x + jackW - 12, y: pos.y + 8))
            }
        }

        // ========== Generate transformer positions ==========
        for _ in 0..<8 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            let magW: CGFloat = CGFloat.random(in: 35...55)
            let magH: CGFloat = CGFloat.random(in: 25...40)
            transformerPositions.append((x: x, y: y, w: magW, h: magH))
        }

        // ========== Generate small IC positions ==========
        for _ in 0..<25 {
            let x = CGFloat.random(in: 80...(width - 80))
            let y = CGFloat.random(in: 80...(height - 80))
            guard !Self.isNearLane(x, y) else { continue }
            let icW: CGFloat = CGFloat.random(in: 15...28)
            let icH: CGFloat = CGFloat.random(in: 12...22)
            smallICPositions.append((x: x, y: y, w: icW, h: icH))
        }

        // ========== Generate status LED positions ==========
        for _ in 0..<15 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            let r = CGFloat.random(in: 3...5)
            statusLEDs.append((x: x, y: y, r: r, colorType: Int.random(in: 0..<3)))
        }

        // ========== Generate passive component positions ==========
        for _ in 0..<120 {
            let x = CGFloat.random(in: 40...(width - 40))
            let y = CGFloat.random(in: 40...(height - 40))
            guard !Self.isNearLane(x, y) else { continue }
            let compW = CGFloat.random(in: 3...6)
            let compH = CGFloat.random(in: 2...4)
            if Bool.random() {
                ferritePositions.append((x: x, y: y, w: compW, h: compH))
            } else {
                ceramicPositions.append((x: x, y: y, w: compW, h: compH))
            }
        }

        // ========== BATCHED RJ45 JACKS ==========
        let jackPath = CGMutablePath()
        for pos in rj45Jacks {
            jackPath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: jackW, height: jackH), cornerWidth: 3, cornerHeight: 3)
        }
        let jackNode = SKShapeNode(path: jackPath)
        jackNode.fillColor = portColor
        jackNode.strokeColor = color.withAlphaComponent(0.6)
        jackNode.lineWidth = 1.5
        jackNode.zPosition = zPos
        node.addChild(jackNode)

        // ========== BATCHED RJ45 PINS ==========
        let pinPath = CGMutablePath()
        for pos in rj45Pins {
            pinPath.addRect(CGRect(x: baseX + pos.x, y: baseY + pos.y, width: 4, height: 12))
        }
        let pinNode = SKShapeNode(path: pinPath)
        pinNode.fillColor = goldColor.withAlphaComponent(0.5)
        pinNode.strokeColor = .clear
        pinNode.zPosition = zPos + 0.1
        node.addChild(pinNode)

        // ========== BATCHED GREEN LEDs ==========
        let greenPath = CGMutablePath()
        for pos in greenLEDs {
            greenPath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let greenNode = SKShapeNode(path: greenPath)
        greenNode.fillColor = greenLED.withAlphaComponent(0.4)
        greenNode.strokeColor = .clear
        greenNode.zPosition = zPos + 0.1
        node.addChild(greenNode)

        // ========== BATCHED ORANGE LEDs ==========
        let orangePath = CGMutablePath()
        for pos in orangeLEDs {
            orangePath.addEllipse(in: CGRect(x: baseX + pos.x - 4, y: baseY + pos.y - 4, width: 8, height: 8))
        }
        let orangeNode = SKShapeNode(path: orangePath)
        orangeNode.fillColor = orangeLED.withAlphaComponent(0.4)
        orangeNode.strokeColor = .clear
        orangeNode.zPosition = zPos + 0.1
        node.addChild(orangeNode)

        // ========== ETHERNET PHY CHIPS (individual - large labeled) ==========
        let phyPositions: [(x: CGFloat, y: CGFloat)] = [(600, 200), (900, 300), (550, 950), (850, 1000)]
        for (index, pos) in phyPositions.enumerated() {
            if !Self.isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 50...70)
                let phy = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                phy.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                phy.fillColor = chipColor
                phy.strokeColor = color
                phy.lineWidth = 2
                phy.zPosition = zPos + 0.1
                node.addChild(phy)

                let label = SKLabelNode(text: ["PHY", "MAC", "ETH", "NIC"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED TRANSFORMERS ==========
        let transPath = CGMutablePath()
        for pos in transformerPositions {
            transPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let transNode = SKShapeNode(path: transPath)
        transNode.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        transNode.strokeColor = color.withAlphaComponent(0.3)
        transNode.lineWidth = 1
        transNode.zPosition = zPos
        node.addChild(transNode)

        // ========== BATCHED SMALL ICs ==========
        let icPath = CGMutablePath()
        for pos in smallICPositions {
            icPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 1, cornerHeight: 1)
        }
        let icNode = SKShapeNode(path: icPath)
        icNode.fillColor = chipColor
        icNode.strokeColor = color.withAlphaComponent(0.25)
        icNode.lineWidth = 0.5
        icNode.zPosition = zPos - 0.1
        node.addChild(icNode)

        // ========== BATCHED STATUS LEDs (by color) ==========
        let statusGreenPath = CGMutablePath()
        let statusOrangePath = CGMutablePath()
        let statusYellowPath = CGMutablePath()
        for led in statusLEDs {
            let rect = CGRect(x: baseX + led.x - led.r, y: baseY + led.y - led.r, width: led.r * 2, height: led.r * 2)
            switch led.colorType {
            case 0: statusGreenPath.addEllipse(in: rect)
            case 1: statusOrangePath.addEllipse(in: rect)
            default: statusYellowPath.addEllipse(in: rect)
            }
        }
        let statusGreenNode = SKShapeNode(path: statusGreenPath)
        statusGreenNode.fillColor = greenLED.withAlphaComponent(0.3)
        statusGreenNode.strokeColor = .clear
        statusGreenNode.zPosition = zPos
        node.addChild(statusGreenNode)

        let statusOrangeNode = SKShapeNode(path: statusOrangePath)
        statusOrangeNode.fillColor = orangeLED.withAlphaComponent(0.3)
        statusOrangeNode.strokeColor = .clear
        statusOrangeNode.zPosition = zPos
        node.addChild(statusOrangeNode)

        let statusYellowNode = SKShapeNode(path: statusYellowPath)
        statusYellowNode.fillColor = UIColor.yellow.withAlphaComponent(0.3)
        statusYellowNode.strokeColor = .clear
        statusYellowNode.zPosition = zPos
        node.addChild(statusYellowNode)

        // ========== BATCHED FERRITES ==========
        let ferritePath = CGMutablePath()
        for pos in ferritePositions {
            ferritePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ferriteNode = SKShapeNode(path: ferritePath)
        ferriteNode.fillColor = UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.4)
        ferriteNode.strokeColor = .clear
        ferriteNode.zPosition = zPos - 0.3
        node.addChild(ferriteNode)

        // ========== BATCHED CERAMICS ==========
        let ceramicPath = CGMutablePath()
        for pos in ceramicPositions {
            ceramicPath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let ceramicNode = SKShapeNode(path: ceramicPath)
        ceramicNode.fillColor = UIColor(red: 0.6, green: 0.55, blue: 0.4, alpha: 0.3)
        ceramicNode.strokeColor = .clear
        ceramicNode.zPosition = zPos - 0.3
        node.addChild(ceramicNode)

        // ========== NETWORK LABELS (individual - few nodes) ==========
        let netLabels = ["1G LAN", "2.5G", "ETH", "RJ45", "Cat6", "PoE"]
        for i in 0..<8 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: netLabels[i % netLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add cache memory blocks for processing sectors - Dense "processor city"
    func addCacheBlocks(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        // PERFORMANCE OPTIMIZED: Uses batched paths instead of individual nodes
        let baseX = sector.worldX
        let baseY = sector.worldY
        let width = sector.width
        let height = sector.height
        let zPos: CGFloat = 3


        let chipColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        let cacheColor = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)

        // Pre-generate positions for batching
        var cacheBlocks: [(x: CGFloat, y: CGFloat)] = []
        var cacheGridLabels: [(x: CGFloat, y: CGFloat, text: String)] = []
        var processorUnits: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
        var registerBlocks: [(x: CGFloat, y: CGFloat)] = []
        var busLines: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
        var gatePositions: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []

        // ========== Generate cache grid positions ==========
        let cacheGridPositions: [(x: CGFloat, y: CGFloat, rows: Int, cols: Int)] = [
            (150, 200, 5, 8), (800, 150, 4, 6),
            (200, 900, 4, 7), (850, 950, 5, 5)
        ]
        let blockSize: CGFloat = 22
        for grid in cacheGridPositions {
            if !Self.isNearLane(grid.x + CGFloat(grid.cols) * 20, grid.y + CGFloat(grid.rows) * 20) {
                for row in 0..<grid.rows {
                    for col in 0..<grid.cols {
                        cacheBlocks.append((x: grid.x + CGFloat(col) * blockSize, y: grid.y + CGFloat(row) * blockSize))
                    }
                }
                cacheGridLabels.append((x: grid.x + CGFloat(grid.cols) * blockSize / 2, y: grid.y - 15, text: ["L3", "L2", "SRAM", "CACHE"].randomElement() ?? "L3"))
            }
        }

        // ========== Generate processor unit positions ==========
        for _ in 0..<20 {
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            let unitW = CGFloat.random(in: 30...50)
            let unitH = CGFloat.random(in: 25...40)
            processorUnits.append((x: x, y: y, w: unitW, h: unitH))
        }

        // ========== Generate register block positions ==========
        for _ in 0..<10 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            registerBlocks.append((x: x, y: y))
        }

        // ========== Generate bus line positions ==========
        for _ in 0..<8 {
            let isHorizontal = Bool.random()
            let lineLength = CGFloat.random(in: 100...300)
            let x = CGFloat.random(in: 100...(width - 100))
            let y = CGFloat.random(in: 100...(height - 100))
            guard !Self.isNearLane(x, y) else { continue }
            if isHorizontal {
                busLines.append((x1: x, y1: y, x2: x + lineLength, y2: y))
            } else {
                busLines.append((x1: x, y1: y, x2: x, y2: y + lineLength))
            }
        }

        // ========== Generate gate positions ==========
        for _ in 0..<100 {
            let x = CGFloat.random(in: 50...(width - 50))
            let y = CGFloat.random(in: 50...(height - 50))
            guard !Self.isNearLane(x, y) else { continue }
            let gateW = CGFloat.random(in: 5...10)
            let gateH = CGFloat.random(in: 4...8)
            gatePositions.append((x: x, y: y, w: gateW, h: gateH))
        }

        // ========== BATCHED CACHE BLOCKS ==========
        let cachePath = CGMutablePath()
        for pos in cacheBlocks {
            cachePath.addRoundedRect(in: CGRect(x: baseX + pos.x, y: baseY + pos.y, width: blockSize - 3, height: blockSize - 3), cornerWidth: 1, cornerHeight: 1)
        }
        let cacheNode = SKShapeNode(path: cachePath)
        cacheNode.fillColor = cacheColor
        cacheNode.strokeColor = color.withAlphaComponent(0.4)
        cacheNode.lineWidth = 0.5
        cacheNode.zPosition = zPos
        node.addChild(cacheNode)

        // Cache grid labels (individual - few nodes)
        for lbl in cacheGridLabels {
            let label = SKLabelNode(text: lbl.text)
            label.fontName = "Menlo"
            label.fontSize = 8
            label.fontColor = color.withAlphaComponent(0.4)
            label.position = CGPoint(x: baseX + lbl.x, y: baseY + lbl.y)
            label.horizontalAlignmentMode = .center
            label.zPosition = zPos + 0.1
            node.addChild(label)
        }

        // ========== BATCHED PROCESSOR UNITS ==========
        let unitPath = CGMutablePath()
        for pos in processorUnits {
            unitPath.addRoundedRect(in: CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h), cornerWidth: 2, cornerHeight: 2)
        }
        let unitNode = SKShapeNode(path: unitPath)
        unitNode.fillColor = chipColor
        unitNode.strokeColor = color.withAlphaComponent(0.5)
        unitNode.lineWidth = 1
        unitNode.zPosition = zPos
        node.addChild(unitNode)

        // ========== ALU/FPU BLOCKS (individual - large labeled) ==========
        let aluPositions: [(x: CGFloat, y: CGFloat)] = [
            (500, 300), (700, 350), (400, 450),
            (600, 850), (750, 900), (500, 1000)
        ]
        for (index, pos) in aluPositions.enumerated() {
            if !Self.isNearLane(pos.x, pos.y) {
                let size: CGFloat = CGFloat.random(in: 40...60)
                let alu = SKShapeNode(rect: CGRect(x: -size/2, y: -size/2, width: size, height: size), cornerRadius: 3)
                alu.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                alu.fillColor = cacheColor
                alu.strokeColor = color
                alu.lineWidth = 1.5
                alu.zPosition = zPos + 0.1
                node.addChild(alu)

                let label = SKLabelNode(text: ["ALU", "FPU", "CU", "REG"][index % 4])
                label.fontName = "Menlo-Bold"
                label.fontSize = 9
                label.fontColor = color.withAlphaComponent(0.5)
                label.position = CGPoint(x: baseX + pos.x, y: baseY + pos.y)
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.zPosition = zPos + 0.2
                node.addChild(label)
            }
        }

        // ========== BATCHED REGISTER FILES ==========
        let regW: CGFloat = 8
        let regH: CGFloat = 6
        let regPath = CGMutablePath()
        for pos in registerBlocks {
            for row in 0..<2 {
                for col in 0..<4 {
                    regPath.addRect(CGRect(x: baseX + pos.x + CGFloat(col) * regW, y: baseY + pos.y + CGFloat(row) * regH, width: regW - 1, height: regH - 1))
                }
            }
        }
        let regNode = SKShapeNode(path: regPath)
        regNode.fillColor = chipColor
        regNode.strokeColor = color.withAlphaComponent(0.3)
        regNode.lineWidth = 0.5
        regNode.zPosition = zPos - 0.1
        node.addChild(regNode)

        // ========== BATCHED BUS LINES ==========
        let busPath = CGMutablePath()
        for line in busLines {
            busPath.move(to: CGPoint(x: baseX + line.x1, y: baseY + line.y1))
            busPath.addLine(to: CGPoint(x: baseX + line.x2, y: baseY + line.y2))
        }
        let busNode = SKShapeNode(path: busPath)
        busNode.strokeColor = color.withAlphaComponent(0.2)
        busNode.lineWidth = 2
        busNode.zPosition = zPos - 0.2
        node.addChild(busNode)

        // ========== BATCHED LOGIC GATES ==========
        let gatePath = CGMutablePath()
        for pos in gatePositions {
            gatePath.addRect(CGRect(x: baseX + pos.x - pos.w/2, y: baseY + pos.y - pos.h/2, width: pos.w, height: pos.h))
        }
        let gateNode = SKShapeNode(path: gatePath)
        gateNode.fillColor = chipColor.withAlphaComponent(0.6)
        gateNode.strokeColor = color.withAlphaComponent(0.15)
        gateNode.lineWidth = 0.5
        gateNode.zPosition = zPos - 0.3
        node.addChild(gateNode)

        // ========== PROCESSOR LABELS (individual - few nodes) ==========
        let procLabels = ["L3 CACHE", "32MB", "SRAM", "12-core", "REG", "ALU"]
        for i in 0..<6 {
            let x = CGFloat.random(in: 150...(width - 150))
            let y = CGFloat.random(in: 150...(height - 150))
            guard !Self.isNearLane(x, y) else { continue }
            let label = SKLabelNode(text: procLabels[i % procLabels.count])
            label.fontName = "Menlo"
            label.fontSize = CGFloat.random(in: 7...10)
            label.fontColor = color.withAlphaComponent(CGFloat.random(in: 0.2...0.35))
            label.position = CGPoint(x: baseX + x, y: baseY + y)
            label.zPosition = zPos + 0.2
            node.addChild(label)
        }
    }

    /// Add trace bundles connecting to sector edges
    func addSectorTraces(to node: SKNode, in sector: MegaBoardSector, color: UIColor) {
        let traceColor = UIColor(hex: MotherboardColors.copperTrace)?.withAlphaComponent(0.15) ?? UIColor.orange.withAlphaComponent(0.15)
        let traceCount = 6
        let traceSpacing: CGFloat = 8
        let traceWidth: CGFloat = 2

        // Add trace bundle going toward CPU (center of map)
        let sectorCenter = CGPoint(x: sector.worldX + sector.width / 2, y: sector.worldY + sector.height / 2)
        let cpuCenter = MotherboardLaneConfig.cpuCenter

        // Determine edge closest to CPU
        let dx = cpuCenter.x - sectorCenter.x
        let dy = cpuCenter.y - sectorCenter.y

        var startPoint: CGPoint
        var endPoint: CGPoint

        if abs(dx) > abs(dy) {
            // Horizontal traces
            if dx > 0 {
                // Traces go right
                startPoint = CGPoint(x: sector.worldX + sector.width - 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX + sector.width, y: sectorCenter.y)
            } else {
                // Traces go left
                startPoint = CGPoint(x: sector.worldX + 100, y: sectorCenter.y)
                endPoint = CGPoint(x: sector.worldX, y: sectorCenter.y)
            }
        } else {
            // Vertical traces
            if dy > 0 {
                // Traces go up
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height - 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + sector.height)
            } else {
                // Traces go down
                startPoint = CGPoint(x: sectorCenter.x, y: sector.worldY + 100)
                endPoint = CGPoint(x: sectorCenter.x, y: sector.worldY)
            }
        }

        // Draw parallel traces (batched into single compound path)
        let isHorizontal = abs(dx) > abs(dy)
        let compoundPath = CGMutablePath()
        for i in 0..<traceCount {
            let offset = CGFloat(i - traceCount/2) * traceSpacing

            if isHorizontal {
                compoundPath.move(to: CGPoint(x: startPoint.x, y: startPoint.y + offset))
                compoundPath.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y + offset))
            } else {
                compoundPath.move(to: CGPoint(x: startPoint.x + offset, y: startPoint.y))
                compoundPath.addLine(to: CGPoint(x: endPoint.x + offset, y: endPoint.y))
            }
        }

        let traceNode = SKShapeNode(path: compoundPath)
        traceNode.strokeColor = traceColor
        traceNode.lineWidth = traceWidth
        traceNode.zPosition = -3.5
        node.addChild(traceNode)
    }

}
