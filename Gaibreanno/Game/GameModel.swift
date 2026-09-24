import Foundation

enum CardKind: String, Codable, CaseIterable {
    case seed, dragon, shield, rewind, spark, guardian, oak, elder, surge

    static let starter: [CardKind] = [.seed, .dragon, .shield, .spark, .guardian, .rewind]
    var name: String {
        switch self {
        case .seed: return "Seed Turret"
        case .dragon: return "Clock Drake"
        case .shield: return "Time Shield"
        case .rewind: return "Rewind"
        case .spark: return "Energy Spark"
        case .guardian: return "Gear Guard"
        case .oak: return "Oak Turret"
        case .elder: return "Time Drake"
        case .surge: return "Energy Storm"
        }
    }
    var cost: Int {
        switch self {
        case .spark: return 0
        case .dragon, .shield, .rewind: return 1
        case .seed, .guardian, .surge: return 2
        case .oak, .elder: return 3
        }
    }
    var art: Int {
        switch self {
        case .seed: return 0
        case .dragon: return 1
        case .shield: return 2
        case .rewind: return 3
        case .spark: return 4
        case .surge: return 15
        case .guardian: return 5
        case .oak: return 7
        case .elder: return 8
        }
    }
    var isUnit: Bool { [.seed, .dragon, .guardian, .oak, .elder].contains(self) }
    var acquisition: String {
        CardKind.starter.contains(self) ? "Starter card. Available from your first battle." : "Choose an unowned card after your first Normal clear of levels 2, 4 and 6."
    }
    var pairingTip: String {
        switch self {
        case .seed: return "Grow in the Past. Use Time Shield to survive the wait."
        case .dragon: return "A cheap opening unit for the Present. Try the Future to pierce the beetle's armor."
        case .shield: return "Prepare in the Future before a heavy hit. Use the Present for urgent protection."
        case .rewind: return "Recall your leftmost unit to free a slot for a stronger card. Save energy to replay it."
        case .spark: return "Gain energy before playing costly units. Also helps on low-energy levels."
        case .guardian: return "Pair with Time Shield to buy time for a strong unit growing in the Past."
        case .oak: return "High attack helps against damage reduction. Use the Future for a burst hit."
        case .elder: return "Grow in the Past. Pair with a cheap shield and spark for a safe opening."
        case .surge: return "Let Gear Guard buy time for double damage in the Future. Spells bypass the drought's unit resistance."
        }
    }
    var attack: Int {
        switch self {
        case .seed, .dragon: return 2
        case .guardian: return 1
        case .oak: return 4
        case .elder: return 5
        default: return 0
        }
    }
    var keyword: String {
        switch self {
        case .seed, .oak: return "Grow"
        case .dragon, .elder: return "Evolve"
        case .shield: return "Shield +4"
        case .rewind: return "Recall"
        case .spark: return "Energy +1"
        case .guardian: return "Shield +2"
        case .surge: return "Hit 6"
        }
    }
    var detail: String {
        switch self {
        case .seed, .dragon, .oak, .elder:
            return "Attacks for \(attack) each turn. Past: waits one turn, then gains +2 attack. Future: waits one turn, then doubles its first attack."
        case .guardian:
            return "Attacks for 1 and grants 2 shield each turn. Past: waits, then gains +2 attack. Future: waits, then doubles its first attack."
        case .shield: return "Gain 4 shield now in the Present, or 8 shield at the start of next turn in the Future. Shield absorbs enemy damage."
        case .rewind: return "Return your leftmost unit to your hand. Replay costs energy and resets growth. Present only."
        case .spark: return "Gain 1 energy now in the Present, or 2 extra energy at the start of next turn in the Future. Maximum energy: 5."
        case .surge: return "Deal 6 damage now in the Present, or 12 damage at the start of next turn in the Future."
        }
    }
}

enum TimeLane: Int, CaseIterable, Codable {
    case past, present, future
    var title: String { ["Past", "Present", "Future"][rawValue] }
    var hint: String { ["Wait · Grow", "Act now", "Wait · Double"][rawValue] }
}

enum EncounterRule { case training, bark, shell, charge, drought, boss }

