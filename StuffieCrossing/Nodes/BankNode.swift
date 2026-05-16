import SpriteKit

class BankNode: SKNode {

    let side: BankSide
    private let background: SKShapeNode

    init(side: BankSide) {
        self.side = side
        let rect = CGRect(
            x: -BankLayout.width / 2,
            y: -BankLayout.height / 2,
            width: BankLayout.width,
            height: BankLayout.height
        )
        background = SKShapeNode(rect: rect, cornerRadius: 10)
        background.fillColor = SKColor(red: 0.35, green: 0.72, blue: 0.3, alpha: 1)
        background.strokeColor = SKColor(red: 0.25, green: 0.55, blue: 0.2, alpha: 1)
        background.lineWidth = 2
        background.physicsBody = nil
        super.init()
        addChild(background)
        zPosition = ZPosition.bank
    }

    required init?(coder: NSCoder) { fatalError() }

    // Returns stuffie slot positions in this node's LOCAL coordinate space.
    // Add to self.position to get scene-space positions.
    func slotPositions(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let totalH = CGFloat(count) * StuffieSize.height
            + CGFloat(count - 1) * BankLayout.stuffieSpacing
        var y = totalH / 2 - StuffieSize.height / 2
        return (0..<count).map { _ in
            let p = CGPoint(x: 0, y: y)
            y -= StuffieSize.height + BankLayout.stuffieSpacing
            return p
        }
    }

    func contains(scenePoint: CGPoint) -> Bool {
        guard let parent = parent else { return false }
        let local = convert(scenePoint, from: parent)
        return background.frame.contains(local)
    }
}
