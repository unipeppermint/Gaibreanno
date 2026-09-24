import Foundation

@main
struct GameEngineChecks {
    static var checks = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError("CHECK FAILED: \(message)") }
    }
    static func fresh(_ deck: [CardKind] = CardKind.starter) -> BattleState { BattleState(stageIndex: 0, deck: deck) }
    static func main() throws {
        var b = fresh()
        expect(b.hand.count == 4 && b.drawPile.count == 2, "Opening hand has four cards")
        expect(b.play(.seed, in: .present) == nil, "Present accepts a unit")
        expect(b.energy == 1 && b.hand.count == 3, "Playing pays cost and removes hand card")
        expect(b.play(.dragon, in: .present) != nil, "Occupied unit lane rejects placement")
        expect(b.energy == 1 && b.hand.contains(.dragon), "Rejected action changes no resources")
        b.endTurn()
        expect(b.enemyHealth == 18 && b.playerHealth == 16, "Present unit attacks before enemy")

        b = fresh(); b.play(.seed, in: .past); b.endTurn()
        expect(b.enemyHealth == 20, "Past unit waits through first turn")
        expect(b.field[0]?.evolved == true && b.field[0]?.attack == 4, "Past unit permanently grows")
        expect(b.field[0]?.art == 7 && b.field[0]?.name == "Oak Turret", "Growth changes illustration and name")
        b.endTurn(); expect(b.enemyHealth == 16, "Grown unit attacks next turn")
        b.endTurn(); expect(b.enemyHealth == 12, "Growth bonus persists")

        b = fresh(); b.play(.dragon, in: .future); b.endTurn()
        expect(b.enemyHealth == 20 && b.field[2]?.charged == true, "Future unit waits and charges")
        b.endTurn(); expect(b.enemyHealth == 16, "First future attack is doubled")
        b.endTurn(); expect(b.enemyHealth == 14, "Later future attacks are normal")

        b = fresh(); expect(b.play(.shield, in: .past) != nil, "Past rejects non-unit spells")
        expect(b.energy == 3 && b.hand.contains(.shield), "Invalid lane doesn't spend card")
        b.play(.shield, in: .present); b.endTurn()
        expect(b.playerHealth == 20 && b.shield == 0 && b.damageBlocked == 4, "Shield absorbs exactly enemy damage")

        b = fresh(); b.play(.shield, in: .future); b.endTurn()
        expect(b.playerHealth == 16 && b.shield == 8, "Future shield activates after the intervening attack")
        expect(b.field[2] == nil, "Future spell clears its slot")
        b.endTurn(); expect(b.playerHealth == 16 && b.shield == 4, "Unused shield persists")

        b = fresh(); b.playerHealth = 1; b.play(.shield, in: .future); b.endTurn()
        expect(b.outcome == .lost && b.shield == 0, "Lethal attack cannot be rescued by delayed shield")
        let lostEnergy = b.energy
        b.endTurn(); expect(b.energy == lostEnergy, "Finished battle ignores further turns")
        expect(b.play(.dragon, in: .present) != nil, "Finished battle rejects plays")

        b = fresh(); b.enemyHealth = 2; b.play(.dragon, in: .present); b.endTurn()
        expect(b.outcome == .won && b.playerHealth == 20, "Lethal friendly attack prevents retaliation")

        b = fresh([.rewind, .seed, .shield, .spark, .dragon, .guardian])
        expect(b.play(.rewind, in: .present) != nil, "Rewind requires a unit")
        b.play(.seed, in: .past); b.endTurn()
        expect(b.play(.rewind, in: .future) != nil, "Rewind cannot be delayed")
        b.play(.rewind, in: .present)
        expect(b.field[0] == nil && b.hand.contains(.seed), "Rewind returns original unit to hand")
        b.play(.seed, in: .present)
        expect(b.field[1]?.evolved == false && b.field[1]?.attack == 2, "Replayed unit loses growth")

        b = fresh(); b.energy = 0
        expect(b.play(.seed, in: .past) != nil && b.hand.contains(.seed), "Unaffordable cards are not consumed")
        b.play(.spark, in: .present); expect(b.energy == 1, "Zero-cost spark restores energy")
        b = fresh(); b.energy = 5; b.play(.spark, in: .present)
        expect(b.energy == 5, "Energy cannot exceed five")

        b = fresh([.surge, .shield, .spark, .dragon, .seed, .guardian])
        b.play(.surge, in: .future); b.endTurn()
        expect(b.enemyHealth == 8, "Future damage spell doubles on activation")
        expect(b.discard.contains(.surge) || b.hand.contains(.surge), "Resolved spells return to draw cycle")

        b = fresh(); b.endTurn(); b.endTurn()
        expect(b.hand.count == 6, "Drawing respects six-card hand limit")
        expect(b.enemyIntent == 6, "Every third turn has stronger enemy intent")

        // Verify all encounters have a legal winning route with the starting deck.
        // Also track card conservation across delayed effects and repeated discard draws.
        for stage in 0..<4 {
            b = BattleState(stageIndex: stage, deck: CardKind.starter)
            b.play(.seed, in: .past); b.play(.dragon, in: .present)
            b.play(.spark, in: .present); b.play(.shield, in: .present); b.endTurn()
            while b.outcome == .playing && b.turn < 15 {
                if b.hand.contains(.spark) && b.energy < 3 { b.play(.spark, in: .present) }
                if b.hand.contains(.shield) { b.play(.shield, in: .present) }
                if b.hand.contains(.guardian) && b.field[2] == nil { b.play(.guardian, in: .future) }
                let all = b.hand + b.drawPile + b.discard + b.field.compactMap { $0?.kind }
                expect(all.count == 6 && Set(all).count == 6, "Card conservation, stage \(stage), turn \(b.turn)")
                expect(b.energy >= 0 && b.energy <= 5 && b.shield >= 0, "Resource bounds remain valid")
                b.endTurn()
            }
            expect(b.outcome == .won, "Stage \(stage + 1) can be won through timing and defense")
            expect(b.stars == 3, "Stage \(stage + 1) has an achievable three-star route with the starter deck")
        }

        // Distinct encounter rules: armor, timing windows, recovery and phase changes.
        b = BattleState(stageIndex: 1, deck: CardKind.starter)
        b.play(.dragon, in: .present); b.endTurn()
        expect(b.enemyHealth == 23, "Tree armor reduces ungrown attacks")
        b = BattleState(stageIndex: 1, deck: CardKind.starter)
        b.play(.seed, in: .past); b.endTurn(); b.endTurn()
        expect(b.enemyHealth == 20, "Grown units bypass tree armor")
        b = BattleState(stageIndex: 2, deck: CardKind.starter)
        b.play(.dragon, in: .present); b.endTurn()
        expect(b.enemyHealth == 28, "Closed shell blocks two damage on odd turns")
        b.endTurn(); expect(b.enemyHealth == 26, "Open shell takes full damage on even turns")
        b = BattleState(stageIndex: 2, deck: CardKind.starter)
        b.turn = 2; b.play(.dragon, in: .future); b.endTurn(); b.endTurn()
        expect(b.enemyHealth == 24 && b.chargedHits == 1, "Future burst bypasses closed shell and tracks challenge")
        b = BattleState(stageIndex: 3, deck: CardKind.starter)
        b.play(.shield, in: .future); b.endTurn()
        expect(b.enemyIntent == 8 && b.shield == 8 && b.playerHealth == 18, "Delayed shield lines up with telegraphed heavy strike")
        b.endTurn(); expect(b.playerHealth == 18 && b.damageBlocked == 8 && b.challengeMet, "Shield fully blocks heavy strike and earns challenge")
        b = BattleState(stageIndex: 4, deck: CardKind.starter)
        b.endTurn(); expect(b.energy == 3, "Drought restores only three energy")
        b.play(.spark, in: .present); expect(b.energy == 4, "Spark bypasses drought recovery limit")
        b.endTurn(); expect(b.energy == 3, "Drought resets bonus energy next turn")
        b = BattleState(stageIndex: 5, deck: CardKind.starter)
        b.enemyHealth = 22; b.play(.dragon, in: .present); b.endTurn()
        expect(b.enemyHealth == 21 && b.playerHealth == 13 && b.enemyIntent == 7, "Boss switches phase and attacks harder on threshold-crossing turn")
        b.endTurn(); expect(b.enemyHealth == 19, "Enraged boss loses armor")

        // Late encounters require purpose-built lines. Routes contain only legal player actions.
        func route(_ stage: Int, hard: Bool, _ actions: String, deck: [CardKind] = [.elder, .shield, .spark, .guardian, .surge, .oak]) {
            var game = BattleState(stageIndex: stage, deck: deck, hard: hard)
            for action in actions.split(separator: ",") {
                if action == "end" { game.endTurn() }
                else {
                    let parts = action.split(separator: ":")
                    let card = CardKind(rawValue: String(parts[0]))!
                    let lane = TimeLane(rawValue: Int(parts[1])!)!
                    expect(game.play(card, in: lane) == nil, "Route plays legal card: \(stage)/\(hard)/\(action)")
                }
                let all = game.hand + game.drawPile + game.discard + game.field.compactMap { $0?.kind }
                expect(all.count == 6 && Set(all).count == 6, "Route conserves cards")
            }
            expect(game.outcome == .won && game.stars == 3, "Three-star route: \(stage), hard \(hard)")
        }
        route(4, hard: false, "guardian:0,end,surge:2,end,surge:2,end,surge:1", deck: [.dragon,.shield,.spark,.guardian,.surge,.oak])
        route(5, hard: false, "elder:0,spark:1,shield:1,end,guardian:1,surge:2,end,shield:1,end,surge:1,shield:1,end,end", deck: [.elder,.shield,.spark,.guardian,.surge,.rewind])
        route(4, hard: false, "elder:0,end,guardian:1,shield:2,end,oak:2,end,end,end,end", deck: [.elder,.shield,.spark,.guardian,.oak,.rewind])
        route(5, hard: false, "elder:0,end,oak:1,shield:2,end,shield:2,end,shield:2,end,end,end", deck: [.elder,.shield,.spark,.guardian,.oak,.rewind])
        route(5, hard: false, "oak:1,end,shield:1,surge:2,end,shield:1,surge:2,end,shield:1,surge:2,end", deck: [.oak,.shield,.spark,.guardian,.surge,.rewind])
        route(4, hard: false, "guardian:0,end,surge:2,end,surge:2,end,surge:1", deck: [.elder,.shield,.spark,.guardian,.surge,.rewind])
        route(0, hard: true, "guardian:0,end,surge:2,end,surge:1")
        route(1, hard: true, "elder:0,end,surge:2,end,end")
        route(2, hard: true, "elder:0,end,oak:2,shield:1,end,end,end")
        route(3, hard: true, "guardian:0,shield:2,end,elder:1,end,surge:1,end,surge:1,end")
        route(4, hard: true, "guardian:0,end,surge:2,end,surge:2,end,surge:1")
        route(5, hard: true, "elder:0,spark:1,shield:1,end,guardian:1,surge:2,end,shield:1,end,guardian:1,surge:1,shield:1,end,end")

        b = BattleState(stageIndex: 4, deck: [.dragon,.surge,.shield,.spark,.guardian,.rewind])
        b.play(.dragon, in: .present); b.endTurn()
        expect(b.enemyHealth == 32, "Drought blocks low-attack unit damage")
        b.play(.surge, in: .present); expect(b.enemyHealth == 26, "Drought does not reduce spells")
        b = BattleState(stageIndex: 5, deck: CardKind.starter)
        b.shield = 8; b.enemyHealth = 22; b.play(.dragon, in: .present); b.endTurn()
        expect(b.playerHealth == 17 && b.shield == 0, "Boss transition shatters four shield once")
        b = BattleState(stageIndex: 0, deck: CardKind.starter, hard: true)
        expect(b.energy == 2, "Hard alarm changes opening energy")
        b = BattleState(stageIndex: 1, deck: CardKind.starter, hard: true)
        b.enemyHealth = 20; b.endTurn(); expect(b.enemyHealth == 22, "Hard tree regenerates")
        b = BattleState(stageIndex: 2, deck: CardKind.starter, hard: true)
        expect(b.play(.shield, in: .present) != nil && b.energy == 3, "Hard beetle rejects sealed lane without spending")
        b.endTurn(); expect(b.play(.shield, in: .present) == nil, "Hard beetle opens lane on even turns")
        b = BattleState(stageIndex: 3, deck: CardKind.starter, hard: true)
        b.play(.shield, in: .future); b.endTurn(); b.endTurn()
        expect(b.playerHealth == 16 && b.damageBlocked == 6, "Hard hammer shatters shield before strike")
        b = BattleState(stageIndex: 4, deck: CardKind.starter, hard: true)
        b.endTurn(); expect(b.energy == 2, "Hard drought restores two")
        b = BattleState(stageIndex: 5, deck: CardKind.starter, hard: true)
        b.turn = 3; b.play(.dragon, in: .present); b.endTurn()
        expect(b.field[1] == nil && b.hand.contains(.dragon), "Hard boss returns present unit without losing card")

        var save = SavedGame(); save.startBattle()
        expect(save.claimVictory(nil) == false, "Cannot claim before winning")
        save.battle?.enemyHealth = 0; save.battle?.outcome = .won
        expect(save.claimVictory(.seed) == false, "Non-milestone cannot claim card")
        expect(save.claimVictory(nil), "Tutorial clear is claimable without reward")
        expect(save.completedStages == [0] && save.unlockedStage == 1, "Clear unlocks next stage")
        expect(save.bestStars?["0"] == 3, "Clear stores best stars")
        expect(save.claimVictory(nil) == false && save.victories == 1, "Reward cannot be claimed twice")
        save.startBattle(); save.battle?.outcome = .won
        expect(save.rewards.count == 3, "Second encounter offers three new card choices")
        expect(save.claimVictory(.seed) == false, "Cannot claim an owned card")
        expect(save.claimVictory(.elder) && save.collection.contains(.elder), "Milestone unlocks selected card")
        save.selectedStage = 1; save.startBattle(); save.battle?.outcome = .won
        expect(save.rewards.isEmpty, "Replaying milestone cannot farm new cards")
        expect(save.claimVictory(nil), "Replay can still complete")
        save.startBattle(); save.battle?.play(.seed, in: .past)
        let data = try JSONEncoder().encode(save)
        let loaded = try JSONDecoder().decode(SavedGame.self, from: data)
        expect(loaded.deck == save.deck && loaded.collection == save.collection, "Collection and deck round-trip")
        expect(loaded.battle?.field[0]?.kind == .seed && loaded.battle?.energy == 1, "Active battle round-trips")
        expect(loaded.completedStages == [0, 1], "Progress round-trips")
        var badDeck = SavedGame(); badDeck.deck = [.seed]; badDeck.startBattle()
        expect(badDeck.battle == nil, "Incomplete deck cannot start")
        let suite = "TimeCardsChecks-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var legacy = save; legacy.version = 1; legacy.completedStages = [0, 1, 2]
        var legacyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        legacyJSON.removeValue(forKey: "bestStars")
        var oldBattle = legacyJSON["battle"] as! [String: Any]
        oldBattle.removeValue(forKey: "chargedHits"); legacyJSON["battle"] = oldBattle
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "time-cards.saved-game.v1")
        let migrated = GameStore(defaults: defaults)
        expect(migrated.state.version == 2 && migrated.state.completedStages == [0], "Prototype progress migrates without misidentifying new encounters")
        expect(migrated.state.collection.contains(.elder) && migrated.state.deck == save.deck, "Migration preserves cards and deck")
        expect(migrated.state.battle == nil && migrated.state.selectedStage == 1, "Old battle is safely retired")
        migrated.state.selectedStage = 1; migrated.state.startBattle(); migrated.state.battle?.play(.seed, in: .past)
        expect(migrated.save(), "Version two save succeeds")
        let restored = GameStore(defaults: defaults)
        expect(restored.state.battle?.field[0]?.kind == .seed, "Version two active battle restores")

        // Campaign progression offers exactly three card rewards and reaches a stable final stage.
        var campaign = SavedGame()
        for stage in Stage.all.indices {
            campaign.startBattle()
            expect(campaign.battle?.stageIndex == stage, "Campaign advances in sequence")
            campaign.battle?.outcome = .won
            let reward = campaign.rewards.first
            expect(campaign.claimVictory(reward), "Campaign clear can be claimed")
        }
        expect(campaign.collection.count == 9 && campaign.completedStages.count == 6, "Full chapter unlocks all nine cards")
        expect(campaign.selectedStage == 5 && campaign.unlockedStage == 5, "Chapter end never advances to nonexistent stage")
        campaign.startBattle(); campaign.battle?.outcome = .won; campaign.battle?.playerHealth = 1
        expect(campaign.claimVictory(nil) && campaign.bestStars?["5"] == 3, "Replay cannot lower previous star record")
        var lockedHard = SavedGame(); lockedHard.selectedHard = true; lockedHard.startBattle()
        expect(lockedHard.battle?.isHard == false, "Hard mode cannot start before all clears")
        campaign.selectedHard = true; campaign.selectedStage = 0; campaign.startBattle()
        expect(campaign.battle?.isHard == true, "Six clears unlock hard mode")
        campaign.battle?.outcome = .won
        let normalStars = campaign.bestStars
        expect(campaign.rewards.isEmpty && campaign.claimVictory(nil), "Hard victory grants no duplicate cards")
        expect(campaign.hardStars?["0"] == 3 && campaign.bestStars == normalStars, "Difficulties store independent stars")
        let hardData = try JSONEncoder().encode(campaign)
        let hardRestore = try JSONDecoder().decode(SavedGame.self, from: hardData)
        expect(hardRestore.viewingHard && hardRestore.hardStars == campaign.hardStars, "Hard selection and stars persist")
        var versionTwoJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as! [String: Any]
        versionTwoJSON.removeValue(forKey: "hardStars"); versionTwoJSON.removeValue(forKey: "selectedHard")
        var versionTwoBattle = versionTwoJSON["battle"] as! [String: Any]
        versionTwoBattle.removeValue(forKey: "hardMode"); versionTwoJSON["battle"] = versionTwoBattle
        let oldSave = try JSONDecoder().decode(SavedGame.self, from: JSONSerialization.data(withJSONObject: versionTwoJSON))
        expect(!oldSave.viewingHard && oldSave.battle?.isHard == false && oldSave.bestStars == save.bestStars, "Older saves default to normal with progress preserved")
        var languageSave = save
        languageSave.battle?.log = ["第 2 回合 · 能量恢复", "时间护盾 +4"]
        let healthBeforeLanguageUpdate = languageSave.battle?.playerHealth
        defaults.set(try JSONEncoder().encode(languageSave), forKey: "time-cards.saved-game.v1")
        let englishStore = GameStore(defaults: defaults)
        expect(englishStore.state.battle?.log.allSatisfy { $0.range(of: "\\p{Han}", options: .regularExpression) == nil } == true, "Resumed battle shows English log")
        expect(englishStore.state.battle?.archivedLog == languageSave.battle?.log, "Original log is archived without data loss")
        expect(englishStore.state.battle?.playerHealth == healthBeforeLanguageUpdate && englishStore.state.battle?.field == languageSave.battle?.field, "Language update preserves live battle")
        expect(englishStore.state.collection == languageSave.collection && englishStore.state.bestStars == languageSave.bestStars, "Language update preserves cards and stars")
        let englishReload = GameStore(defaults: defaults)
        expect(englishReload.state.battle?.archivedLog?.count == 2, "Log migration runs only once")
        // Contract economy, campaign isolation, loss, continuation and persistence.
        var contractGame = SavedGame()
        contractGame.startBattle(); contractGame.battle?.play(.seed, in: .past)
        expect(!contractGame.startContract(stake: -25, risk: .measured), "Negative stakes rejected")
        expect(!contractGame.startContract(stake: 26, risk: .measured), "Unsupported stakes rejected")
        expect(contractGame.startContract(stake: 50, risk: .daring) && contractGame.chips == 250, "Stake deducted exactly once")
        expect(!contractGame.startContract(stake: 50, risk: .daring) && contractGame.chips == 250, "Active run cannot be overwritten or charged twice")
        expect(contractGame.activeBattle?.enemyIntent == 5, "Contract attack bonus is telegraphed")
        expect(!contractGame.finishContract(bank: true) && !contractGame.continueContract(boon: .mend), "Cannot bank or advance before victory")
        expect(!contractGame.refillPracticeChips(), "No practice refill during an active run")
        expect(contractGame.activeBattle?.overdrive() == true, "Contract enables health for energy trade")
        expect(contractGame.activeBattle?.playerHealth == 17 && contractGame.activeBattle?.energy == 5, "Overdrive pays three HP and grants two energy")
        expect(contractGame.activeBattle?.overdrive() == false, "Cannot overdrive twice in a turn")
        let restoredRun = try JSONDecoder().decode(SavedGame.self, from: JSONEncoder().encode(contractGame))
        expect(restoredRun.chips == 250 && restoredRun.contract?.battle.overdriveTurn == 1, "Chips and overdrive limit survive reload")
        expect(restoredRun.activeBattle?.overdriveTurn == 1, "Restored battle routes to contract")
        contractGame.activeBattle?.outcome = .won
        contractGame.activeBattle?.playerHealth = 10
        expect(contractGame.contract?.payout == 100, "First payout includes the stake")
        expect(contractGame.continueContract(boon: .mend), "Victory can roll into another round")
        expect(contractGame.chips == 250 && contractGame.contract?.round == 1, "Continuation does not deduct another stake")
        expect(contractGame.activeBattle?.playerHealth == 16 && contractGame.activeBattle?.shield == 0, "Mend carries health and restores six")
        expect(contractGame.activeBattle?.overdriveTurn == nil && contractGame.activeBattle?.hand.count == 4, "New encounter resets hand and overdrive")
        contractGame.activeBattle?.outcome = .won
        expect(contractGame.continueContract(boon: .ward), "Second victory can continue with ward")
        expect(contractGame.activeBattle?.shield == 8 && contractGame.activeBattle?.playerHealth == 16, "Ward grants shield while preserving health")
        contractGame.activeBattle?.outcome = .won
        expect(!contractGame.continueContract(boon: .mend), "Third victory cannot advance beyond route")
        expect(contractGame.contract?.payout == 400 && contractGame.finishContract(bank: true), "Third victory banks the advertised payout")
        expect(contractGame.chips == 650 && contractGame.contractWallet?.history.first?.net == 350, "Wallet and net profit balance correctly")
        expect(!contractGame.finishContract(bank: true) && contractGame.chips == 650, "Bank cannot pay twice")
        expect(contractGame.battle?.field[0]?.kind == .seed && contractGame.battle?.energy == 1, "Saved campaign resumes exactly where it stopped")
        expect(contractGame.completedStages.isEmpty && contractGame.collection == CardKind.starter, "Contract wins grant no campaign unlocks")
        var loss = SavedGame()
        loss.contractWallet = ContractWallet(chips: 25)
        expect(loss.startContract(stake: 25, risk: .ruthless), "Minimum bankroll can enter")
        expect(loss.activeBattle?.playerHealth == 16 && loss.activeBattle?.enemyIntent == 6, "Ruthless applies both advertised penalties")
        loss.activeBattle?.outcome = .lost
        expect(!loss.finishContract(bank: true), "Defeat cannot be cashed out")
        expect(loss.finishContract(bank: false) && loss.chips == 0, "Loss consumes only the committed stake")
        expect(loss.refillPracticeChips() && loss.chips == 100 && !loss.refillPracticeChips(), "Free refill prevents lockout without repeated collection")
        loss.contractWallet?.chips = 24
        expect(!loss.startContract(stake: 25, risk: .measured), "Insufficient chips cannot start a contract")
        b = fresh(); expect(!b.overdrive(), "Campaign does not enable contract overdrive")
        b.contractRisk = .measured; b.playerHealth = 3
        expect(!b.overdrive() && b.playerHealth == 3, "Overdrive cannot cause lethal self-damage")
        b.playerHealth = 20; b.energy = 4
        expect(!b.overdrive() && b.playerHealth == 20, "No health charged when energy would overflow")
        b.energy = 1; b.shield = 10
        expect(b.overdrive() && b.shield == 10 && b.playerHealth == 17, "Overdrive health cost bypasses shields")
        b.endTurn(); b.energy = 1
        expect(b.overdrive(), "Overdrive becomes available on the next turn")
        let oldContractFree = try JSONDecoder().decode(SavedGame.self, from: JSONSerialization.data(withJSONObject: versionTwoJSON))
        expect(oldContractFree.chips == 300 && oldContractFree.contract == nil, "Pre-contract saves receive default wallet without losing progress")
        defaults.set(try JSONEncoder().encode(restoredRun), forKey: "time-cards.saved-game.v1")
        let persistedContract = GameStore(defaults: defaults)
        expect(persistedContract.state.chips == 250 && persistedContract.state.contract?.stake == 50 && persistedContract.state.battle?.field[0]?.kind == .seed, "GameStore restores both modes independently")
        // Real legal routes exercise all three risks without forcing a victory state.
        for risk in ContractRisk.allCases {
            var runGame = SavedGame(); runGame.startContract(stake: 25, risk: risk)
            for round in 0..<3 {
                var fight = runGame.activeBattle!
                for move: (CardKind, TimeLane) in [(.seed, .past), (.dragon, .present), (.spark, .present), (.shield, .present)] {
                    expect(fight.play(move.0, in: move.1) == nil, "Contract opening plays are legal")
                }
                fight.endTurn()
                while fight.outcome == .playing && fight.turn < 15 {
                    if fight.hand.contains(.spark) && fight.energy < 3 { expect(fight.play(.spark, in: .present) == nil, "Contract energy recovery is legal") }
                    if fight.hand.contains(.shield) { expect(fight.play(.shield, in: .present) == nil, "Contract defense is legal") }
                    if fight.hand.contains(.guardian) && fight.field[2] == nil { expect(fight.play(.guardian, in: .future) == nil, "Contract future placement is legal") }
                    fight.endTurn()
                }
                expect(fight.outcome == .won, "Starter deck wins risk \(risk.rawValue), round \(round + 1)")
                runGame.activeBattle = fight
                if round < 2 { expect(runGame.continueContract(boon: .mend), "Legal win can continue") }
            }
            expect(runGame.finishContract(bank: true), "Legal three-win route pays out")
            expect(runGame.chips == 275 + 25 * risk.payoutSteps[2] / 10, "Full run total matches advertised payout")
        }
        print("PASS: \(checks) game engine checks, including all six encounters and save round-trip.")
    }
}
