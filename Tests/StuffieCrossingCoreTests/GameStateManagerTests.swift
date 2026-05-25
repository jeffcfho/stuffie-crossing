import XCTest
@testable import StuffieCrossingCore

final class GameStateManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeManager(level: Level = Levels.level1) -> GameStateManager {
        let mgr = GameStateManager(level: level)
        mgr.introCompleted()
        return mgr
    }

    /// Simulates a complete crossing: places stuffies on bridge, taps Go, fires animationCompleted.
    private func cross(_ ids: [String], from side: BankSide, in mgr: GameStateManager) {
        let bank = side == .left ? mgr.leftBank : mgr.rightBank
        for s in bank where ids.contains(s.id) {
            mgr.stuffieMovedToBridge(s)
        }
        mgr.goTapped(sourceSide: side)
        mgr.animationCompleted(sourceSide: side)
    }

    /// Places stuffies on bridge without crossing (for canTapGo assertions).
    private func putOnBridge(_ ids: [String], from side: BankSide, in mgr: GameStateManager) {
        let bank = side == .left ? mgr.leftBank : mgr.rightBank
        for s in bank where ids.contains(s.id) {
            mgr.stuffieMovedToBridge(s)
        }
    }

    // MARK: - ConflictPair

    func test_conflictPair_canonicalOrdering() {
        let pair = ConflictPair("lion", "bunny")
        XCTAssertEqual(pair.a, "bunny")
        XCTAssertEqual(pair.b, "lion")
    }

    func test_conflictPair_symmetricEquality() {
        XCTAssertEqual(ConflictPair("lion", "bunny"), ConflictPair("bunny", "lion"))
    }

    func test_conflictPair_hashableInSet() {
        let set: Set<ConflictPair> = [ConflictPair("lion", "bunny")]
        XCTAssertTrue(set.contains(ConflictPair("bunny", "lion")))
    }

    func test_conflictPair_involves() {
        let pair = ConflictPair("lion", "bunny")
        XCTAssertTrue(pair.involves("lion"))
        XCTAssertTrue(pair.involves("bunny"))
        XCTAssertFalse(pair.involves("bear"))
    }

    // MARK: - canTapGo Core Rules

    func test_canTapGo_falseWhenBridgeEmpty() {
        let mgr = makeManager()
        XCTAssertFalse(mgr.canTapGo(sourceSide: .left))
    }

    func test_canTapGo_falseWhenEscortMissing() {
        let mgr = makeManager(level: Levels.level1)
        let escortId = mgr.level.mandatoryEscortId!
        let nonEscort = mgr.leftBank.first { $0.id != escortId }!
        mgr.stuffieMovedToBridge(nonEscort)
        XCTAssertFalse(mgr.canTapGo(sourceSide: .left))
    }

    func test_canTapGo_trueWithEscort() {
        let mgr = makeManager(level: Levels.level1)
        putOnBridge(Levels.level1.hintSequence[0], from: .left, in: mgr)
        XCTAssertTrue(mgr.canTapGo(sourceSide: .left))
    }

    // MARK: - Conflict Reaction

    func test_conflictReaction_triggeredByBadCrossing() {
        // Ellie alone on L1 leaves Lion+Bunny — conflict detected → conflictReaction state.
        let mgr = makeManager(level: Levels.level1)
        let escortId = mgr.level.mandatoryEscortId!
        cross([escortId], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
        XCTAssertFalse(mgr.conflictingIds.isEmpty)
    }

    func test_conflictReactionCompleted_restoresState() {
        let mgr = makeManager(level: Levels.level1)
        let escortId = mgr.level.mandatoryEscortId!
        let initialLeft = mgr.leftBank.map(\.id).sorted()

        cross([escortId], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)

        mgr.conflictReactionCompleted()
        XCTAssertEqual(mgr.state, .idle)
        XCTAssertEqual(mgr.leftBank.map(\.id).sorted(), initialLeft)
        XCTAssertTrue(mgr.rightBank.isEmpty)
        XCTAssertTrue(mgr.conflictingIds.isEmpty)
    }

    // MARK: - Initial State

    func test_initialState_isIntro() {
        let mgr = GameStateManager(level: Levels.level1)
        XCTAssertEqual(mgr.state, .intro)
    }

    func test_initialState_allStuffiesOnLeft() {
        let mgr = makeManager()
        XCTAssertEqual(mgr.leftBank.count, mgr.level.stuffies.count)
        XCTAssertTrue(mgr.rightBank.isEmpty)
    }

    // MARK: - State Transitions

    func test_stuffieOnBridge_transitionsToSelecting() {
        let mgr = makeManager()
        mgr.stuffieMovedToBridge(mgr.leftBank[0])
        XCTAssertEqual(mgr.state, .selecting)
    }

    func test_removeAllFromBridge_transitionsBackToIdle() {
        let mgr = makeManager()
        let s = mgr.leftBank[0]
        mgr.stuffieMovedToBridge(s)
        mgr.stuffieRemovedFromBridge(s)
        XCTAssertEqual(mgr.state, .idle)
    }

    func test_goTapped_transitionsToAnimating() {
        let mgr = makeManager()
        putOnBridge(Levels.level1.hintSequence[0], from: .left, in: mgr)
        mgr.goTapped(sourceSide: .left)
        XCTAssertEqual(mgr.state, .animating)
    }

    // MARK: - Bridge Capacity

    func test_bridgeCapacity_enforcedAtMax() {
        let mgr = makeManager()
        for s in mgr.leftBank {
            mgr.stuffieMovedToBridge(s)
        }
        XCTAssertEqual(mgr.onBridge.count, mgr.level.bridgeCapacity)
    }

    func test_duplicateStuffie_notAddedToBridge() {
        let mgr = makeManager()
        let s = mgr.leftBank[0]
        mgr.stuffieMovedToBridge(s)
        mgr.stuffieMovedToBridge(s)
        XCTAssertEqual(mgr.onBridge.count, 1)
    }

    // MARK: - Level 1

    func test_level1_hintSolution_win() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)   // E+Lion →
        cross(h[1], from: .right, in: mgr)  // E ←
        cross(h[2], from: .left, in: mgr)   // E+Bunny → WIN
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 3)
        XCTAssertTrue(mgr.leftBank.isEmpty)
    }

    func test_level1_withoutEscort_blocked() {
        let mgr = makeManager(level: Levels.level1)
        let escortId = mgr.level.mandatoryEscortId!
        let nonEscort = mgr.leftBank.first { $0.id != escortId }!
        mgr.stuffieMovedToBridge(nonEscort)
        XCTAssertFalse(mgr.canTapGo(sourceSide: .left))
    }

    func test_level1_ellieAlone_triggersConflictReaction() {
        // Ellie alone leaves Lion+Bunny on left — conflict
        let mgr = makeManager(level: Levels.level1)
        let escortId = mgr.level.mandatoryEscortId!
        cross([escortId], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    // MARK: - Level 2

    func test_level2_hintSolution_win() {
        let mgr = makeManager(level: Levels.level2)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)   // E+Bunny →
        cross(h[1], from: .right, in: mgr)  // E ←
        cross(h[2], from: .left, in: mgr)   // E+Lion →
        cross(h[3], from: .right, in: mgr)  // E+Bunny ←
        cross(h[4], from: .left, in: mgr)   // E+Duck →
        cross(h[5], from: .right, in: mgr)  // E ←
        cross(h[6], from: .left, in: mgr)   // E+Bunny → WIN
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 4)
    }

    func test_level2_lionFirstMove_triggersConflictReaction() {
        // E+Lion leaves Bunny+Duck alone on left
        let mgr = makeManager(level: Levels.level2)
        let escortId = mgr.level.mandatoryEscortId!
        cross([escortId, "lion"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    func test_level2_duckFirstMove_triggersConflictReaction() {
        // E+Duck leaves Lion+Bunny alone on left
        let mgr = makeManager(level: Levels.level2)
        let escortId = mgr.level.mandatoryEscortId!
        cross([escortId, "duck"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    func test_level2_escortAloneBack_triggersConflictReaction() {
        // After E+Bunny→, E←, E+Lion→: Ellie alone back leaves Bunny+Lion on right.
        let mgr = makeManager(level: Levels.level2)
        let h = mgr.level.hintSequence
        let escortId = mgr.level.mandatoryEscortId!
        cross(h[0], from: .left, in: mgr)
        cross(h[1], from: .right, in: mgr)
        cross(h[2], from: .left, in: mgr)
        cross([escortId], from: .right, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    // MARK: - Level 3

    func test_level3_hintSolution_win() {
        let mgr = makeManager(level: Levels.level3)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        cross(h[1], from: .right, in: mgr)
        cross(h[2], from: .left, in: mgr)
        cross(h[3], from: .right, in: mgr)
        cross(h[4], from: .left, in: mgr)
        cross(h[5], from: .right, in: mgr)
        cross(h[6], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 5)
    }

    func test_level3_allFirstMoves_canTapGo() {
        // 5 stuffies: any E+X first move has escort present → canTapGo is true.
        let escortId = Levels.level3.mandatoryEscortId!
        let nonEscorts = Levels.level3.stuffies.filter { $0.id != escortId }
        for passenger in nonEscorts {
            let mgr = makeManager(level: Levels.level3)
            putOnBridge([escortId, passenger.id], from: .left, in: mgr)
            XCTAssertTrue(mgr.canTapGo(sourceSide: .left),
                          "E+\(passenger.id) should have Go enabled in Level 3")
        }
    }

    func test_level3_bunnyThenLion_escortAloneBack_triggersConflictReaction() {
        // E+Bunny→, E←, E+Lion→: Ellie alone back leaves Bunny+Lion on right.
        let mgr = makeManager(level: Levels.level3)
        let escortId = mgr.level.mandatoryEscortId!
        cross([escortId, "bunny"], from: .left, in: mgr)
        cross([escortId], from: .right, in: mgr)
        cross([escortId, "lion"], from: .left, in: mgr)
        cross([escortId], from: .right, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    // MARK: - Level 4

    func test_level4_hintSolution_win() {
        let mgr = makeManager(level: Levels.level4)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        cross(h[1], from: .right, in: mgr)
        cross(h[2], from: .left, in: mgr)
        cross(h[3], from: .right, in: mgr)
        cross(h[4], from: .left, in: mgr)
        cross(h[5], from: .right, in: mgr)
        cross(h[6], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 5)
    }

    func test_level4_afterLionBack_conflictReaction() {
        // After E+Lion→, E←: E+Bunny leaves Duck+Bear; E+Bear leaves Bunny+Duck — both conflict.
        // E+Duck leaves Bunny+Bear — no conflict.
        let escortId = Levels.level4.mandatoryEscortId!

        let m1 = makeManager(level: Levels.level4)
        cross([escortId, "lion"], from: .left, in: m1)
        cross([escortId], from: .right, in: m1)
        cross([escortId, "bunny"], from: .left, in: m1)
        XCTAssertEqual(m1.state, .conflictReaction, "E+Bunny leaves Duck+Bear")

        let m2 = makeManager(level: Levels.level4)
        cross([escortId, "lion"], from: .left, in: m2)
        cross([escortId], from: .right, in: m2)
        cross([escortId, "bear"], from: .left, in: m2)
        XCTAssertEqual(m2.state, .conflictReaction, "E+Bear leaves Bunny+Duck")

        let m3 = makeManager(level: Levels.level4)
        cross([escortId, "lion"], from: .left, in: m3)
        cross([escortId], from: .right, in: m3)
        cross([escortId, "duck"], from: .left, in: m3)
        XCTAssertNotEqual(m3.state, .conflictReaction, "E+Duck leaves Bunny+Bear — valid")
    }

    // MARK: - Level 5

    func test_level5_bridgeCapacity3() {
        let mgr = makeManager(level: Levels.level5)
        XCTAssertEqual(mgr.level.bridgeCapacity, 3)
        putOnBridge(["ellie", "lion", "duck"], from: .left, in: mgr)
        XCTAssertEqual(mgr.onBridge.count, 3)
        mgr.stuffieMovedToBridge(mgr.leftBank.first { $0.id == "bear" }!)
        XCTAssertEqual(mgr.onBridge.count, 3)
    }

    func test_level5_hintSolution_win() {
        let mgr = makeManager(level: Levels.level5)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)   // E+Lion+Duck →
        cross(h[1], from: .right, in: mgr)  // E+Duck ←
        cross(h[2], from: .left, in: mgr)   // E+Bunny+Bear →
        cross(h[3], from: .right, in: mgr)  // E ←
        cross(h[4], from: .left, in: mgr)   // E+Duck → WIN
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 5)
    }

    func test_level5_onlyLionDuckGrouping_succeeds() {
        // All E+X+Y have escort → canTapGo true.
        // Only E+Lion+Duck avoids conflict reaction (leaves Bunny+Bear — not a conflict pair).
        let escortId = Levels.level5.mandatoryEscortId!
        let pairs = [("lion", "bunny"), ("lion", "duck"), ("lion", "bear"),
                     ("bunny", "duck"), ("bunny", "bear"), ("duck", "bear")]
        for (p1, p2) in pairs {
            let mgr = makeManager(level: Levels.level5)
            cross([escortId, p1, p2], from: .left, in: mgr)
            let isLionDuck = Set([p1, p2]) == Set(["lion", "duck"])
            if isLionDuck {
                XCTAssertNotEqual(mgr.state, .conflictReaction, "E+\(p1)+\(p2) should succeed")
            } else {
                XCTAssertEqual(mgr.state, .conflictReaction, "E+\(p1)+\(p2) should conflict")
            }
        }
    }

    func test_level5_escortAloneBack_triggersConflictReaction() {
        // After E+Lion+Duck→, Ellie alone back leaves Lion+Duck on right — conflict.
        let mgr = makeManager(level: Levels.level5)
        let h = mgr.level.hintSequence
        let escortId = mgr.level.mandatoryEscortId!
        cross(h[0], from: .left, in: mgr)   // E+Lion+Duck →
        cross([escortId], from: .right, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    // MARK: - Bidirectional Crossing

    func test_bidirectionalCrossing_stuffiesMoveBothWays() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        let rightIds = mgr.rightBank.map(\.id).sorted()
        XCTAssertEqual(rightIds, h[0].sorted())
        cross(h[1], from: .right, in: mgr)
        XCTAssertTrue(mgr.rightBank.allSatisfy { $0.id != mgr.level.mandatoryEscortId })
    }

    // MARK: - Undo

    func test_undo_restoresStateBeforeMove() {
        let mgr = makeManager(level: Levels.level1)
        let initialLeft = mgr.leftBank.map(\.id).sorted()
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        mgr.undoTapped()
        XCTAssertEqual(mgr.leftBank.map(\.id).sorted(), initialLeft)
        XCTAssertTrue(mgr.rightBank.isEmpty)
        XCTAssertEqual(mgr.state, .idle)
    }

    func test_undo_noOpWhenNoHistory() {
        let mgr = makeManager()
        mgr.undoTapped()
        XCTAssertEqual(mgr.state, .idle)
    }

    // MARK: - Restart

    func test_restart_resetsToInitialState() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        mgr.restartTapped()
        XCTAssertEqual(mgr.state, .intro)
        XCTAssertEqual(mgr.leftBank.count, mgr.level.stuffies.count)
        XCTAssertTrue(mgr.rightBank.isEmpty)
        XCTAssertTrue(mgr.onBridge.isEmpty)
    }

    // MARK: - Hint System

    func test_hint_returnsFirstMoveBeforeAnyMove() {
        let mgr = makeManager(level: Levels.level1)
        let hint = mgr.hintTapped()
        XCTAssertEqual(hint?.sorted(), mgr.level.hintSequence[0].sorted())
    }

    func test_hint_returnsSecondMoveAfterFirstCrossing() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        let hint = mgr.hintTapped()
        XCTAssertEqual(hint?.sorted(), h[1].sorted())
    }

    func test_hint_returnsNilAfterAllMovesUsed() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        cross(h[1], from: .right, in: mgr)
        cross(h[2], from: .left, in: mgr)
        XCTAssertNil(mgr.hintTapped())
    }

    // MARK: - Edge Cases

    func test_singleStuffieOnBank_neverConflicts() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        XCTAssertEqual(mgr.leftBank.count, 1)
        XCTAssertEqual(mgr.state, .idle)
    }

    func test_threeStuffiesOnSameBank_noConflictCheck() {
        let mgr = makeManager(level: Levels.level1)
        let h = mgr.level.hintSequence
        cross(h[0], from: .left, in: mgr)
        cross(h[1], from: .right, in: mgr)
        cross(h[2], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 3)
    }
}
