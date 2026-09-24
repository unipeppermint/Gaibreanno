import Foundation

enum ContractRisk: String, Codable, CaseIterable {
    case measured, daring, ruthless
    var name: String { switch self { case .measured: return "Measured"; case .daring: return "Daring"; case .ruthless: return "Ruthless" } }
    var attackBonus: Int { Self.allCases.firstIndex(of: self)! }
    var startingHealth: Int { self == .ruthless ? 16 : 20 }
    var payoutSteps: [Int] { switch self { case .measured: return [15, 30, 60]; case .daring: return [20, 40, 80]; case .ruthless: return [30, 60, 120] } }
    var detail: String { "Start \(startingHealth) HP · Enemy attack +\(attackBonus)" }
}

enum ContractBoon { case mend, ward }

struct ContractReceipt: Codable {
    var risk: ContractRisk
    var stake: Int
    var payout: Int
    var cleared: Int
    var net: Int { payout - stake }
}

struct ContractWallet: Codable {
    var chips = 300
    var history: [ContractReceipt] = []
    var bestRun = 0
}

struct ContractRun: Codable {
    let risk: ContractRisk
    let stake: Int
    let deck: [CardKind]
    var round = 0
    var battle: BattleState
    var multiplier: Double { Double(risk.payoutSteps[round]) / 10 }
    var payout: Int { stake * risk.payoutSteps[round] / 10 }
    var canContinue: Bool { round < 2 && battle.outcome == .won }
    var nextPayout: Int { stake * risk.payoutSteps[min(2, round + 1)] / 10 }
}

extension SavedGame {
    var chips: Int { contractWallet?.chips ?? 300 }
    // Contract battles are isolated from the saved campaign, stars and card rewards.
    var activeBattle: BattleState? {
        get { contract?.battle ?? battle }
        set {
            if contract != nil {
                if let newValue { contract?.battle = newValue }
            } else { battle = newValue }
        }
    }

    @discardableResult mutating func startContract(stake: Int, risk: ContractRisk) -> Bool {
        guard contract == nil, [25, 50, 100].contains(stake), chips >= stake,
              deck.count == 6, Set(deck).count == 6, deck.allSatisfy({ collection.contains($0) }) else { return false }
        var wallet = contractWallet ?? ContractWallet()
        wallet.chips -= stake
        var encounter = BattleState(stageIndex: 0, deck: deck)
        encounter.contractRisk = risk
        encounter.playerHealth = risk.startingHealth
        encounter.log = ["Fate Contract · Round 1 of 3 · \(stake) gold committed.", risk.detail]
        contract = ContractRun(risk: risk, stake: stake, deck: deck, battle: encounter)
        contractWallet = wallet
        return true
    }

    @discardableResult mutating func continueContract(boon: ContractBoon) -> Bool {
        guard var run = contract, run.canContinue else { return false }
        let health = run.battle.playerHealth
        run.round += 1
        run.battle = BattleState(stageIndex: run.round, deck: run.deck)
        run.battle.contractRisk = run.risk
        run.battle.playerHealth = min(20, health + (boon == .mend ? 6 : 0))
        run.battle.shield = boon == .ward ? 8 : 0
        run.battle.log = ["Round \(run.round + 1) · \(run.risk.name) · \(run.risk.detail)",
                          boon == .mend ? "Mend: recover up to 6 HP. Health carries over." : "Ward: start with 8 shield. Health carries over."]
        contract = run
        return true
    }

    /// Settles exactly once; abandoning an unfinished encounter also loses the committed stake.
    @discardableResult mutating func finishContract(bank: Bool) -> Bool {
        guard let run = contract, !bank || run.battle.outcome == .won else { return false }
        var wallet = contractWallet ?? ContractWallet()
        let payout = bank ? run.payout : 0
        let cleared = run.round + (run.battle.outcome == .won ? 1 : 0)
        wallet.chips += payout
        wallet.bestRun = max(wallet.bestRun, cleared)
        wallet.history.insert(ContractReceipt(risk: run.risk, stake: run.stake, payout: payout, cleared: cleared), at: 0)
        wallet.history = Array(wallet.history.prefix(8))
        contractWallet = wallet
        contract = nil
        return true
    }

    @discardableResult mutating func refillPracticeChips() -> Bool {
        guard contract == nil, chips < 25 else { return false }
        var wallet = contractWallet ?? ContractWallet()
        wallet.chips += 100
        contractWallet = wallet
        return true
    }
}
