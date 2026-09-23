import Foundation

enum CardKind: String, Codable, CaseIterable {
    case seed, dragon, shield, rewind, spark, guardian, oak, elder, surge

    static let starter: [CardKind] = [.seed, .dragon, .shield, .spark, .guardian, .rewind]
    var name: String {
        switch self {
        case .seed: return "种子炮台"
        case .dragon: return "发条幼龙"
        case .shield: return "时间护盾"
        case .rewind: return "回溯术"
        case .spark: return "能量火花"
        case .guardian: return "齿轮卫士"
        case .oak: return "巨木炮台"
        case .elder: return "时空巨龙"
        case .surge: return "能量风暴"
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
        case .spark, .surge: return 4
        case .guardian: return 5
        case .oak: return 7
        case .elder: return 8
        }
    }
    var isUnit: Bool { [.seed, .dragon, .guardian, .oak, .elder].contains(self) }
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
        case .seed, .oak: return "成长"
        case .dragon, .elder: return "进化"
        case .shield: return "护盾 +4"
        case .rewind: return "返回手牌"
        case .spark: return "能量 +1"
        case .guardian: return "守护 +2"
        case .surge: return "伤害 6"
        }
    }
    var detail: String {
        switch self {
        case .seed, .dragon, .oak, .elder:
            return "每回合攻击 \(attack)。放入过去：等待一回合，成长后永久增加 2 点攻击。放入未来：等待一回合，首次攻击翻倍。"
        case .guardian:
            return "每回合攻击 1，并获得 2 点护盾。在过去成长后攻击 +2；在未来首次攻击翻倍。"
        case .shield: return "获得 4 点护盾，抵挡敌人伤害。现在使用立即生效；放入未来，在下回合开始获得 8 点护盾。"
        case .rewind: return "将场上最左侧的单位召回手牌，腾出卡槽。单位再次打出需支付费用；成长会重置。仅能在现在使用。"
        case .spark: return "获得 1 点能量，上限 5。现在使用立即生效；放入未来，在下回合开始额外获得 2 点能量。"
        case .surge: return "对敌人造成 6 点伤害。现在使用立即生效；放入未来，在下回合开始造成 12 点伤害。"
        }
    }
}

enum TimeLane: Int, CaseIterable, Codable {
    case past, present, future
    var title: String { ["过去", "现在", "未来"][rawValue] }
    var hint: String { ["等待 · 永久成长", "本回合生效", "等待 · 首次翻倍"][rawValue] }
}

