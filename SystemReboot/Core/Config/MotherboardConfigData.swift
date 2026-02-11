import Foundation
import CoreGraphics

// MARK: - Motherboard Config Default Data
// Extracted from MotherboardTypes.swift — pure data (district coordinates,
// component positions, bus definitions) kept as Swift for compile-time safety.

extension MotherboardConfig {
    /// Create the default motherboard configuration for System: Reboot
    static func createDefault() -> MotherboardConfig {
        // Create districts
        let districts = [
            MotherboardDistrict(
                id: "cpu_district",
                name: "CPU District",
                description: "The core processing unit - defend at all costs",
                x: 1800, y: 1800, width: 400, height: 400,
                componentIds: ["cpu_main"],
                primaryColor: MotherboardColors.cpuCore,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "ram_district",
                name: "RAM District",
                description: "Memory modules - boost tower performance",
                x: 1600, y: 3000, width: 800, height: 600,
                componentIds: ["ram_1", "ram_2", "ram_3", "ram_4"],
                primaryColor: MotherboardColors.ramSlots,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "gpu_district",
                name: "GPU District",
                description: "Graphics processing - massive damage boost",
                x: 1600, y: 400, width: 800, height: 600,
                componentIds: ["gpu_main"],
                primaryColor: MotherboardColors.gpuSlot,
                secondaryColor: MotherboardColors.powerSurge
            ),
            MotherboardDistrict(
                id: "storage_district",
                name: "Storage Bay",
                description: "SSD and HDD - save your progress",
                x: 3000, y: 1600, width: 600, height: 800,
                componentIds: ["ssd_1", "hdd_1"],
                primaryColor: MotherboardColors.storage,
                secondaryColor: MotherboardColors.activeGlow
            ),
            MotherboardDistrict(
                id: "io_district",
                name: "I/O Panel",
                description: "External ports - virus entry points",
                x: 400, y: 1600, width: 600, height: 800,
                componentIds: ["usb_1", "usb_2", "lan_1"],
                primaryColor: MotherboardColors.ioPorts,
                secondaryColor: MotherboardColors.activeGlow
            )
        ]

        // Create components
        let components = [
            // CPU - always installed
            MotherboardComponent(
                id: "cpu_main",
                componentType: .cpu,
                displayName: "Central Processing Unit",
                gridX: 18, gridY: 18,
                gridWidth: 4, gridHeight: 4,
                isInstalled: true,
                isPowered: true,
                powerRequirement: 0,
                installCost: 0,
                bonus: nil,
                spawnPointOffset: nil
            ),
            // RAM slots
            MotherboardComponent(
                id: "ram_1",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 1",
                gridX: 17, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 2000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_2",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 2",
                gridX: 19, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 3000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_3",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 3",
                gridX: 21, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 4000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "ram_4",
                componentType: .ramSlot,
                displayName: "DDR5 Slot 4",
                gridX: 23, gridY: 32,
                gridWidth: 2, gridHeight: 4,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 50,
                installCost: 5000,
                bonus: .cacheBoost(multiplier: 1.1),
                spawnPointOffset: nil
            ),
            // GPU
            MotherboardComponent(
                id: "gpu_main",
                componentType: .gpuSlot,
                displayName: "PCIe x16 Graphics",
                gridX: 17, gridY: 6,
                gridWidth: 6, gridHeight: 3,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 200,
                installCost: 10000,
                bonus: .renderBoost(multiplier: 1.5),
                spawnPointOffset: nil
            ),
            // Storage
            MotherboardComponent(
                id: "ssd_1",
                componentType: .ssdBay,
                displayName: "NVMe SSD",
                gridX: 32, gridY: 18,
                gridWidth: 3, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 20,
                installCost: 5000,
                bonus: .storageCapacity(slots: 3),
                spawnPointOffset: nil
            ),
            MotherboardComponent(
                id: "hdd_1",
                componentType: .hddBay,
                displayName: "Archive HDD",
                gridX: 32, gridY: 21,
                gridWidth: 3, gridHeight: 3,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 30,
                installCost: 3000,
                bonus: .storageCapacity(slots: 5),
                spawnPointOffset: nil
            ),
            // I/O Ports (spawn points)
            MotherboardComponent(
                id: "usb_1",
                componentType: .usbPort,
                displayName: "USB Port 1",
                gridX: 4, gridY: 18,
                gridWidth: 2, gridHeight: 2,
                isInstalled: true,  // Start with one port open
                isPowered: true,
                powerRequirement: 5,
                installCost: 0,
                bonus: nil,
                spawnPointOffset: CGPoint(x: -50, y: 0)
            ),
            MotherboardComponent(
                id: "usb_2",
                componentType: .usbPort,
                displayName: "USB Port 2",
                gridX: 4, gridY: 21,
                gridWidth: 2, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 5,
                installCost: 1000,
                bonus: nil,
                spawnPointOffset: CGPoint(x: -50, y: 0)
            ),
            MotherboardComponent(
                id: "lan_1",
                componentType: .lanPort,
                displayName: "Ethernet Port",
                gridX: 4, gridY: 24,
                gridWidth: 2, gridHeight: 2,
                isInstalled: false,
                isPowered: false,
                powerRequirement: 10,
                installCost: 2000,
                bonus: .bandwidthLimit(reduction: 0.1),
                spawnPointOffset: CGPoint(x: -50, y: 0)
            )
        ]

        // Create buses
        let buses = [
            SystemBus(
                id: "west_bus",
                busType: .west,
                width: 64,
                isActive: true,
                segments: [
                    BusSegment(start: CGPoint(x: 600, y: 2000),
                              end: CGPoint(x: 1800, y: 2000),
                              direction: .east)
                ],
                connectedComponentIds: ["cpu_main", "usb_1", "usb_2", "lan_1"]
            ),
            SystemBus(
                id: "north_bus",
                busType: .north,
                width: 64,
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2000, y: 2200),
                              end: CGPoint(x: 2000, y: 3000),
                              direction: .north)
                ],
                connectedComponentIds: ["cpu_main", "ram_1", "ram_2", "ram_3", "ram_4"]
            ),
            SystemBus(
                id: "south_bus",
                busType: .south,
                width: 128,  // Wider for GPU
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2000, y: 1800),
                              end: CGPoint(x: 2000, y: 1000),
                              direction: .south)
                ],
                connectedComponentIds: ["cpu_main", "gpu_main"]
            ),
            SystemBus(
                id: "east_bus",
                busType: .east,
                width: 32,
                isActive: false,
                segments: [
                    BusSegment(start: CGPoint(x: 2200, y: 2000),
                              end: CGPoint(x: 3200, y: 2000),
                              direction: .east)
                ],
                connectedComponentIds: ["cpu_main", "ssd_1", "hdd_1"]
            )
        ]

        return MotherboardConfig(
            canvasWidth: 4200,  // 3 sectors × 1400
            canvasHeight: 4200,
            districts: districts,
            components: components,
            buses: buses,
            starterComponentIds: ["cpu_main", "usb_1"],
            basePowerBudget: 1000,
            maxPowerBudget: 10000
        )
    }
}
