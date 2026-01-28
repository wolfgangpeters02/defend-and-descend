import SwiftUI
import SpriteKit

// MARK: - Tower Gallery View
// Debug view to preview all tower visuals without playing the game

struct TowerGalleryView: View {
    @State private var selectedArchetype: String = "all"
    @State private var showAnimations = true
    @State private var zoomLevel: CGFloat = 1.0

    private let archetypes = [
        "all", "projectile", "artillery", "frost", "magic",
        "beam", "tesla", "pyro", "legendary", "multishot", "execute"
    ]

    var body: some View {
        ZStack {
            // Background
            Color(hex: "0a0a0f").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Archetype filter
                archetypeFilter

                // Tower gallery
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
                    ], spacing: 24) {
                        ForEach(filteredTowers, id: \.id) { tower in
                            TowerPreviewCell(tower: tower, showAnimations: showAnimations)
                        }
                    }
                    .padding(20)
                }

                // Deck card preview section
                deckCardPreview
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("TOWER VISUAL GALLERY")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("AAA Code-Only Tower Designs")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)

            Toggle("Animations", isOn: $showAnimations)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "00d4ff") ?? .cyan))
                .frame(width: 150)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(hex: "161b22"))
    }

    private var archetypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(archetypes, id: \.self) { archetype in
                    Button(action: { selectedArchetype = archetype }) {
                        Text(archetype.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedArchetype == archetype ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedArchetype == archetype
                                    ? Color(hex: "00d4ff") ?? .cyan
                                    : Color(hex: "2a3a4a") ?? .gray
                            )
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "0d1117"))
    }

    private var deckCardPreview: some View {
        VStack(spacing: 8) {
            Text("DECK CARD PREVIEW")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sampleWeapons, id: \.id) { weapon in
                        VStack(spacing: 4) {
                            TowerDeckCardPreview(weapon: weapon)
                            Text(weapon.id)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(hex: "161b22"))
    }

    private var filteredTowers: [TowerPreviewData] {
        if selectedArchetype == "all" {
            return allTowers
        }
        return allTowers.filter { $0.archetype == selectedArchetype }
    }

    private var allTowers: [TowerPreviewData] {
        [
            // Protocols (Unified Weapon/Tower System)
            TowerPreviewData(id: "kernel_pulse", name: "Kernel Pulse", archetype: "projectile", rarity: "common", color: "00d4ff"),
            TowerPreviewData(id: "burst_protocol", name: "Burst Protocol", archetype: "artillery", rarity: "common", color: "f97316"),
            TowerPreviewData(id: "trace_route", name: "Trace Route", archetype: "projectile", rarity: "rare", color: "00d4ff"),
            TowerPreviewData(id: "ice_shard", name: "Ice Shard", archetype: "frost", rarity: "rare", color: "06b6d4"),
            TowerPreviewData(id: "fork_bomb", name: "Fork Bomb", archetype: "multishot", rarity: "epic", color: "8b5cf6"),
            TowerPreviewData(id: "root_access", name: "Root Access", archetype: "beam", rarity: "epic", color: "ef4444"),
            TowerPreviewData(id: "overflow", name: "Overflow", archetype: "tesla", rarity: "legendary", color: "22d3ee"),
            TowerPreviewData(id: "null_pointer", name: "Null Pointer", archetype: "execute", rarity: "legendary", color: "ef4444"),
        ]
    }

    private var sampleWeapons: [WeaponPreviewData] {
        [
            WeaponPreviewData(id: "kernel_pulse", rarity: "common"),
            WeaponPreviewData(id: "burst_protocol", rarity: "common"),
            WeaponPreviewData(id: "trace_route", rarity: "rare"),
            WeaponPreviewData(id: "fork_bomb", rarity: "epic"),
            WeaponPreviewData(id: "null_pointer", rarity: "legendary"),
        ]
    }
}

// MARK: - Tower Preview Data

struct TowerPreviewData: Identifiable {
    let id: String
    let name: String
    let archetype: String
    let rarity: String
    let color: String
}

// MARK: - Tower Preview Cell

struct TowerPreviewCell: View {
    let tower: TowerPreviewData
    let showAnimations: Bool

