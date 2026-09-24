import Foundation

enum DeckApproach: Int, CaseIterable {
    case guardHP, pressure, burst
    var title: String { ["Guard", "Pressure", "Burst"][rawValue] }

    func advice(for deck: [CardKind]) -> String {
        switch self {
        case .guardHP:
            if deck.contains(.shield) { return "Keep 1 energy for Time Shield: 4 shield now can buy time for a growing unit." }
            if deck.contains(.guardian) { return "Gear Guard adds 2 shield per active attack. Use that cover to buy time for your delayed cards." }
            return "No shield cards in this deck. Waiting for a bigger hit puts your remaining HP on the line."
        case .pressure:
            if let unit = deck.filter({ $0.isUnit }).min(by: { $0.cost < $1.cost }) {
                return "\(unit.name) costs \(unit.cost) energy. Play in Present for an attack this turn, without waiting for a multiplier."
            }
            return "Use damage spells in Present to finish an enemy before it can retaliate. Save enough energy for the play."
        case .burst:
            if deck.contains(.surge) { return "Energy Storm in Future hits for 12 base damage after the enemy acts. Budget for surviving that attack first." }
            if let unit = deck.filter({ $0.isUnit }).max(by: { $0.attack < $1.attack }) {
                return "\(unit.name) in Future opens with \(unit.attack * 2) base attack. You must survive a turn before it can strike."
            }
            return "Future doubles a spell's effect after the enemy acts. Extra energy still cannot exceed the cap of 5."
        }
    }
}

extension CardKind {
    var tacticalRole: String {
        switch self {
        case .seed: return "Growth play"
        case .dragon: return "Low-cost pressure"
        case .shield: return "Protect the run"
        case .rewind: return "Reposition"
        case .spark: return "Energy reserve"
        case .guardian: return "Defensive engine"
        case .oak, .elder: return "Heavy commitment"
        case .surge: return "Burst finisher"
        }
    }
    var immediatePayoff: String {
        if isUnit { return "\(attack) ATK" }
        switch self {
        case .shield: return "+4 SHIELD"
        case .spark: return "+1 ENERGY"
        case .surge: return "6 DAMAGE"
        default: return "RECALL"
        }
    }
    var delayedPayoff: String {
        if isUnit { return "\(attack * 2) ATK" }
        switch self {
        case .shield: return "+8 SHIELD"
        case .spark: return "+2 ENERGY"
        case .surge: return "12 DAMAGE"
        default: return "N/A"
        }
    }
    var tradeoff: String {
        switch self {
        case .shield: return "Future doubles cover, but leaves the next enemy hit unprotected by this card. Present protects immediately."
        case .spark: return "Future grants more energy next turn; Present funds a play now. Energy above 5 is lost."
        case .rewind: return "Present only. Reclaim a slot, but lose that unit's growth and pay its cost again to replay it."
        case .surge: return "Take 6 base damage now, or survive the enemy's attack for 12 later. Enemy armor may reduce either hit."
        case .guardian: return "Future doubles only the first attack, not its 2 shield. Waiting also delays that protection. Base attack shown."
        default: return "Future doubles only the first attack after a turn of waiting. Past instead grows attack by +2 permanently. Base attack shown."
        }
    }
}
