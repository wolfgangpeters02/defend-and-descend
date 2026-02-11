import Foundation
import CoreGraphics

struct BossMilestones {
    var announced75: Bool = false
    var announced50: Bool = false
    var announced25: Bool = false
}

// MARK: - Boss Mechanics

struct DamagePuddle {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var createdAt: TimeInterval
    var lifetime: TimeInterval
    var fadeStartTime: TimeInterval
    var fadeDuration: TimeInterval
}

struct BossLaser {
    var id: String
    var bossId: String
    var angle: CGFloat
    var length: CGFloat
    var damage: CGFloat
    var rotationSpeed: CGFloat
}

// MARK: - WoW Raid Mechanics

struct VoidZone {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var telegraphDuration: TimeInterval
    var createdAt: TimeInterval
    var activated: Bool
    var activationTime: TimeInterval
}

struct Pylon {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var health: CGFloat
    var maxHealth: CGFloat
    var size: CGFloat
    var destroyed: Bool
    var lastBeamTime: TimeInterval
}

struct VoidRift {
    var id: String
    var centerX: CGFloat
    var centerY: CGFloat
    var angle: CGFloat
    var length: CGFloat
    var width: CGFloat
    var damage: CGFloat
    var rotationSpeed: CGFloat
}

struct GravityWell {
    var id: String
    var x: CGFloat
    var y: CGFloat
    var pullRadius: CGFloat
    var pullStrength: CGFloat
    var createdAt: TimeInterval
    var lifetime: TimeInterval
}

struct MeteorStrike {
    var id: String
    var targetX: CGFloat
    var targetY: CGFloat
    var radius: CGFloat
    var damage: CGFloat
    var telegraphDuration: TimeInterval
    var createdAt: TimeInterval
    var impactTime: TimeInterval
    var impacted: Bool
}

struct ArenaWall {
    var currentRadius: CGFloat
    var shrinkRate: CGFloat
    var minRadius: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat
    var damage: CGFloat
}