struct Stage {
    let name: String
    let enemy: String
    let health: Int
    let attack: Int
    let rule: EncounterRule
    let lesson: String
    let briefing: String
    let challenge: String
    var hardModifier: String {
        switch rule {
        case .training: return "Tight Start: begin with only 2 energy."
        case .bark: return "Regrowth: the enemy heals 2 HP after each attack."
        case .shell: return "Present Lock: no cards can enter the Present on odd turns."
        case .charge: return "Shield Break: lose 2 shield before each even-turn attack."
        case .drought: return "Deep Drought: recover only 2 energy each turn."
        case .boss: return "Time Shock: after every third enemy attack, your Present unit returns to your hand."
        }
    }
    var rewardMilestone: Bool { [.bark, .charge, .boss].contains(rule) }
    static let all = [
        Stage(name: "01 · Forest Alarm", enemy: "Clock Scout", health: 20, attack: 4, rule: .training,
              lesson: "First Steps", briefing: "Attack +2 every third turn. Play Clock Drake in the Present to attack now. Shield blocks damage.", challenge: "Win within 5 turns"),
        Stage(name: "02 · Ironbark", enemy: "Ironbark", health: 24, attack: 4, rule: .bark,
              lesson: "Past · Growth", briefing: "Ungrown units deal 1 less damage. Growth, Future burst and spells bypass bark. Try Seed Turret in the Past.", challenge: "Win with a grown unit"),
        Stage(name: "03 · Clock Beetle", enemy: "Clock Beetle", health: 28, attack: 4, rule: .shell,
              lesson: "Future · Timing", briefing: "Armor 2 on odd turns; none on even turns. A Future unit's first double hit ignores armor.", challenge: "Trigger a Future unit burst"),
        Stage(name: "04 · Hammer Post", enemy: "Hammer Clock", health: 32, attack: 2, rule: .charge,
              lesson: "Shield · Defense", briefing: "Attacks for 2 on odd turns and 8 on even turns. Prepare a shield in the Future before the heavy hit.", challenge: "Block at least 8 damage"),
        Stage(name: "05 · Energy Drought", enemy: "Energy Eater", health: 32, attack: 4, rule: .drought,
              lesson: "Energy · Planning", briefing: "Recover 3 energy. Unit hits deal 2 less damage; spells are unaffected. Try strong units or Energy Storm.", challenge: "Play at most 10 cards"),
        Stage(name: "06 · Forest Core", enemy: "Clock King", health: 42, attack: 4, rule: .boss,
              lesson: "Boss · Two Phases", briefing: "Armor 1 above half HP. At half HP, lose 4 shield and face 7 attack. Save defense and burst damage.", challenge: "Finish with at least 10 HP")
    ]
}

struct FieldCard: Codable, Equatable {
    let kind: CardKind
    var waiting: Bool
    var evolved: Bool = false
    var charged: Bool = false
    var art: Int {
        if evolved && kind == .seed { return 7 }
        if evolved && kind == .dragon { return 8 }
        return kind.art
    }
    var name: String {
        if evolved && kind == .seed { return "Oak Turret" }
        if evolved && kind == .dragon { return "Time Drake" }
        return kind.name
    }
    var attack: Int { kind.attack + (evolved ? 2 : 0) }
}

enum BattleOutcome: String, Codable { case playing, won, lost }

struct BattleState: Codable {
    let stageIndex: Int
    var playerHealth = 20
    var shield = 0
    var enemyHealth: Int
    var turn = 1
    var energy = 3
    var hand: [CardKind]
    var drawPile: [CardKind]
    var discard: [CardKind] = []
    var field: [FieldCard?] = [nil, nil, nil]
    var outcome: BattleOutcome = .playing
    var log: [String] = ["The time gates are open. Select a card, then a time slot."]
    var archivedLog: [String]?
    var cardsPlayed = 0
    var damageBlocked = 0
    var chargedHits: Int? = 0
    var hardMode: Bool? = false
    var isHard: Bool { hardMode == true }
    var briefing: String { stage.briefing + (isHard ? "\n\nHard modifier: " + stage.hardModifier : "") }

