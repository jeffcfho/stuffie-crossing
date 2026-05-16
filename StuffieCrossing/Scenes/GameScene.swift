import SpriteKit

class GameScene: SKScene {

    let stateManager: GameStateManager
    weak var overlayDelegate: GameOverlayDelegate?

    private(set) var bridgeNode: BridgeNode!
    private var leftBankNode: BankNode!
    private var rightBankNode: BankNode!

    // Single source of truth for all stuffie nodes, keyed by stuffie ID
    private var stuffieNodes: [String: StuffieNode] = [:]

    init(level: Level, size: CGSize) {
        stateManager = GameStateManager(level: level)
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.3, green: 0.7, blue: 0.95, alpha: 1)
        stateManager.delegate = self
        setupNodes()
        populateLevel()
        // Skip intro animation for MVP — go straight to interactive
        stateManager.introCompleted()
    }

    // MARK: - Setup

    private func setupNodes() {
        let cx = size.width / 2
        let cy = size.height / 2
        let gap: CGFloat = 30

        bridgeNode = BridgeNode()
        bridgeNode.position = CGPoint(x: cx, y: cy)
        addChild(bridgeNode)

        leftBankNode = BankNode(side: .left)
        leftBankNode.position = CGPoint(
            x: cx - BridgeLayout.width / 2 - gap - BankLayout.width / 2,
            y: cy
        )
        addChild(leftBankNode)

        rightBankNode = BankNode(side: .right)
        rightBankNode.position = CGPoint(
            x: cx + BridgeLayout.width / 2 + gap + BankLayout.width / 2,
            y: cy
        )
        addChild(rightBankNode)
    }

    private func populateLevel() {
        placeStuffies(stateManager.leftBank, on: leftBankNode)
        placeStuffies(stateManager.rightBank, on: rightBankNode)
    }

    // Creates StuffieNodes as direct scene children, positioned at bank slots.
    private func placeStuffies(_ stuffies: [Stuffie], on bank: BankNode) {
        let slots = bank.slotPositions(count: stuffies.count)
        for (stuffie, localSlot) in zip(stuffies, slots) {
            let node = makeStuffieNode(stuffie, bank: bank)
            let scenePos = CGPoint(x: bank.position.x + localSlot.x,
                                   y: bank.position.y + localSlot.y)
            node.restingPosition = scenePos
            node.position = scenePos
            addChild(node)
        }
    }

    private func makeStuffieNode(_ stuffie: Stuffie, bank: BankNode) -> StuffieNode {
        let node = StuffieNode(stuffie: stuffie)
        node.sourceBankNode = bank
        stuffieNodes[stuffie.id] = node
        return node
    }

    // MARK: - Bridge Interaction

    func stuffieDroppedOnBridge(_ node: StuffieNode) {
        stateManager.stuffieMovedToBridge(node.stuffie)
        // Recalculate bridge slot positions for all bridge stuffies
        repositionBridgeStuffies()
    }

    func stuffieDroppedOffBridge(_ node: StuffieNode) {
        // If stuffie was on the bridge, remove it from bridge state
        if stateManager.onBridge.contains(where: { $0.id == node.stuffie.id }) {
            stateManager.stuffieRemovedFromBridge(node.stuffie)
            repositionBridgeStuffies()
        }
        node.snapToRestingPosition()
    }

    private func repositionBridgeStuffies() {
        let bridgeStuffies = stateManager.onBridge
        let count = bridgeStuffies.count
        // Space stuffies evenly across bridge width
        let spacing = min(StuffieSize.width + 8, BridgeLayout.width / CGFloat(max(count, 1)))
        let totalW = spacing * CGFloat(count - 1)
        for (i, stuffie) in bridgeStuffies.enumerated() {
            guard let node = stuffieNodes[stuffie.id] else { continue }
            let x = bridgeNode.position.x - totalW / 2 + spacing * CGFloat(i)
            let slot = CGPoint(x: x, y: bridgeNode.position.y)
            node.restingPosition = slot
            node.removeAction(forKey: "snapBack")
            node.run(SKAction.move(to: slot, duration: 0.15), withKey: "snapBack")
        }
    }

    // MARK: - Overlay Actions

    func handleGoTapped() {
        stateManager.goTapped(sourceSide: currentBridgeSourceSide())
    }

    func handleHintTapped() {
        guard let ids = stateManager.hintTapped() else { return }
        for id in ids {
            stuffieNodes[id]?.wiggle()
        }
    }

    func handleUndoTapped() {
        stateManager.undoTapped()
        // rebuild triggered by state transitioning to .idle
    }

    func handleRestartTapped() {
        stateManager.restartTapped()
        stateManager.introCompleted()
        // rebuild triggered by state transitioning to .idle
    }

    // MARK: - Animations

    private func animateCrossing(sourceSide: BankSide) {
        let crossers = stateManager.onBridge.compactMap { stuffieNodes[$0.id] }
        let targetX = sourceSide == .left ? rightBankNode.position.x : leftBankNode.position.x

        let move = SKAction.moveTo(x: targetX, duration: 0.55)
        move.timingMode = .easeInEaseOut

        let group = DispatchGroup()
        for node in crossers {
            group.enter()
            node.run(move) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            self?.stateManager.animationCompleted(sourceSide: sourceSide)
            // rebuildStuffieNodes() is called in gameStateDidTransition(.idle)
            // so conflict shakes play fully before nodes are replaced
        }
    }

    // Destroys and recreates all stuffie nodes to match current state manager state.
    private func rebuildStuffieNodes() {
        stuffieNodes.values.forEach { $0.removeFromParent() }
        stuffieNodes.removeAll()
        populateLevel()
    }

    // MARK: - Helpers

    private func currentBridgeSourceSide() -> BankSide {
        stateManager.onBridge
            .compactMap { stuffieNodes[$0.id]?.sourceBankNode?.side }
            .first ?? .left
    }
}

// MARK: - GameStateDelegate

extension GameScene: GameStateDelegate {

    func gameStateDidTransition(to state: GameState) {
        overlayDelegate?.gameStateDidChange(canGo: state == .selecting)

        switch state {
        case .idle:
            rebuildStuffieNodes()
        case .animating:
            animateCrossing(sourceSide: currentBridgeSourceSide())
        case .win:
            showWinCelebration()
        default:
            break
        }
    }

    func conflictDetectedBetween(_ a: Stuffie, _ b: Stuffie, onBank: BankSide) {
        stuffieNodes[a.id]?.shakeForConflict()
        stuffieNodes[b.id]?.shakeForConflict()
    }

    private func showWinCelebration() {
        let celebrate = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                guard let self, let view = self.view else { return }
                let menu = MenuScene(size: self.size)
                menu.scaleMode = .resizeFill
                view.presentScene(menu, transition: SKTransition.fade(withDuration: 0.8))
                if let vc = view.next as? GameViewController {
                    vc.hideGameOverlay()
                }
            }
        ])
        run(celebrate)
    }
}
