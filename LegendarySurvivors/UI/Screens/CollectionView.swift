import SwiftUI

// MARK: - Collection View

struct CollectionView: View {
    @ObservedObject var appState = AppState.shared
    let onBack: () -> Void

    @State private var selectedCategory: String = "all"
    @State private var selectedRarity: String = "all"

    private let categories = ["all", "weapon", "powerup", "arena"]
    private let rarities = ["all", "common", "rare", "epic", "legendary"]

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            let columns = isPortrait ? 3 : 5

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 15) {
                    // Header
                    HStack {
                        Button(action: {
                            HapticsService.shared.play(.light)
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text("COLLECTION")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.cyan)

                        Spacer()

                        // Progress
                        Text("\(unlockedCount)/\(totalCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)

                            Rectangle()
                                .fill(Color.cyan)
                                .frame(width: geo.size.width * progressPercent, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal)

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                FilterChip(
                                    title: category.capitalized,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Rarity filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(rarities, id: \.self) { rarity in
                                FilterChip(
                                    title: rarity.capitalized,
                                    isSelected: selectedRarity == rarity,
                                    color: rarityColor(rarity)
                                ) {
                                    selectedRarity = rarity
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Collection grid
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                            spacing: 10
                        ) {
                            ForEach(filteredItems, id: \.id) { item in
                                CollectionItemCard(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var allItems: [CollectionDisplayItem] {
        var items: [CollectionDisplayItem] = []
        let config = GameConfigLoader.shared.config

        // Weapons (also serve as towers in TD mode)
        if let weapons = config?.weapons {
            for (id, weapon) in weapons {
                items.append(CollectionDisplayItem(
                    id: id,
                    name: weapon.name,
                    towerName: weapon.towerName,  // Show tower name for unified collection
                    category: "weapon",
                    rarity: weapon.rarity,
                    icon: weapon.icon,
                    isUnlocked: appState.currentPlayer.unlocks.weapons.contains(id),
                    level: appState.currentPlayer.weaponLevels[id]
                ))
            }
        }

        // Powerups
        if let powerups = config?.powerups {
            for (id, powerup) in powerups {
                items.append(CollectionDisplayItem(
                    id: id,
                    name: powerup.name,
                    towerName: nil,
                    category: "powerup",
                    rarity: powerup.rarity,
                    icon: powerup.icon,
                    isUnlocked: appState.currentPlayer.unlocks.powerups.contains(id),
                    level: appState.currentPlayer.powerupLevels[id]
                ))
            }
        }

        // Arenas (also serve as TD maps)
        if let arenas = config?.arenas {
            for (id, arena) in arenas {
                items.append(CollectionDisplayItem(
                    id: id,
                    name: arena.name,
                    towerName: nil,
                    category: "arena",
                    rarity: arena.rarity,
                    icon: "🏟️",
                    isUnlocked: appState.currentPlayer.unlocks.arenas.contains(id),
                    level: nil
                ))
            }
        }

        return items.sorted { $0.name < $1.name }
    }

    private var filteredItems: [CollectionDisplayItem] {
        allItems.filter { item in
            let categoryMatch = selectedCategory == "all" || item.category == selectedCategory
            let rarityMatch = selectedRarity == "all" || item.rarity == selectedRarity
            return categoryMatch && rarityMatch
        }
    }

    private var unlockedCount: Int {
        allItems.filter { $0.isUnlocked }.count
    }

    private var totalCount: Int {
        allItems.count
    }

    private var progressPercent: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(unlockedCount) / CGFloat(totalCount)
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .yellow
        default: return .white
        }
    }
}

// MARK: - Collection Display Item

struct CollectionDisplayItem: Identifiable {
    let id: String
    let name: String
    let towerName: String?  // For weapons that also serve as towers
    let category: String
    let rarity: String
    let icon: String
    let isUnlocked: Bool
    let level: Int?
}

// MARK: - Collection Item Card

struct CollectionItemCard: View {
    let item: CollectionDisplayItem

    private var rarityColor: Color {
        switch item.rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .yellow
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Icon
            Text(item.icon)
                .font(.system(size: 28))
                .opacity(item.isUnlocked ? 1 : 0.3)
                .blur(radius: item.isUnlocked ? 0 : 2)

            // Name (show tower name for weapons)
            if item.isUnlocked {
                if let towerName = item.towerName {
                    // Weapon with tower capability
                    VStack(spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(towerName)
                            .font(.system(size: 7))
                            .foregroundColor(.purple)
                            .lineLimit(1)
                    }
                } else {
                    Text(item.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            } else {
                Text("???")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            // Level badge
            if let level = item.level, item.isUnlocked {
                Text("Lv.\(level)")
                    .font(.system(size: 8))
                    .foregroundColor(.cyan)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(item.isUnlocked ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            item.isUnlocked ? rarityColor.opacity(0.5) : Color.gray.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
        .overlay(
            // Locked overlay
            Group {
                if !item.isUnlocked {
                    ZStack {
                        Color.black.opacity(0.5)
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .cornerRadius(10)
                }
            }
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .cyan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.1))
                )
        }
    }
}

#Preview {
    CollectionView(onBack: {})
}
