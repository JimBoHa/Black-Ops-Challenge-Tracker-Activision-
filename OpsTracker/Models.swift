import Foundation

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case camo = "Camos"
    case callingCard = "Calling Cards"
    case daily = "Daily"
    case weekly = "Weekly"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .camo: "paintpalette.fill"
        case .callingCard: "rectangle.stack.fill"
        case .daily: "sun.max.fill"
        case .weekly: "calendar"
        }
    }
}

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case multiplayer = "Multiplayer"
    case zombies = "Zombies"
    case warzone = "Warzone"
    case campaign = "Campaign"
    var id: String { rawValue }
}

struct Challenge: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var kind: ChallengeKind
    var mode: GameMode
    var group: String
    var current: Int
    var target: Int
    var reward: String
    var expiresAt: Date?
    var tracked: Bool

    var isComplete: Bool { current >= target }
    var progress: Double { target > 0 ? min(Double(current) / Double(target), 1) : 0 }
}

enum SampleCatalog {
    static let challenges: [Challenge] = [
        Challenge(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Military Camo I", detail: "Get 100 eliminations with this weapon.", kind: .camo, mode: .multiplayer, group: "Assault Rifles", current: 42, target: 100, reward: "Granite", expiresAt: nil, tracked: true),
        Challenge(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Special Camo", detail: "Get 30 eliminations shortly after sprinting.", kind: .camo, mode: .multiplayer, group: "Assault Rifles", current: 8, target: 30, reward: "Special Camo", expiresAt: nil, tracked: false),
        Challenge(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, title: "Undead Hunter", detail: "Eliminate 1,000 zombies with critical hits.", kind: .callingCard, mode: .zombies, group: "Career", current: 680, target: 1000, reward: "Undead Hunter Calling Card", expiresAt: nil, tracked: true),
        Challenge(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, title: "Win Matches", detail: "Win 2 Multiplayer matches.", kind: .daily, mode: .multiplayer, group: "Today", current: 1, target: 2, reward: "2,500 XP", expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: .now), tracked: true),
        Challenge(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, title: "Team Player", detail: "Earn 25 objective medals.", kind: .daily, mode: .multiplayer, group: "Today", current: 17, target: 25, reward: "2,500 XP", expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: .now), tracked: false),
        Challenge(id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, title: "Weekly Operator", detail: "Complete any 6 challenges this week.", kind: .weekly, mode: .multiplayer, group: "Season 5 · Week 1", current: 3, target: 6, reward: "Grid-Breaker Kit", expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now), tracked: true),
        Challenge(id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!, title: "Critical Cleanup", detail: "Get 500 critical eliminations in Zombies.", kind: .weekly, mode: .zombies, group: "Season 5 · Week 1", current: 221, target: 500, reward: "5,000 XP", expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now), tracked: false)
    ]
}
