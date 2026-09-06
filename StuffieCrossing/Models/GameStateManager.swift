import Foundation

enum GameState {
    case intro
    case idle
    case selecting
    case animating
    case checking
    case conflictReaction
    case win
}

protocol GameStateDelegate: AnyObject {
    func gameStateDidTransition(to state: GameState)
}

protocol GameOverlayDelegate: AnyObject {
    func gameStateDidChange(canGo: Bool)
}

enum BankSide {
    case left, right
}

class GameStateManager {

    weak var delegate: GameStateDelegate?
    weak var overlayDelegate: GameOverlayDelegate?

    private(set) var state: GameState = .intro {
        didSet { delegate?.gameStateDidTransition(to: state) }
    }

    private(set) var level: Level
    private(set) var leftBank: [Stuffie]
    private(set) var rightBank: [Stuffie]
    private(set) var onBridge: [Stuffie] = []
    // Which bank the current bridge load departs from. nil when the bridge is empty.
    // The bridge may only ever hold stuffies travelling in one direction: a mixed
    // load made applyBridgeCrossing(from:) append a stuffie to the bank it was
    // already on, duplicating it and inflating the win count.
    private(set) var bridgeSourceSide: BankSide?
    // IDs of the two stuffies whose conflict was detected after the last crossing.
    private(set) var conflictingIds: [String] = []
    private var moveHistory: [MoveSnapshot] = []

    init(level: Level) {
        self.level = level
        self.leftBank = level.stuffies
        self.rightBank = []
    }

    // MARK: - Player Actions

    func introCompleted() {
        guard state == .intro else { return }
        state = .idle
    }

    func stuffieMovedToBridge(_ stuffie: Stuffie) {
        guard state == .idle || state == .selecting else { return }
        guard onBridge.count < level.bridgeCapacity else { return }
        guard !onBridge.contains(where: { $0.id == stuffie.id }) else { return }
        // A stuffie on the bridge is still listed on its bank until the crossing
        // is applied, so its current bank is its departure side.
        guard let side = bankSide(of: stuffie) else { return }
        guard bridgeSourceSide == nil || bridgeSourceSide == side else { return }
        onBridge.append(stuffie)
        bridgeSourceSide = side
        state = onBridge.isEmpty ? .idle : .selecting
    }

    // The bank a stuffie currently stands on, or nil if it is on neither.
    func bankSide(of stuffie: Stuffie) -> BankSide? {
        if leftBank.contains(where:  { $0.id == stuffie.id }) { return .left }
        if rightBank.contains(where: { $0.id == stuffie.id }) { return .right }
        return nil
    }

    func stuffieRemovedFromBridge(_ stuffie: Stuffie) {
        guard state == .selecting else { return }
        onBridge.removeAll { $0.id == stuffie.id }
        if onBridge.isEmpty { bridgeSourceSide = nil }
        state = onBridge.isEmpty ? .idle : .selecting
    }

    func goTapped(sourceSide: BankSide) {
        guard state == .selecting, !onBridge.isEmpty else { return }
        snapshotForUndo(sourceSide: sourceSide)
        state = .animating
    }

    func animationCompleted(sourceSide: BankSide) {
        guard state == .animating else { return }
        applyBridgeCrossing(from: sourceSide)
        state = .checking
        evaluateAfterCrossing()
    }

    // Called by GameScene after the conflict reaction animation finishes.
    func conflictReactionCompleted() {
        guard state == .conflictReaction else { return }
        if let snapshot = moveHistory.popLast() {
            restoreSnapshot(snapshot)
        }
        conflictingIds = []
        state = .idle
    }

    func hintTapped() -> [String]? {
        guard state == .idle || state == .selecting else { return nil }
        let step = moveHistory.count
        guard step < level.hintSequence.count else { return nil }
        return level.hintSequence[step]
    }

    func undoTapped() {
        guard let snapshot = moveHistory.popLast() else { return }
        restoreSnapshot(snapshot)
        state = .idle
    }

    func restartTapped() {
        moveHistory.removeAll()
        onBridge.removeAll()
        bridgeSourceSide = nil
        leftBank = level.stuffies
        rightBank = []
        state = .intro
    }

    // MARK: - Go Button Validity

    // Returns true if the Go button should be enabled.
    // Only checks escort presence — conflicts are handled reactively via conflictReaction state.
    func canTapGo(sourceSide: BankSide) -> Bool {
        guard state == .idle || state == .selecting else { return false }
        guard !onBridge.isEmpty else { return false }
        if let escortId = level.mandatoryEscortId,
           !onBridge.contains(where: { $0.id == escortId }) {
            return false
        }
        return true
    }

    // MARK: - Internal

    private func applyBridgeCrossing(from sourceSide: BankSide) {
        let crossers = onBridge
        onBridge.removeAll()
        bridgeSourceSide = nil
        switch sourceSide {
        case .left:
            leftBank.removeAll  { s in crossers.contains { $0.id == s.id } }
            rightBank.append(contentsOf: crossers)
        case .right:
            rightBank.removeAll { s in crossers.contains { $0.id == s.id } }
            leftBank.append(contentsOf: crossers)
        }
    }

    private func evaluateAfterCrossing() {
        if rightBank.count == level.stuffies.count && leftBank.isEmpty && onBridge.isEmpty {
            state = .win
            markLevelComplete()
            return
        }
        if let ids = conflictingPairIds(in: leftBank) ?? conflictingPairIds(in: rightBank) {
            conflictingIds = ids
            state = .conflictReaction
        } else {
            state = .idle
        }
    }

    private func conflictingPairIds(in bank: [Stuffie]) -> [String]? {
        guard bank.count == 2,
              level.conflicts.contains(ConflictPair(bank[0].id, bank[1].id)) else { return nil }
        return [bank[0].id, bank[1].id]
    }

    // MARK: - Persistence

    private static let completedLevelIdsKey = "completedLevelIds"
    private static let devModeKey = "devMode"

    private func markLevelComplete() {
        var completed = GameStateManager.completedLevelIds()
        completed.insert(level.id)
        UserDefaults.standard.set(Array(completed), forKey: GameStateManager.completedLevelIdsKey)
    }

    static func completedLevelIds() -> Set<Int> {
        let arr = UserDefaults.standard.array(forKey: completedLevelIdsKey) as? [Int] ?? []
        return Set(arr)
    }

    static func resetProgress() {
        UserDefaults.standard.removeObject(forKey: completedLevelIdsKey)
    }

    static func enableDevMode() {
        UserDefaults.standard.set(true, forKey: devModeKey)
    }

    static func disableDevMode() {
        UserDefaults.standard.removeObject(forKey: devModeKey)
    }

    static func isDevModeEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: devModeKey)
    }

    // MARK: - Undo

    private struct MoveSnapshot {
        let leftBank: [Stuffie]
        let rightBank: [Stuffie]
        let onBridge: [Stuffie]
        let sourceSide: BankSide
    }

    private func snapshotForUndo(sourceSide: BankSide) {
        moveHistory.append(MoveSnapshot(
            leftBank: leftBank,
            rightBank: rightBank,
            onBridge: onBridge,
            sourceSide: sourceSide
        ))
    }

    private func restoreSnapshot(_ snapshot: MoveSnapshot) {
        leftBank = snapshot.leftBank
        rightBank = snapshot.rightBank
        onBridge = snapshot.onBridge
        bridgeSourceSide = snapshot.onBridge.isEmpty ? nil : snapshot.sourceSide
    }
}
