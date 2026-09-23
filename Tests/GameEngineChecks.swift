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
        expect(b.field[0]?.art == 7 && b.field[0]?.name == "巨木炮台", "Growth changes illustration and name")
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
        for stage in 0..<Stage.all.count {
            b = BattleState(stageIndex: stage, deck: CardKind.starter)
            b.play(.seed, in: .past); b.play(.dragon, in: .present); b.endTurn()
            while b.outcome == .playing && b.turn < 15 {
                if b.hand.contains(.spark) { b.play(.spark, in: .present) }
                if b.hand.contains(.shield) { b.play(.shield, in: .present) }
                if b.hand.contains(.guardian) && b.field[2] == nil { b.play(.guardian, in: .future) }
                let all = b.hand + b.drawPile + b.discard + b.field.compactMap { $0?.kind }
                expect(all.count == 6 && Set(all).count == 6, "Card conservation, stage \(stage), turn \(b.turn)")
                expect(b.energy >= 0 && b.energy <= 5 && b.shield >= 0, "Resource bounds remain valid")
                b.endTurn()
            }
            expect(b.outcome == .won, "Stage \(stage + 1) can be won through timing and defense")
        }

        var save = SavedGame(); save.startBattle()
        expect(save.claimVictory(.elder) == false, "Cannot claim before winning")
        save.battle?.enemyHealth = 0; save.battle?.outcome = .won
        expect(save.claimVictory(.seed) == false, "Cannot claim a card outside reward choices")
        expect(save.claimVictory(.elder), "Valid victory is claimable")
        expect(save.collection.contains(.elder) && save.completedStages == [0] && save.unlockedStage == 1, "Victory unlocks card and next stage")
        expect(save.claimVictory(.oak) == false && save.victories == 1, "Reward cannot be claimed twice")
        save.startBattle(); save.battle?.play(.seed, in: .past)
        let data = try JSONEncoder().encode(save)
        let loaded = try JSONDecoder().decode(SavedGame.self, from: data)
        expect(loaded.deck == save.deck && loaded.collection == save.collection, "Collection and deck round-trip")
        expect(loaded.battle?.field[0]?.kind == .seed && loaded.battle?.energy == 1, "Active battle round-trips")
        expect(loaded.completedStages == [0], "Progress round-trips")
        var badDeck = SavedGame(); badDeck.deck = [.seed]; badDeck.startBattle()
        expect(badDeck.battle == nil, "Incomplete deck cannot start")
        print("PASS: \(checks) game engine checks, including all three encounters and save round-trip.")
    }
}
