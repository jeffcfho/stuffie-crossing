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
    func conflictDetectedBetween(_ a: Stuffie, _ b: Stuffie, onBank: BankSide)
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
        didSet {
            delegate?.gameStateDidTransition(to: state)
            overlayDelegate?.gameStateDidChange(canGo: state == .selecting)
        }
    }

    private(set) var level: Level
    private(set) var leftBank: [Stuffie]
    private(set) var rightBank: [Stuffie]
    private(set) var onBridge: [Stuffie] = []
    private var moveHistory: [MoveSnapshot] = []
    private var retryCount: Int = 0

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
        onBridge.append(stuffie)
        state = onBridge.isEmpty ? .idle : .selecting
    }

    func stuffieRemovedFromBridge(_ stuffie: Stuffie) {
        guard state == .selecting else { return }
        onBridge.removeAll { $0.id == stuffie.id }
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
        leftBank = level.stuffies
        rightBank = []
        retryCount = 0
        state = .intro
    }

    // MARK: - Internal

    private func applyBridgeCrossing(from sourceSide: BankSide) {
        let crossers = onBridge
        onBridge.removeAll()
        switch sourceSide {
        case .left:
            leftBank.removeAll { s in crossers.contains { $0.id == s.id } }
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

        if let (a, b, side) = firstConflict() {
            retryCount += 1
            delegate?.conflictDetectedBetween(a, b, onBank: side)
            state = .conflictReaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.state = .idle
            }
        } else {
            state = .idle
        }
    }

    private func firstConflict() -> (Stuffie, Stuffie, BankSide)? {
        // Conflict only fires when exactly 2 stuffies are alone together on a bank.
        // A 3rd stuffie's presence prevents the conflict (they're not "alone").
        for side in [BankSide.left, BankSide.right] {
            let bank = side == .left ? leftBank : rightBank
            guard bank.count == 2 else { continue }
            if bank[0].conflictsWith(bank[1]) {
                return (bank[0], bank[1], side)
            }
        }
        return nil
    }

    private func markLevelComplete() {
        var completed = completedLevelIds()
        completed.insert(level.id)
        UserDefaults.standard.set(Array(completed), forKey: "completedLevelIds")
    }

    static func completedLevelIds() -> Set<Int> {
        let arr = UserDefaults.standard.array(forKey: "completedLevelIds") as? [Int] ?? []
        return Set(arr)
    }

    private func completedLevelIds() -> Set<Int> {
        GameStateManager.completedLevelIds()
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
    }
}
