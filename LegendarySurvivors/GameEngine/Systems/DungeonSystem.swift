import Foundation
import CoreGraphics

// MARK: - Dungeon System

class DungeonSystem {

    // MARK: - Room Creation

    static func createDungeonRooms(arenaId: String) -> [DungeonRoom] {
        var rooms: [DungeonRoom] = []

        // Create progression based on arena type
        switch arenaId {
        case "frozen_wasteland":
            rooms = createFrozenProgression()
        case "volcanic_depths":
            rooms = createVolcanicProgression()
        case "heist":
            rooms = createHeistProgression()
        case "void_raid":
            rooms = createVoidRaidProgression()
        case "cyberboss":
            rooms = createCyberbossProgression()
        default:
            rooms = createCathedralProgression()
        }

        return rooms
    }

    // MARK: - Cathedral Progression (Default)

    private static func createCathedralProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createCorruptedCathedral(),
            createCorruptedGarden(),
            createAncientCrypt(),
            createThroneRoom()
        ]
    }

    private static func createPreRoom() -> DungeonRoom {
        let width: CGFloat = 1200
        let height: CGFloat = 800

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "pre_room",
            width: width,
            height: height,
            enemies: [],
            obstacles: createPreRoomObstacles(width: width, height: height),
            effectZones: [
                // Starting healing zone
                ArenaEffectZone(
                    id: RandomUtils.generateId(),
                    x: width / 2 - 100,
                    y: height / 2 - 100,
                    width: 200,
                    height: 200,
                    effects: ["healthRegeneration": 5.0],
                    type: "healing"
                )
            ],
            hazards: [],
            backgroundColor: "#1a1a2e",
            decorations: createPreRoomDecorations(width: width, height: height),
            doors: [
                Door(
                    id: RandomUtils.generateId(),
                    x: width - 50,
                    y: height / 2 - 40,
                    width: 50,
                    height: 80,
                    locked: false,
                    targetRoomIndex: 1,
                    direction: "right"
                )
            ]
        )
    }

    private static func createCorruptedCathedral() -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []
        var decorations: [Decoration] = []

        // Pillar rows with wide spacing
        for i in 0..<4 {
            let x = 600 + CGFloat(i) * 700
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: x, y: 400,
                width: 80, height: 80,
                color: "#4a4a6a",
                type: "pillar"
            ))
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: x, y: height - 400,
                width: 80, height: 80,
                color: "#4a4a6a",
                type: "pillar"
            ))
        }

        // Altar at the end
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: width - 400, y: height / 2 - 60,
            width: 200, height: 120,
            color: "#6a4a6a",
            type: "altar"
        ))

        // Decorations - overturned chairs, prayer books, corruption tendrils
        for _ in 0..<50 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 200...(width - 200)),
                y: CGFloat.random(in: 200...(height - 200)),
                type: "prayer_book",
                color: "#8b7355"
            ))
        }

        for _ in 0..<30 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 100...(width - 100)),
                y: CGFloat.random(in: 100...(height - 100)),
                type: "corruption_tendril",
                color: "#4a0080"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "corrupted_cathedral",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "cathedral", count: 25),
            obstacles: obstacles,
            effectZones: [],
            hazards: createCorruptionHazards(width: width, height: height),
            backgroundColor: "#1a1025",
            decorations: decorations,
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 0, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: 2, direction: "right")
            ]
        )
    }

    private static func createCorruptedGarden() -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []
        var decorations: [Decoration] = []

        // Dead trees scattered
        for _ in 0..<8 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 400...(width - 400)),
                y: CGFloat.random(in: 400...(height - 400)),
                width: 100, height: 100,
                color: "#3d2817",
                type: "dead_tree"
            ))
        }

        // Poisoned fountains
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: width / 3, y: height / 2,
            width: 120, height: 120,
            color: "#2d4a2d",
            type: "fountain"
        ))
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: width * 2 / 3, y: height / 2,
            width: 120, height: 120,
            color: "#2d4a2d",
            type: "fountain"
        ))

        // Thorny vegetation decorations
        for _ in 0..<100 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                type: "thorns",
                color: "#2d1f1f"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "corrupted_garden",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "garden", count: 30),
            obstacles: obstacles,
            effectZones: [
                // Poison puddles slow enemies
                ArenaEffectZone(
                    id: RandomUtils.generateId(),
                    x: width / 3 - 100, y: height / 2 - 100,
                    width: 200, height: 200,
                    effects: ["speedMultiplier": 0.7],
                    type: "poison"
                )
            ],
            hazards: createPoisonHazards(width: width, height: height),
            backgroundColor: "#0d1a0d",
            decorations: decorations,
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 1, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: 3, direction: "right")
            ]
        )
    }

    private static func createAncientCrypt() -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []
        var decorations: [Decoration] = []

        // Sarcophagi in rows
        for i in 0..<3 {
            for j in 0..<2 {
                obstacles.append(Obstacle(
                    id: RandomUtils.generateId(),
                    x: 600 + CGFloat(i) * 900,
                    y: 500 + CGFloat(j) * 800,
                    width: 150, height: 80,
                    color: "#4a4a4a",
                    type: "sarcophagus"
                ))
            }
        }

        // Skull piles and burial urns
        for _ in 0..<40 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 100...(width - 100)),
                y: CGFloat.random(in: 100...(height - 100)),
                type: "skull_pile",
                color: "#d4c4a8"
            ))
        }

        for _ in 0..<30 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 100...(width - 100)),
                y: CGFloat.random(in: 100...(height - 100)),
                type: "burial_urn",
                color: "#8b7355"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "ancient_crypt",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "crypt", count: 35),
            obstacles: obstacles,
            effectZones: [],
            hazards: createCryptHazards(width: width, height: height),
            backgroundColor: "#0f0f15",
            decorations: decorations,
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 2, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: 4, direction: "right")
            ]
        )
    }

    private static func createThroneRoom() -> DungeonRoom {
        let width: CGFloat = 2400
        let height: CGFloat = 1600

        var obstacles: [Obstacle] = []

        // Throne at the back
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: width - 300, y: height / 2 - 100,
            width: 200, height: 200,
            color: "#6a4a8a",
            type: "throne"
        ))

        // Side pillars
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: 400, y: 300,
            width: 100, height: 100,
            color: "#5a5a7a",
            type: "pillar"
        ))
        obstacles.append(Obstacle(
            id: RandomUtils.generateId(),
            x: 400, y: height - 400,
            width: 100, height: 100,
            color: "#5a5a7a",
            type: "pillar"
        ))

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "throne_room",
            width: width,
            height: height,
            enemies: [], // Boss spawns separately
            obstacles: obstacles,
            effectZones: [],
            hazards: [],
            backgroundColor: "#150a1f",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 3, direction: "left")
            ],
            isBossRoom: true,
            bossId: "void_harbinger"
        )
    }

    // MARK: - Frozen Progression

    private static func createFrozenProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createFrozenCitadel(index: 1),
            createFrozenCitadel(index: 2),
            createIceThrone()
        ]
    }

    private static func createFrozenCitadel(index: Int) -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []

        // Ice pillars
        for i in 0..<5 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 500 + CGFloat(i) * 600,
                y: CGFloat.random(in: 400...(height - 400)),
                width: 90, height: 90,
                color: "#a0d8ef",
                type: "ice_pillar"
            ))
        }

        // Frozen warriors
        for _ in 0..<3 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 600...(width - 600)),
                y: CGFloat.random(in: 400...(height - 400)),
                width: 60, height: 80,
                color: "#7ec8e3",
                type: "frozen_warrior"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "frozen_citadel_\(index)",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "frozen", count: 25 + index * 5),
            obstacles: obstacles,
            effectZones: createFrozenEffectZones(width: width, height: height),
            hazards: createFrozenHazards(width: width, height: height),
            backgroundColor: "#0a1929",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: index - 1, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: index + 1, direction: "right")
            ]
        )
    }

    private static func createIceThrone() -> DungeonRoom {
        let width: CGFloat = 2400
        let height: CGFloat = 1600

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "ice_throne",
            width: width,
            height: height,
            enemies: [],
            obstacles: [
                Obstacle(
                    id: RandomUtils.generateId(),
                    x: width - 300, y: height / 2 - 100,
                    width: 200, height: 200,
                    color: "#a0d8ef",
                    type: "ice_throne"
                )
            ],
            effectZones: [],
            hazards: [],
            backgroundColor: "#051525",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 2, direction: "left")
            ],
            isBossRoom: true,
            bossId: "frost_titan"
        )
    }

    // MARK: - Volcanic Progression

    private static func createVolcanicProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createVolcanicForge(index: 1),
            createVolcanicForge(index: 2),
            createLavaThrone()
        ]
    }

    private static func createVolcanicForge(index: Int) -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []

        // Rock formations
        for _ in 0..<6 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 400...(width - 400)),
                y: CGFloat.random(in: 400...(height - 400)),
                width: 100, height: 100,
                color: "#4a3030",
                type: "rock"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "volcanic_forge_\(index)",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "volcanic", count: 25 + index * 5),
            obstacles: obstacles,
            effectZones: [],
            hazards: createLavaHazards(width: width, height: height),
            backgroundColor: "#1a0a0a",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: index - 1, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: index + 1, direction: "right")
            ]
        )
    }

    private static func createLavaThrone() -> DungeonRoom {
        let width: CGFloat = 2400
        let height: CGFloat = 1600

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "lava_throne",
            width: width,
            height: height,
            enemies: [],
            obstacles: [],
            effectZones: [],
            hazards: createLavaHazards(width: width, height: height),
            backgroundColor: "#200505",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 2, direction: "left")
            ],
            isBossRoom: true,
            bossId: "inferno_lord"
        )
    }

    // MARK: - Heist Progression

    private static func createHeistProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createSecurityEntrance(),
            createVaultCorridor(),
            createServerRoom()
        ]
    }

    private static func createSecurityEntrance() -> DungeonRoom {
        let width: CGFloat = 3600
        let height: CGFloat = 2000

        var obstacles: [Obstacle] = []

        // Security desks
        for i in 0..<3 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 600 + CGFloat(i) * 900,
                y: height / 2,
                width: 150, height: 80,
                color: "#3a3a4a",
                type: "desk"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "security_entrance",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "heist", count: 20),
            obstacles: obstacles,
            effectZones: [],
            hazards: createLaserFences(width: width, height: height),
            backgroundColor: "#0a0a15",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 0, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: 2, direction: "right")
            ],
            securityCameras: createSecurityCameras(width: width, height: height)
        )
    }

    private static func createVaultCorridor() -> DungeonRoom {
        let width: CGFloat = 4000
        let height: CGFloat = 1200

        var obstacles: [Obstacle] = []

        // Vault doors along corridor
        for i in 0..<4 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 800 + CGFloat(i) * 800,
                y: 200,
                width: 100, height: 150,
                color: "#5a5a6a",
                type: "vault_door"
            ))
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 800 + CGFloat(i) * 800,
                y: height - 350,
                width: 100, height: 150,
                color: "#5a5a6a",
                type: "vault_door"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "vault_corridor",
            width: width,
            height: height,
            enemies: generateRoomEnemies(roomType: "heist", count: 30),
            obstacles: obstacles,
            effectZones: [],
            hazards: createLaserFences(width: width, height: height),
            backgroundColor: "#0a0a12",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 1, direction: "left"),
                Door(id: RandomUtils.generateId(), x: width - 50, y: height / 2 - 40, width: 50, height: 80, locked: true, targetRoomIndex: 3, direction: "right")
            ],
            securityCameras: createSecurityCameras(width: width, height: height)
        )
    }

    private static func createServerRoom() -> DungeonRoom {
        let width: CGFloat = 2400
        let height: CGFloat = 1600

        var obstacles: [Obstacle] = []

        // Server racks
        for i in 0..<3 {
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 400 + CGFloat(i) * 600,
                y: 400,
                width: 80, height: 200,
                color: "#2a2a3a",
                type: "server_rack"
            ))
            obstacles.append(Obstacle(
                id: RandomUtils.generateId(),
                x: 400 + CGFloat(i) * 600,
                y: height - 600,
                width: 80, height: 200,
                color: "#2a2a3a",
                type: "server_rack"
            ))
        }

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "server_room",
            width: width,
            height: height,
            enemies: [],
            obstacles: obstacles,
            effectZones: [],
            hazards: [],
            backgroundColor: "#050510",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 2, direction: "left")
            ],
            isBossRoom: true,
            bossId: "cyberboss"
        )
    }

    // MARK: - Void Raid Progression

    private static func createVoidRaidProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createVoidHarbingerArena()
        ]
    }

    private static func createVoidHarbingerArena() -> DungeonRoom {
        let width: CGFloat = 3000
        let height: CGFloat = 3000

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "void_harbinger_arena",
            width: width,
            height: height,
            enemies: [],
            obstacles: [],
            effectZones: [],
            hazards: [],
            backgroundColor: "#0a0015",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 0, direction: "left")
            ],
            isBossRoom: true,
            bossId: "void_harbinger"
        )
    }

    // MARK: - Cyberboss Progression

    private static func createCyberbossProgression() -> [DungeonRoom] {
        return [
            createPreRoom(),
            createCyberNexusArena()
        ]
    }

    private static func createCyberNexusArena() -> DungeonRoom {
        let width: CGFloat = 2400
        let height: CGFloat = 1600

        return DungeonRoom(
            id: RandomUtils.generateId(),
            type: "cyber_nexus_arena",
            width: width,
            height: height,
            enemies: [],
            obstacles: [],
            effectZones: [],
            hazards: [],
            backgroundColor: "#050515",
            decorations: [],
            doors: [
                Door(id: RandomUtils.generateId(), x: 0, y: height / 2 - 40, width: 50, height: 80, locked: false, targetRoomIndex: 0, direction: "left")
            ],
            isBossRoom: true,
            bossId: "cyberboss"
        )
    }

    // MARK: - Helper Functions

    private static func createPreRoomObstacles(width: CGFloat, height: CGFloat) -> [Obstacle] {
        return [
            Obstacle(
                id: RandomUtils.generateId(),
                x: 100, y: 100,
                width: 80, height: 80,
                color: "#4a4a5a",
                type: "crate"
            ),
            Obstacle(
                id: RandomUtils.generateId(),
                x: 100, y: height - 180,
                width: 80, height: 80,
                color: "#4a4a5a",
                type: "crate"
            )
        ]
    }

    private static func createPreRoomDecorations(width: CGFloat, height: CGFloat) -> [Decoration] {
        var decorations: [Decoration] = []

        // Torches along walls
        for i in 0..<4 {
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat(i) * (width / 4) + 50,
                y: 50,
                type: "torch",
                color: "#ff8800"
            ))
            decorations.append(Decoration(
                id: RandomUtils.generateId(),
                x: CGFloat(i) * (width / 4) + 50,
                y: height - 50,
                type: "torch",
                color: "#ff8800"
            ))
        }

        return decorations
    }

    private static func generateRoomEnemies(roomType: String, count: Int) -> [EnemySpawn] {
        var spawns: [EnemySpawn] = []

        for _ in 0..<count {
            let enemyType: String
            let rand = Double.random(in: 0...1)

            switch roomType {
            case "cathedral", "garden", "crypt":
                if rand < 0.5 {
                    enemyType = "basic"
                } else if rand < 0.8 {
                    enemyType = "fast"
                } else {
                    enemyType = "tank"
                }
            case "frozen":
                if rand < 0.4 {
                    enemyType = "basic"
                } else if rand < 0.7 {
                    enemyType = "fast"
                } else {
                    enemyType = "tank"
                }
            case "volcanic":
                if rand < 0.3 {
                    enemyType = "basic"
                } else if rand < 0.6 {
                    enemyType = "fast"
                } else {
                    enemyType = "tank"
                }
            case "heist":
                if rand < 0.6 {
                    enemyType = "fast"
                } else {
                    enemyType = "basic"
                }
            default:
                enemyType = "basic"
            }

            spawns.append(EnemySpawn(
                id: RandomUtils.generateId(),
                type: enemyType,
                delay: Double.random(in: 0...5)
            ))
        }

        return spawns
    }

    // MARK: - Hazard Creators

    private static func createCorruptionHazards(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        for _ in 0..<5 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 200...(width - 200)),
                y: CGFloat.random(in: 200...(height - 200)),
                width: 100, height: 100,
                damage: 10,
                damageType: "corruption",
                type: "corruption_pool"
            ))
        }

        return hazards
    }

    private static func createPoisonHazards(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        for _ in 0..<8 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 200...(width - 200)),
                y: CGFloat.random(in: 200...(height - 200)),
                width: 80, height: 80,
                damage: 5,
                damageType: "poison",
                type: "poison_puddle"
            ))
        }

        return hazards
    }

    private static func createCryptHazards(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        for _ in 0..<4 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 300...(width - 300)),
                y: CGFloat.random(in: 300...(height - 300)),
                width: 60, height: 60,
                damage: 15,
                damageType: "necrotic",
                type: "bone_spike"
            ))
        }

        return hazards
    }

    private static func createFrozenHazards(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        for _ in 0..<6 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 200...(width - 200)),
                y: CGFloat.random(in: 200...(height - 200)),
                width: 120, height: 120,
                damage: 8,
                damageType: "cold",
                type: "ice_patch"
            ))
        }

        return hazards
    }

    private static func createFrozenEffectZones(width: CGFloat, height: CGFloat) -> [ArenaEffectZone] {
        var zones: [ArenaEffectZone] = []

        // Slow zones from ice
        for _ in 0..<3 {
            zones.append(ArenaEffectZone(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 300...(width - 300)),
                y: CGFloat.random(in: 300...(height - 300)),
                width: 150, height: 150,
                effects: ["speedMultiplier": 0.6],
                type: "ice_slow"
            ))
        }

        return zones
    }

    private static func createLavaHazards(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        for _ in 0..<10 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: CGFloat.random(in: 200...(width - 200)),
                y: CGFloat.random(in: 200...(height - 200)),
                width: 100, height: 100,
                damage: 20,
                damageType: "fire",
                type: "lava_pool"
            ))
        }

        return hazards
    }

    private static func createLaserFences(width: CGFloat, height: CGFloat) -> [Hazard] {
        var hazards: [Hazard] = []

        // Moving laser fences
        for i in 0..<3 {
            hazards.append(Hazard(
                id: RandomUtils.generateId(),
                x: 800 + CGFloat(i) * 800,
                y: 0,
                width: 10, height: height,
                damage: 40,
                damageType: "laser",
                type: "laser_fence",
                isMoving: true,
                moveSpeed: 100 + CGFloat(i) * 20,
                moveDirection: i % 2 == 0 ? "down" : "up"
            ))
        }

        return hazards
    }

    private static func createSecurityCameras(width: CGFloat, height: CGFloat) -> [SecurityCamera] {
        return [
            SecurityCamera(
                id: RandomUtils.generateId(),
                x: 400, y: 100,
                detectionRadius: 300,
                detectionAngle: 60,
                rotation: 180,
                rotationSpeed: 30,
                isTriggered: false,
                cooldown: 30
            ),
            SecurityCamera(
                id: RandomUtils.generateId(),
                x: width - 400, y: 100,
                detectionRadius: 350,
                detectionAngle: 60,
                rotation: 180,
                rotationSpeed: -30,
                isTriggered: false,
                cooldown: 30
            ),
            SecurityCamera(
                id: RandomUtils.generateId(),
                x: width / 2, y: height - 100,
                detectionRadius: 300,
                detectionAngle: 60,
                rotation: 0,
                rotationSpeed: 25,
                isTriggered: false,
                cooldown: 30
            )
        ]
    }

    // MARK: - Room Validation

    static func validateRoomSpacing(room: DungeonRoom) -> Bool {
        let totalArea = room.width * room.height
        var obstacleArea: CGFloat = 0

        for obstacle in room.obstacles {
            obstacleArea += obstacle.width * obstacle.height
        }

        let density = obstacleArea / totalArea

        // Ensure < 25% obstacle density
        if density > 0.25 {
            return false
        }

        // Check center area is clear (spawn area)
        let centerX = room.width / 2
        let centerY = room.height / 2
        let clearRadius: CGFloat = 200

        for obstacle in room.obstacles {
            let obstacleCenter = CGPoint(
                x: obstacle.x + obstacle.width / 2,
                y: obstacle.y + obstacle.height / 2
            )
            let distance = MathUtils.distance(
                from: CGPoint(x: centerX, y: centerY),
                to: obstacleCenter
            )

            if distance < clearRadius {
                return false
            }
        }

        return true
    }
}

// MARK: - Hazard Extension

// Extend Hazard with movement properties for laser fences
extension Hazard {
    init(id: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
         damage: CGFloat, damageType: String, type: String,
         isMoving: Bool = false, moveSpeed: CGFloat = 0, moveDirection: String = "") {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.damage = damage
        self.damageType = damageType
        self.type = type
    }
}