    init(stageIndex: Int, deck: [CardKind], hard: Bool = false) {
        hardMode = hard
        self.stageIndex = min(max(stageIndex, 0), Stage.all.count - 1)
        enemyHealth = Stage.all[self.stageIndex].health
        hand = Array(deck.prefix(4))
        drawPile = Array(deck.dropFirst(4))
        if hard && stage.rule == .training { energy = 2 }
        log.append(briefing)
    }
    var stage: Stage { Stage.all[stageIndex] }
    var enemyIntent: Int {
        switch stage.rule {
        case .charge: return turn.isMultiple(of: 2) ? 8 : 2
        case .boss: return enemyHealth <= stage.health / 2 ? 7 : 4
        case .training: return stage.attack + (turn.isMultiple(of: 3) ? 2 : 0)
        default: return stage.attack
        }
    }
    var baseEnergy: Int { stage.rule == .drought ? (isHard ? 2 : 3) : min(5, 2 + turn) }
    var enemyStatus: String {
        switch stage.rule {
        case .training: return "Attack \(enemyIntent)"
        case .bark: return "Bark 1 · Attack \(enemyIntent)"
        case .shell: return "Armor \(turn.isMultiple(of: 2) ? 0 : 2) · Attack \(enemyIntent)"
        case .charge: return "\(turn.isMultiple(of: 2) ? "Heavy hit" : "Charge") \(enemyIntent)"
        case .drought: return "Energy \(baseEnergy) · Resist 2"
        case .boss: return enemyHealth <= stage.health / 2 ? "Enraged · Attack 7" : "Armor 1 · Enrages at half HP"
        }
    }
    var challengeMet: Bool {
        switch stage.rule {
        case .training: return turn <= 5
        case .bark: return field.contains { $0?.evolved == true }
        case .shell: return (chargedHits ?? 0) > 0
        case .charge: return damageBlocked >= 8
        case .drought: return cardsPlayed <= 10
        case .boss: return playerHealth >= 10
        }
    }
    var stars: Int { outcome == .won ? 1 + (playerHealth >= 12 ? 1 : 0) + (challengeMet ? 1 : 0) : 0 }

    private mutating func hitEnemy(_ amount: Int, evolved: Bool = false, charged: Bool = false, spell: Bool = false) -> Int {
        var armor = 0
        switch stage.rule {
        case .bark: armor = (evolved || spell) ? 0 : 1
        case .shell: armor = turn.isMultiple(of: 2) ? 0 : 2
        case .drought: armor = spell ? 0 : 2
        case .boss: armor = enemyHealth > stage.health / 2 ? 1 : 0
        default: break
        }
        if charged && stage.rule != .drought { armor = 0 }
        let hit = max(0, amount - armor)
        let wasCalm = stage.rule == .boss && enemyHealth > stage.health / 2
        enemyHealth = max(0, enemyHealth - hit)
        if wasCalm && enemyHealth > 0 && enemyHealth <= stage.health / 2 {
            shield = max(0, shield - 4)
            record("Clock King enrages! Lose 4 shield. Armor gone; attack is now 7.")
        }
        return hit
    }

    func canPlay(_ kind: CardKind, in lane: TimeLane) -> String? {
        guard outcome == .playing else { return "This battle has ended." }
        guard hand.contains(kind) else { return "That card is not in your hand." }
        if isHard && stage.rule == .shell && !turn.isMultiple(of: 2) && lane == .present { return "Present is locked. Wait for an even turn, or use Past or Future." }
        guard energy >= kind.cost else { return "Not enough energy. Cost: \(kind.cost)." }
        if lane == .past && !kind.isUnit { return "Past accepts units only. Play spells in Present or Future." }
        if kind == .rewind {
            guard lane == .present else { return "Rewind can only be played in the Present." }
            guard field.contains(where: { $0?.kind.isUnit == true }) else { return "There is no unit to recall." }
        }
        if (kind.isUnit || lane == .future) && field[lane.rawValue] != nil {
            return "Slot occupied. Use Rewind to recall a unit."
        }
        return nil
    }

