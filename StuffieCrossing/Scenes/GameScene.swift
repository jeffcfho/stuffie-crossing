import SpriteKit

class GameScene: SKScene {

    let stateManager: GameStateManager
    weak var overlayDelegate: GameOverlayDelegate?

    private(set) var bridgeNode: BridgeNode!
    private var leftBankNode: BankNode!
    private var rightBankNode: BankNode!

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
        stateManager.introCompleted()
    }

    // MARK: - Setup

    private func setupNodes() {
        let cx = size.width / 2
        let cy = size.height / 2
        let gap: CGFloat = 30
        let stuffieCount = stateManager.level.stuffies.count

        bridgeNode = BridgeNode(capacity: stateManager.level.bridgeCapacity)
        bridgeNode.position = CGPoint(x: cx, y: cy)
        addChild(bridgeNode)

        leftBankNode = BankNode(side: .left, stuffieCount: stuffieCount)
        leftBankNode.position = CGPoint(
            x: cx - bridgeNode.plankWidth / 2 - gap - BankLayout.width / 2,
            y: cy
        )
        addChild(leftBankNode)

        rightBankNode = BankNode(side: .right, stuffieCount: stuffieCount)
        rightBankNode.position = CGPoint(
            x: cx + bridgeNode.plankWidth / 2 + gap + BankLayout.width / 2,
            y: cy
        )
        addChild(rightBankNode)
    }

    private func populateLevel() {
        placeStuffies(stateManager.leftBank, on: leftBankNode)
        placeStuffies(stateManager.rightBank, on: rightBankNode)
    }

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
        let isEscort = stuffie.id == stateManager.level.mandatoryEscortId
        let node = StuffieNode(stuffie: stuffie, isEscort: isEscort)
        node.sourceBankNode = bank
        stuffieNodes[stuffie.id] = node
        return node
    }

    // MARK: - Bridge Interaction

    func stuffieDroppedOnBridge(_ node: StuffieNode) {
        stateManager.stuffieMovedToBridge(node.stuffie)
        repositionBridgeStuffies()
        updateGoButtonState()
    }

    func stuffieDroppedOffBridge(_ node: StuffieNode) {
        if stateManager.onBridge.contains(where: { $0.id == node.stuffie.id }) {
            stateManager.stuffieRemovedFromBridge(node.stuffie)
            repositionBridgeStuffies()
        }
        node.snapToRestingPosition()
        updateGoButtonState()
    }

    private func repositionBridgeStuffies() {
        let bridgeStuffies = stateManager.onBridge
        let count = bridgeStuffies.count
        let spacing = min(StuffieSize.width + 8, bridgeNode.plankWidth / CGFloat(max(count, 1)))
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

    // MARK: - Go Button State

    private func updateGoButtonState() {
        let canGo = stateManager.canTapGo(sourceSide: currentBridgeSourceSide())
        overlayDelegate?.gameStateDidChange(canGo: canGo)
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
    }

    func handleRestartTapped() {
        stateManager.restartTapped()
        stateManager.introCompleted()
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
        }
    }

    private func animateConflictReaction() {
        let conflictNodes = stateManager.conflictingIds.compactMap { stuffieNodes[$0] }

        for node in conflictNodes {
            node.wiggle()
            let puff = makeSmokePuff()
            puff.position = CGPoint(x: node.position.x, y: node.position.y + StuffieSize.height / 2 + 24)
            addChild(puff)
            puff.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.15),
                SKAction.wait(forDuration: 0.9),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }

        run(SKAction.wait(forDuration: 1.5)) { [weak self] in
            self?.stateManager.conflictReactionCompleted()
        }
    }

    private func makeSmokePuff() -> SKNode {
        let container = SKNode()

        let circle = SKShapeNode(circleOfRadius: 22)
        circle.fillColor = SKColor(white: 0.95, alpha: 0.92)
        circle.strokeColor = SKColor(white: 0.6, alpha: 0.8)
        circle.lineWidth = 2
        container.addChild(circle)

        let label = SKLabelNode(text: "!")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 26
        label.fontColor = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        container.alpha = 0
        container.zPosition = ZPosition.overlay
        return container
    }

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
        updateGoButtonState()

        switch state {
        case .idle:
            rebuildStuffieNodes()
        case .animating:
            animateCrossing(sourceSide: currentBridgeSourceSide())
        case .conflictReaction:
            animateConflictReaction()
        case .win:
            showWinCelebration()
        default:
            break
        }
    }

    private func showWinCelebration() {
        let currentId = stateManager.level.id
        let nextLevelId = currentId + 1
        let hasNextLevel = Levels.allLevels().contains(where: { $0.id == nextLevelId })

        var actions: [SKAction] = [SKAction.wait(forDuration: 1.0)]

        if hasNextLevel {
            let banner = SKLabelNode(text: "Level \(nextLevelId) Unlocked!")
            banner.fontName = "AvenirNext-Bold"
            banner.fontSize = 42
            banner.fontColor = .systemYellow
            banner.zPosition = ZPosition.overlay
            banner.position = CGPoint(x: size.width / 2, y: size.height / 2)
            banner.alpha = 0
            addChild(banner)

            actions += [
                SKAction.run { banner.run(SKAction.fadeIn(withDuration: 0.4)) },
                SKAction.wait(forDuration: 1.8)
            ]
        }

        actions.append(SKAction.run { [weak self] in
            guard let self, let view = self.view else { return }
            let menu = MenuScene(size: self.size)
            menu.scaleMode = .resizeFill
            view.presentScene(menu, transition: SKTransition.fade(withDuration: 0.8))
            if let vc = view.next as? GameViewController {
                vc.hideGameOverlay()
            }
        })

        run(SKAction.sequence(actions))
    }
}