    var body: some View {
        VStack(spacing: 8) {
            // SpriteKit preview
            SpriteView(scene: createPreviewScene(), options: showAnimations ? [.allowsTransparency] : [.allowsTransparency, .ignoresSiblingOrder])
                .frame(width: 100, height: 100)
                .background(Color(hex: "0d1117"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rarityColor.opacity(0.5), lineWidth: 2)
                )

            // Tower info
            VStack(spacing: 2) {
                Text(tower.name)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(tower.archetype.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(archetypeColor)

                Text(tower.rarity.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(rarityColor)
            }
        }
    }

    private var rarityColor: Color {
        RarityColors.color(for: tower.rarity)
    }

    private var archetypeColor: Color {
        Color(hex: tower.color) ?? .cyan
    }

    private func createPreviewScene() -> SKScene {
        let scene = TowerPreviewScene(
            weaponType: tower.id,
            color: tower.color,
            rarity: tower.rarity,
            animated: showAnimations
        )
        scene.scaleMode = .aspectFit
        scene.backgroundColor = UIColor(hex: "0d1117") ?? .black
        return scene
    }
}

// MARK: - Tower Preview Scene (SpriteKit)

class TowerPreviewScene: SKScene {
    private let weaponType: String
    private let colorHex: String
    private let rarity: String
    private let animated: Bool

    init(weaponType: String, color: String, rarity: String, animated: Bool) {
        self.weaponType = weaponType
        self.colorHex = color
        self.rarity = rarity
        self.animated = animated
        super.init(size: CGSize(width: 100, height: 100))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(hex: "0d1117") ?? .black

        let towerColor = UIColor(hex: colorHex) ?? .cyan

        let towerNode = TowerVisualFactory.createTowerNode(
            weaponType: weaponType,
            color: towerColor,
            range: 80,
            mergeLevel: 1,
            level: 1,
            damage: 10,
            attackSpeed: 1.0,
            projectileCount: 1,
            rarity: rarity
        )

        towerNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        towerNode.setScale(0.8)
        addChild(towerNode)

        if !animated {
            towerNode.isPaused = true
        }
    }
}

// MARK: - Deck Card Preview (Simplified)

struct TowerDeckCardPreview: View {
    let weapon: WeaponPreviewData

    private var rarityColor: Color {
        RarityColors.color(for: weapon.rarity)
    }

    private var archetypeColor: Color {
        switch weapon.id.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return Color(hex: "00d4ff") ?? .cyan
        case "cannon", "bomb", "burst_protocol":
            return Color(hex: "f97316") ?? .orange
        case "ice_shard":
            return Color(hex: "06b6d4") ?? .cyan
        case "staff", "wand":
            return Color(hex: "a855f7") ?? .purple
        case "laser", "root_access":
            return Color(hex: "ef4444") ?? .red
        case "lightning", "overflow":
            return Color(hex: "22d3ee") ?? .cyan
        case "flamethrower":
            return Color(hex: "f97316") ?? .orange
        case "excalibur":
            return Color(hex: "f59e0b") ?? .orange
        case "fork_bomb":
            return Color(hex: "8b5cf6") ?? .purple
        case "null_pointer":
            return Color(hex: "ef4444") ?? .red
        default:
            return .cyan
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            archetypeColor.opacity(0.4),
                            rarityColor.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)

            Image(systemName: iconForWeapon(weapon.id))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [rarityColor, archetypeColor.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: archetypeColor.opacity(0.4), radius: 6)
    }

    private func iconForWeapon(_ weaponType: String) -> String {
        switch weaponType.lowercased() {
        case "bow", "crossbow", "trace_route", "kernel_pulse":
            return "scope"
        case "wand", "staff":
            return "wand.and.stars"
        case "cannon":
            return "cylinder.split.1x2.fill"
        case "bomb", "burst_protocol":
            return "burst.fill"
        case "ice_shard":
            return "snowflake"
        case "laser", "root_access":
            return "rays"
        case "lightning", "overflow":
            return "bolt.horizontal.fill"
        case "flamethrower":
            return "flame.fill"
        case "excalibur":
            return "sparkle"
        case "fork_bomb":
            return "arrow.triangle.branch"
        case "null_pointer":
            return "exclamationmark.triangle.fill"
        default:
            return "square.fill"
        }
    }
}

// MARK: - Simple Weapon Preview Data

struct WeaponPreviewData: Identifiable {
    let id: String
    let rarity: String
}

// MARK: - Preview Provider

#Preview {
    TowerGalleryView()
}