    @discardableResult
    mutating func play(_ kind: CardKind, in lane: TimeLane) -> String? {
        if let error = canPlay(kind, in: lane) { return error }
        guard let index = hand.firstIndex(of: kind) else { return "Your hand has changed." }
        hand.remove(at: index)
        energy -= kind.cost
        cardsPlayed += 1
        if kind.isUnit {
            field[lane.rawValue] = FieldCard(kind: kind, waiting: lane != .present, charged: lane == .future)
            record("\(kind.name) → \(lane.title)\(lane == .present ? ", attacks this turn" : ", activates next turn")")
        } else if lane == .future {
            field[lane.rawValue] = FieldCard(kind: kind, waiting: true)
            record("\(kind.name) prepared: double effect next turn.")
        } else {
            resolveSpell(kind, multiplier: 1)
            discard.append(kind)
        }
        checkOutcome()
        return nil
    }

    mutating func endTurn() {
        guard outcome == .playing else { return }
        // Active units attack first. Newly placed past/future cards must survive the enemy turn.
        for lane in TimeLane.allCases {
            guard var unit = field[lane.rawValue], unit.kind.isUnit, !unit.waiting else { continue }
            let hit = hitEnemy(unit.attack * (unit.charged ? 2 : 1), evolved: unit.evolved, charged: unit.charged)
            if unit.charged { chargedHits = (chargedHits ?? 0) + 1 }
            record("\(unit.name) deals \(hit) damage\(unit.charged ? " · Future burst" : "")")
            unit.charged = false
            field[lane.rawValue] = unit
            if unit.kind == .guardian {
                shield += 2
                record("Gear Guard grants 2 shield.")
            }
            checkOutcome()
            if outcome != .playing { return }
        }
        if isHard && stage.rule == .charge && turn.isMultiple(of: 2) {
            shield = max(0, shield - 2); record("Shield Break removes 2 shield.")
        }
        let incoming = enemyIntent
        let blocked = min(shield, incoming)
        shield -= blocked
        damageBlocked += blocked
        playerHealth = max(0, playerHealth - (incoming - blocked))
        record("Enemy attack \(incoming) · Blocked \(blocked) · Damage taken \(incoming - blocked)")
        checkOutcome()
        if outcome != .playing { return }

        if isHard && stage.rule == .bark {
            enemyHealth = min(stage.health, enemyHealth + 2); record("Regrowth heals 2 HP.")
        }
        if isHard && stage.rule == .boss && turn.isMultiple(of: 3), let unit = field[1], unit.kind.isUnit {
            field[1] = nil
            if hand.count < 6 { hand.append(unit.kind) } else { discard.append(unit.kind) }
            record("Time Shock recalls \(unit.kind.name) from Present; discarded if your hand is full.")
        }
        turn += 1
        energy = baseEnergy
        for lane in TimeLane.allCases {
            guard var card = field[lane.rawValue], card.waiting else { continue }
            if card.kind.isUnit {
                card.waiting = false
                card.evolved = lane == .past
                field[lane.rawValue] = card
                record(lane == .past ? "Growth! \(card.name) gains +2 attack." : "\(card.name) is ready: next attack doubled.")
            } else {
                field[lane.rawValue] = nil
                resolveSpell(card.kind, multiplier: 2)
                discard.append(card.kind)
            }
        }
        checkOutcome()
        if outcome == .playing {
            drawCards(2)
            record("Turn \(turn) · Energy restored · Cards drawn")
        }
    }

    private mutating func resolveSpell(_ kind: CardKind, multiplier: Int) {
        switch kind {
        case .shield:
            shield += 4 * multiplier
            record("Time Shield +\(4 * multiplier)")
        case .spark:
            let gain = min(5 - energy, multiplier)
            energy += gain
            record("Energy Spark +\(gain) · Energy cap 5")
        case .surge:
            let hit = hitEnemy(6 * multiplier, spell: true)
            record("Energy Storm deals \(hit) damage.")
        case .rewind:
            if let index = field.firstIndex(where: { $0?.kind.isUnit == true }), let unit = field[index] {
                field[index] = nil
                hand.append(unit.kind)
                record("\(unit.kind.name) returned to hand. Growth reset.")
            }
        default: break
        }
    }
    private mutating func drawCards(_ count: Int) {
        for _ in 0..<count {
            guard hand.count < 6 else { break }
            if drawPile.isEmpty { drawPile = discard; discard = [] }
            guard !drawPile.isEmpty else { break }
            hand.append(drawPile.removeFirst())
        }
    }
    private mutating func checkOutcome() {
        if enemyHealth <= 0 { outcome = .won }
        else if playerHealth <= 0 { outcome = .lost }
    }
    private mutating func record(_ text: String) {
        log.append(text)
        if log.count > 30 { log.removeFirst(log.count - 30) }
    }
}

