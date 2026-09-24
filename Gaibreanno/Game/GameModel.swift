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
        case .spark: return 4
        case .surge: return 15
        case .guardian: return 5
        case .oak: return 7
        case .elder: return 8
        }
    }
    var isUnit: Bool { [.seed, .dragon, .guardian, .oak, .elder].contains(self) }
    var acquisition: String {
        CardKind.starter.contains(self) ? "初始卡牌，开始冒险即可获得。" : "普通第 2、4、6 关首次通关时，可从未拥有的卡牌中选择。"
    }
    var pairingTip: String {
        switch self {
        case .seed: return "放入过去持续成长，配合时间护盾撑过等待回合。"
        case .dragon: return "低费用适合开局放入现在，也能在未来抓住甲虫的破绽。"
        case .shield: return "重锤来袭前放入未来；生命危险时在现在立即使用。"
        case .rewind: return "召回最左侧单位腾出卡槽，再部署高攻击的新卡；记得预留费用。"
        case .spark: return "先补能，再部署高费单位；缺能关也能用它突破回能限制。"
        case .guardian: return "配合时间护盾持续防守，为过去的高攻单位争取成长时间。"
        case .oak: return "高攻击更容易打穿单位减伤；在未来蓄力可形成一次爆发。"
        case .elder: return "在过去成长为主力输出，搭配低费护盾与火花稳定开局。"
        case .surge: return "搭配卫士争取等待时间，再于未来释放双倍伤害；缺能关法术不受单位减伤影响。"
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
        case .training: return "紧缩开局：初始能量只有 2。"
        case .bark: return "再生树皮：敌方每次攻击后恢复 2 生命。"
        case .shell: return "封锁现在：奇数回合不能向现在出牌。"
        case .charge: return "碎盾重锤：偶数回合攻击前消除 2 护盾。"
        case .drought: return "深度缺能：每回合只恢复 2 能量。"
        case .boss: return "时间震荡：每第三回合敌方攻击后，将现在的单位退回手牌。"
        }
    }
    var rewardMilestone: Bool { [.bark, .charge, .boss].contains(rule) }
    static let all = [
        Stage(name: "01 · 林间警报", enemy: "巡林闹钟", health: 20, attack: 4, rule: .training,
              lesson: "学会出牌", briefing: "每第三回合攻击 +2。把幼龙放入现在，立即出击；护盾能抵挡伤害。", challenge: "5 回合内获胜"),
        Stage(name: "02 · 铁皮树桩", enemy: "铁皮树桩", health: 24, attack: 4, rule: .bark,
              lesson: "过去 · 成长破甲", briefing: "未成长单位伤害 -1；成长、未来连击和法术穿甲。把种子放入过去。", challenge: "带着成长单位获胜"),
        Stage(name: "03 · 开合甲虫", enemy: "发条甲虫", health: 28, attack: 4, rule: .shell,
              lesson: "未来 · 抓住破绽", briefing: "奇数回合每次受伤 -2，偶数回合无护甲。未来单位的首次翻倍攻击无视护甲。", challenge: "触发一次未来单位连击"),
        Stage(name: "04 · 重锤哨站", enemy: "重锤闹钟", health: 32, attack: 2, rule: .charge,
              lesson: "护盾 · 预判重击", briefing: "奇数回合攻击 2，偶数回合重击 8。提前把护盾放入未来，迎接重击。", challenge: "累计抵挡 8 点伤害"),
        Stage(name: "05 · 缺能小径", enemy: "吸能齿轮", health: 32, attack: 4, rule: .drought,
              lesson: "能量 · 精打细算", briefing: "回能 3；单位每次伤害 -2，法术不减伤。试试高攻击单位或能量风暴。", challenge: "出牌不超过 10 张"),
        Stage(name: "06 · 森林总闸", enemy: "暴走钟王", health: 42, attack: 4, rule: .boss,
              lesson: "首领 · 两阶段决战", briefing: "半血前护甲 1；进入半血时消除 4 护盾，随后攻击 7。留好护盾与爆发牌。", challenge: "剩余至少 10 点生命")
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
    var chargedHits: Int? = 0
    var hardMode: Bool? = false
    var isHard: Bool { hardMode == true }
    var briefing: String { stage.briefing + (isHard ? "\n\n困难追加：" + stage.hardModifier : "") }

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
        case .training: return "本轮攻击 \(enemyIntent)"
        case .bark: return "树皮减伤 1 · 攻击 \(enemyIntent)"
        case .shell: return "护甲 \(turn.isMultiple(of: 2) ? 0 : 2) · 攻击 \(enemyIntent)"
        case .charge: return "\(turn.isMultiple(of: 2) ? "重击" : "蓄力攻击") \(enemyIntent)"
        case .drought: return "回能 \(baseEnergy) · 单位减伤 2"
        case .boss: return enemyHealth <= stage.health / 2 ? "狂暴 · 攻击 7" : "护甲 1 · 过半血后攻击 7"
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
            record("钟王进入狂暴！消除 4 护盾，护甲消失，本轮起攻击 7")
        }
        return hit
    }

    func canPlay(_ kind: CardKind, in lane: TimeLane) -> String? {
        guard outcome == .playing else { return "本局已结束" }
        guard hand.contains(kind) else { return "这张卡不在手牌中" }
        if isHard && stage.rule == .shell && !turn.isMultiple(of: 2) && lane == .present { return "甲虫封锁现在：请在偶数回合出牌，或使用过去与未来" }
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
            let hit = hitEnemy(unit.attack * (unit.charged ? 2 : 1), evolved: unit.evolved, charged: unit.charged)
            if unit.charged { chargedHits = (chargedHits ?? 0) + 1 }
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
        if isHard && stage.rule == .charge && turn.isMultiple(of: 2) {
            shield = max(0, shield - 2); record("碎盾重锤消除 2 护盾")
        }
        let incoming = enemyIntent
        let blocked = min(shield, incoming)
        shield -= blocked
        damageBlocked += blocked
        playerHealth = max(0, playerHealth - (incoming - blocked))
        record("敌方攻击 \(incoming) · 护盾抵挡 \(blocked) · 受到 \(incoming - blocked) 点伤害")
        checkOutcome()
        if outcome != .playing { return }

        if isHard && stage.rule == .bark {
            enemyHealth = min(stage.health, enemyHealth + 2); record("再生树皮恢复 2 生命")
        }
        if isHard && stage.rule == .boss && turn.isMultiple(of: 3), let unit = field[1], unit.kind.isUnit {
            field[1] = nil
            if hand.count < 6 { hand.append(unit.kind) } else { discard.append(unit.kind) }
            record("时间震荡！\(unit.kind.name)退出现在，手牌满时进入弃牌堆")
        }
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
            let hit = hitEnemy(6 * multiplier, spell: true)
            record("能量风暴造成 \(hit) 点伤害")
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
        } else { state = SavedGame() }
    }
    @discardableResult
    func save() -> Bool {
        guard let data = try? JSONEncoder().encode(state) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}