struct Stage {
    let name: String
    let region: String
    let enemy: String
    let health: Int
    let attack: Int
    static let all = [
        Stage(name: "失控的时钟", region: "齿轮森林", enemy: "暴走闹钟", health: 20, attack: 4),
        Stage(name: "逆流回廊", region: "倒转之城", enemy: "逆流守卫", health: 28, attack: 5),
        Stage(name: "零点风暴", region: "时间裂隙", enemy: "零点领主", health: 38, attack: 6)
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
        if evolved && kind == .seed { return "巨木炮台" }
        if evolved && kind == .dragon { return "时空巨龙" }
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
    var log: [String] = ["时空通道已开启。选择手牌，再选择时间卡槽。"]
    var cardsPlayed = 0
    var damageBlocked = 0

    init(stageIndex: Int, deck: [CardKind]) {
        self.stageIndex = min(max(stageIndex, 0), Stage.all.count - 1)
        enemyHealth = Stage.all[self.stageIndex].health
        hand = Array(deck.prefix(4))
        drawPile = Array(deck.dropFirst(4))
    }
    var stage: Stage { Stage.all[stageIndex] }
    var enemyIntent: Int { stage.attack + ((turn % 3 == 0) ? 2 : 0) }
    var baseEnergy: Int { min(5, 2 + turn) }

    func canPlay(_ kind: CardKind, in lane: TimeLane) -> String? {
        guard outcome == .playing else { return "本局已结束" }
        guard hand.contains(kind) else { return "这张卡不在手牌中" }
        guard energy >= kind.cost else { return "能量不足，需要 \(kind.cost) 点能量" }
        if lane == .past && !kind.isUnit { return "过去只接收成长单位，法术请放入现在或未来" }
        if kind == .rewind {
            guard lane == .present else { return "回溯术只能在现在使用" }
            guard field.contains(where: { $0?.kind.isUnit == true }) else { return "场上没有可以召回的单位" }
        }
        if (kind.isUnit || lane == .future) && field[lane.rawValue] != nil {
            return "这个卡槽已被占用，可用回溯术召回单位"
        }
        return nil
    }

    @discardableResult
    mutating func play(_ kind: CardKind, in lane: TimeLane) -> String? {
        if let error = canPlay(kind, in: lane) { return error }
        guard let index = hand.firstIndex(of: kind) else { return "手牌已变化" }
        hand.remove(at: index)
        energy -= kind.cost
        cardsPlayed += 1
        if kind.isUnit {
            field[lane.rawValue] = FieldCard(kind: kind, waiting: lane != .present, charged: lane == .future)
            record("\(kind.name) → \(lane.title)\(lane == .present ? "，本回合出击" : "，下回合激活")")
        } else if lane == .future {
            field[lane.rawValue] = FieldCard(kind: kind, waiting: true)
            record("\(kind.name)已预约，下回合效果翻倍")
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
            let hit = unit.attack * (unit.charged ? 2 : 1)
            enemyHealth = max(0, enemyHealth - hit)
            record("\(unit.name)造成 \(hit) 点伤害\(unit.charged ? " · 未来连击" : "")")
            unit.charged = false
            field[lane.rawValue] = unit
            if unit.kind == .guardian {
                shield += 2
                record("齿轮卫士提供 2 点护盾")
            }
            checkOutcome()
            if outcome != .playing { return }
        }
        let incoming = enemyIntent
        let blocked = min(shield, incoming)
        shield -= blocked
        damageBlocked += blocked
        playerHealth = max(0, playerHealth - (incoming - blocked))
        record("敌方攻击 \(incoming) · 护盾抵挡 \(blocked) · 受到 \(incoming - blocked) 点伤害")
        checkOutcome()
        if outcome != .playing { return }

        turn += 1
        energy = baseEnergy
        for lane in TimeLane.allCases {
            guard var card = field[lane.rawValue], card.waiting else { continue }
            if card.kind.isUnit {
                card.waiting = false
                card.evolved = lane == .past
                field[lane.rawValue] = card
                record(lane == .past ? "成长连锁！\(card.name)攻击 +2" : "\(card.name)已激活，下次攻击翻倍")
            } else {
                field[lane.rawValue] = nil
                resolveSpell(card.kind, multiplier: 2)
                discard.append(card.kind)
            }
        }
        checkOutcome()
        if outcome == .playing {
            drawCards(2)
            record("第 \(turn) 回合 · 能量恢复 · 抽取手牌")
        }
    }

    private mutating func resolveSpell(_ kind: CardKind, multiplier: Int) {
        switch kind {
        case .shield:
            shield += 4 * multiplier
            record("时间护盾 +\(4 * multiplier)")
        case .spark:
            let gain = min(5 - energy, multiplier)
            energy += gain
            record("能量火花 +\(gain) · 能量上限 5")
        case .surge:
            enemyHealth = max(0, enemyHealth - 6 * multiplier)
            record("能量风暴造成 \(6 * multiplier) 点伤害")
        case .rewind:
            if let index = field.firstIndex(where: { $0?.kind.isUnit == true }), let unit = field[index] {
                field[index] = nil
                hand.append(unit.kind)
                record("\(unit.kind.name)已召回手牌，成长重置")
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
    var version = 1
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
        let locked = CardKind.allCases.filter { !collection.contains($0) }
        return Array(locked.prefix(3))
    }
    mutating func startBattle() {
        guard deck.count == 6, Set(deck).count == 6, deck.allSatisfy({ collection.contains($0) }) else { return }
        battle = BattleState(stageIndex: min(selectedStage, unlockedStage), deck: deck)
    }
    /// Consuming the victory and saving the collection happen as one persisted state change.
    @discardableResult
    mutating func claimVictory(_ reward: CardKind?) -> Bool {
        guard let finished = battle, finished.outcome == .won else { return false }
        let choices = rewards
        if !choices.isEmpty {
            guard let reward = reward, choices.contains(reward) else { return false }
            collection.append(reward)
        }
        if !completedStages.contains(finished.stageIndex) { completedStages.append(finished.stageIndex) }
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
           decoded.version == 1,
           decoded.deck.count == 6, Set(decoded.deck).count == 6,
           decoded.deck.allSatisfy({ decoded.collection.contains($0) }),
           (0..<Stage.all.count).contains(decoded.selectedStage),
           decoded.completedStages.allSatisfy({ (0..<Stage.all.count).contains($0) }),
           decoded.battle.map({ (0..<Stage.all.count).contains($0.stageIndex) && $0.field.count == 3 }) ?? true {
            state = decoded
        } else { state = SavedGame() }
    }
    @discardableResult
    func save() -> Bool {
        guard let data = try? JSONEncoder().encode(state) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