struct SavedGame: Codable {
    var version = 2
    var bestStars: [String: Int]? = [:]
    var hardStars: [String: Int]? = [:]
    var selectedHard: Bool? = false
    var hardUnlocked: Bool { Set(completedStages).count == Stage.all.count }
    var viewingHard: Bool { selectedHard == true && hardUnlocked }
    var currentStars: [String: Int] { (viewingHard ? hardStars : bestStars) ?? [:] }
    var collection = CardKind.starter
    var deck = CardKind.starter
    var completedStages: [Int] = []
    var selectedStage = 0
    var battle: BattleState?
    var haptics = true
    var reducedMotion = false
    var hasSeenRules = false
    var victories = 0

    var unlockedStage: Int { min((completedStages.max() ?? -1) + 1, Stage.all.count - 1) }
    var rewards: [CardKind] {
        guard let battle = battle, battle.outcome == .won, battle.stage.rewardMilestone, !battle.isHard,
              !completedStages.contains(battle.stageIndex) else { return [] }
        let locked = CardKind.allCases.filter { !collection.contains($0) }
        return Array(locked.prefix(3))
    }
    mutating func startBattle() {
        guard deck.count == 6, Set(deck).count == 6, deck.allSatisfy({ collection.contains($0) }) else { return }
        battle = BattleState(stageIndex: min(selectedStage, unlockedStage), deck: deck, hard: viewingHard)
    }
    /// Consuming the victory and saving the collection happen as one persisted state change.
    @discardableResult
    mutating func claimVictory(_ reward: CardKind?) -> Bool {
        guard let finished = battle, finished.outcome == .won else { return false }
        let choices = rewards
        if !choices.isEmpty {
            guard let reward = reward, choices.contains(reward) else { return false }
            collection.append(reward)
        } else if reward != nil { return false }
        var scores = (finished.isHard ? hardStars : bestStars) ?? [:]
        scores[String(finished.stageIndex)] = max(scores[String(finished.stageIndex)] ?? 0, finished.stars)
        if finished.isHard { hardStars = scores }
        else {
            bestStars = scores
            if !completedStages.contains(finished.stageIndex) { completedStages.append(finished.stageIndex) }
        }
        victories += 1
        selectedStage = min(finished.stageIndex + 1, unlockedStage)
        battle = nil
        return true
    }
}

final class GameStore {
    private let defaults: UserDefaults
    private let key = "time-cards.saved-game.v1"
    var state: SavedGame
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(SavedGame.self, from: data),
           (1...2).contains(decoded.version),
           decoded.deck.count == 6, Set(decoded.deck).count == 6,
           decoded.deck.allSatisfy({ decoded.collection.contains($0) }),
           (0..<Stage.all.count).contains(decoded.selectedStage),
           decoded.completedStages.allSatisfy({ (0..<Stage.all.count).contains($0) }),
           decoded.battle.map({ (0..<Stage.all.count).contains($0.stageIndex) && $0.field.count == 3 }) ?? true {
            state = decoded
            if state.version == 1 {
                // The prototype's later indices represented different chapters. Keep owned cards,
                // preferences and the first clear, but do not reinterpret its active encounter.
                state.version = 2
                state.completedStages = state.completedStages.contains(0) ? [0] : []
                state.selectedStage = state.completedStages.isEmpty ? 0 : 1
                state.battle = nil
                state.bestStars = state.completedStages.isEmpty ? [:] : ["0": 1]
                _ = save()
            }
            if var battle = state.battle,
               battle.log.contains(where: { $0.range(of: "\\p{Han}", options: .regularExpression) != nil }) {
                battle.archivedLog = (battle.archivedLog ?? []) + battle.log
                battle.log = ["Battle resumed. Earlier log entries are archived.", battle.briefing]
                state.battle = battle
                _ = save()
            }
        } else { state = SavedGame() }
    }
    @discardableResult
    func save() -> Bool {
        guard let data = try? JSONEncoder().encode(state) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
