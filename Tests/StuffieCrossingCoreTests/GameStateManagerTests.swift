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

    private func allStuffies(_ mgr: GameStateManager) -> [Stuffie] {
        mgr.leftBank + mgr.rightBank + mgr.onBridge
    }

    // MARK: - Initial State

    func test_initialState_isIntro() {
        let mgr = GameStateManager(level: Levels.level1)
        XCTAssertEqual(mgr.state, .intro)
    }

    func test_initialState_allStuffiesOnLeft() {
        let mgr = makeManager()
        XCTAssertEqual(mgr.leftBank.count, 3)
        XCTAssertTrue(mgr.rightBank.isEmpty)
    }

    // MARK: - State Transitions: IDLE → SELECTING

    func test_stuffieOnBridge_transitionsToSelecting() {
        let mgr = makeManager()
        mgr.leftBank.first.map { mgr.stuffieMovedToBridge($0) }
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
        mgr.stuffieMovedToBridge(mgr.leftBank[0])
        mgr.goTapped(sourceSide: .left)
        XCTAssertEqual(mgr.state, .animating)
    }

    // MARK: - Bridge Capacity

    func test_bridgeCapacity_enforcedAtMax() {
        let mgr = makeManager()
        let bank = mgr.leftBank
        for s in bank {
            mgr.stuffieMovedToBridge(s)  // Level1 capacity = 2; 3rd stuffie should be ignored
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

    // MARK: - Conflict Detection

    func test_conflictDetection_onlyWhenExactlyTwoAlone() {
        // Level 1: Lion-Bunny conflict. After Bear+Bunny cross right,
        // Lion is ALONE on left (1 stuffie) = no conflict.
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        // Lion alone on left — should not be a conflict
        XCTAssertEqual(mgr.state, .idle)
        XCTAssertEqual(mgr.leftBank.count, 1)
        XCTAssertEqual(mgr.leftBank[0].id, "lion")
    }

    func test_conflictDetection_lionAndBunnyAlone_triggers() {
        // If we leave Lion and Bunny alone on a bank, should get conflict reaction
        let mgr = makeManager()
        // Send Bear across alone — left has Lion+Bunny alone
        cross(["bear"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    func test_noConflict_threeStuffiesOnSameBank() {
        // Three stuffies together — Lion+Bunny not "alone" — no conflict
        // This validates win is reachable: all 3 ending up on right = WIN, not conflict
        let mgr = makeManager()
        // Level 1 solution path A: Bear+Bunny right, Bear back, Bear+Lion right
        cross(["bear", "bunny"], from: .left, in: mgr)
        cross(["bear"], from: .right, in: mgr)
        cross(["bear", "lion"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
    }

    // MARK: - Level 1 Win Paths

    func test_level1_solutionPathA_win() {
        // Bear+Bunny right, Bear back, Bear+Lion right
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .idle)
        cross(["bear"], from: .right, in: mgr)
        XCTAssertEqual(mgr.state, .idle)
        cross(["bear", "lion"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
        XCTAssertEqual(mgr.rightBank.count, 3)
        XCTAssertTrue(mgr.leftBank.isEmpty)
    }

    func test_level1_solutionPathB_win() {
        // Bear+Lion right, Bear back, Bear+Bunny right
        let mgr = makeManager()
        cross(["bear", "lion"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .idle)
        cross(["bear"], from: .right, in: mgr)
        XCTAssertEqual(mgr.state, .idle)
        cross(["bear", "bunny"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
    }

    // MARK: - Level 2 Win Path

    func test_level2_solutionPath_win() {
        // Level 2: Bear conflicts Lion, Lion conflicts Bunny.
        // Bear+Bunny right (Lion alone = safe), then Lion right.
        let level2 = Levels.allLevels()[1]
        let mgr = makeManager(level: level2)
        cross(["bear", "bunny"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .idle, "After Bear+Bunny cross, Lion alone on left = no conflict")
        cross(["lion"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .win)
    }

    func test_level2_bearAndLionAlone_conflict() {
        let level2 = Levels.allLevels()[1]
        let mgr = makeManager(level: level2)
        // Send Bunny alone right → left has Bear+Lion
        cross(["bunny"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    func test_level2_lionAndBunnyAlone_conflict() {
        let level2 = Levels.allLevels()[1]
        let mgr = makeManager(level: level2)
        // Send Bear alone right → left has Lion+Bunny
        cross(["bear"], from: .left, in: mgr)
        XCTAssertEqual(mgr.state, .conflictReaction)
    }

    // MARK: - Bidirectional Crossing

    func test_birectionalCrossing_stuffiesMoveBothWays() {
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        XCTAssertEqual(mgr.rightBank.map(\.id).sorted(), ["bear", "bunny"])
        cross(["bear"], from: .right, in: mgr)
        XCTAssertEqual(mgr.leftBank.map(\.id).sorted(), ["bear", "lion"])
    }

    // MARK: - Undo

    func test_undo_restoresStateBeforeMove() {
        let mgr = makeManager()
        let initialLeft = mgr.leftBank.map(\.id).sorted()
        cross(["bear", "bunny"], from: .left, in: mgr)
        mgr.undoTapped()
        XCTAssertEqual(mgr.leftBank.map(\.id).sorted(), initialLeft)
        XCTAssertTrue(mgr.rightBank.isEmpty)
        XCTAssertEqual(mgr.state, .idle)
    }

    func test_undo_noOpWhenNoHistory() {
        let mgr = makeManager()
        mgr.undoTapped()
        XCTAssertEqual(mgr.state, .idle)  // no crash, no state change
    }

    // MARK: - Restart

    func test_restart_resetsToInitialState() {
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        mgr.restartTapped()
        XCTAssertEqual(mgr.state, .intro)
        XCTAssertEqual(mgr.leftBank.count, 3)
        XCTAssertTrue(mgr.rightBank.isEmpty)
        XCTAssertTrue(mgr.onBridge.isEmpty)
    }

    // MARK: - Hint System

    func test_hint_returnsFirstMoveBeforeAnyMove() {
        let mgr = makeManager()
        let hint = mgr.hintTapped()
        XCTAssertEqual(hint?.sorted(), ["bear", "bunny"])
    }

    func test_hint_returnsSecondMoveAfterFirstCrossing() {
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        let hint = mgr.hintTapped()
        XCTAssertEqual(hint, ["bear"])
    }

    func test_hint_returnsNilAfterAllMovesUsed() {
        let mgr = makeManager()
        // Execute all 3 hint moves for Level 1
        cross(["bear", "bunny"], from: .left, in: mgr)
        cross(["bear"], from: .right, in: mgr)
        cross(["bear", "lion"], from: .left, in: mgr)
        let hint = mgr.hintTapped()
        XCTAssertNil(hint)
    }

    // MARK: - Conflict Semantics Edge Cases

    func test_singleStuffieOnBank_neverConflicts() {
        let mgr = makeManager()
        cross(["bear", "bunny"], from: .left, in: mgr)
        // Lion alone on left — 1 stuffie, never a conflict
        XCTAssertNotEqual(mgr.state, .conflictReaction)
    }

    func test_stuffieConflict_isBidirectional() {
        // Lion has conflicts=["bunny"], Bear has conflicts=[].
        // Lion.conflictsWith(bunny) should be true.
        // bunny.conflictsWith(lion) should also be true (checked from other direction).
        let lion = Levels.lion
        let bunny = Levels.bunny
        XCTAssertTrue(lion.conflictsWith(bunny))
        XCTAssertTrue(bunny.conflictsWith(lion))
    }

    func test_stuffieNoConflict_withNeutralPair() {
        let bear = Levels.bear
        let bunny = Levels.bunny
        XCTAssertFalse(bear.conflictsWith(bunny))
        XCTAssertFalse(bunny.conflictsWith(bear))
    }
}
