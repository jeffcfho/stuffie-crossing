import SpriteKit

class StuffieNode: SKNode {

    let stuffie: Stuffie
    weak var sourceBankNode: BankNode?
    var restingPosition: CGPoint = .zero

    private let body: SKShapeNode
    private var activeTouch: UITouch?

    init(stuffie: Stuffie, isEscort: Bool = false) {
        self.stuffie = stuffie
        if isEscort {
            body = SKShapeNode(circleOfRadius: min(StuffieSize.width, StuffieSize.height) / 2)
        } else {
            let rect = CGRect(
                x: -StuffieSize.width / 2,
                y: -StuffieSize.height / 2,
                width: StuffieSize.width,
                height: StuffieSize.height
            )
            body = SKShapeNode(rect: rect, cornerRadius: 12)
        }
        body.fillColor = StuffieNode.placeholderColor(for: stuffie.id)
        body.strokeColor = body.fillColor.withAlphaComponent(0.6)
        body.lineWidth = 2
        body.physicsBody = nil
        super.init()
        addChild(body)
        isUserInteractionEnabled = true
        zPosition = ZPosition.stuffieResting
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Drag
    // StuffieNodes are always direct children of GameScene, so touch coordinates
    // are in scene space and position updates need no conversion.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        guard let scene = scene, let manager = (scene as? GameScene)?.stateManager else { return }
        guard manager.state == .idle || manager.state == .selecting else {
            wiggle()
            return
        }
        activeTouch = touch
        zPosition = ZPosition.stuffieDragging
        removeAllActions()
        run(SKAction.scale(to: StuffieSize.liftScale, duration: 0.08))
        (scene as? GameScene)?.bridgeNode.isHighlighted = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let scene = scene else { return }
        position = touch.location(in: scene)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let scene = scene else { return }
        activeTouch = nil
        run(SKAction.scale(to: StuffieSize.bridgeSnapScale, duration: 0.08))
        (scene as? GameScene)?.bridgeNode.isHighlighted = false

        let location = touch.location(in: scene)
        guard let gameScene = scene as? GameScene else { return }

        if gameScene.bridgeNode.contains(point: location) {
            gameScene.stuffieDroppedOnBridge(self)
        } else {
            gameScene.stuffieDroppedOffBridge(self)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let scene = scene as? GameScene else { return }
        activeTouch = nil
        run(SKAction.scale(to: StuffieSize.bridgeSnapScale, duration: 0.08))
        scene.stuffieDroppedOffBridge(self)
    }

    func snapToRestingPosition(animated: Bool = true) {
        zPosition = ZPosition.stuffieResting
        if animated {
            run(SKAction.move(to: restingPosition, duration: 0.2))
        } else {
            position = restingPosition
        }
    }

    func wiggle() {
        removeAction(forKey: "wiggle")
        let wiggle = SKAction.sequence([
            SKAction.rotate(byAngle: 0.08, duration: 0.05),
            SKAction.rotate(byAngle: -0.16, duration: 0.1),
            SKAction.rotate(byAngle: 0.08, duration: 0.05),
        ])
        run(SKAction.repeat(wiggle, count: 2), withKey: "wiggle")
    }

    // MARK: - Helpers

    private static func placeholderColor(for id: String) -> SKColor {
        switch id {
        case "bear":  return SKColor(red: 0.6,  green: 0.4,  blue: 0.2,  alpha: 1)
        case "bunny": return SKColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        case "lion":  return SKColor(red: 0.95, green: 0.75, blue: 0.1,  alpha: 1)  // golden amber
        case "ellie": return SKColor(red: 0.7,  green: 0.7,  blue: 0.75, alpha: 1)
        case "duck":  return SKColor(red: 1.0,  green: 0.45, blue: 0.0,  alpha: 1)  // orange
        default:      return .gray
        }
    }
}
