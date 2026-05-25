import SpriteKit

class BridgeNode: SKNode {

    let plankWidth: CGFloat
    private let plank: SKShapeNode
    var isHighlighted: Bool = false {
        didSet { plank.strokeColor = isHighlighted ? .systemYellow : .brown }
    }

    init(capacity: Int) {
        plankWidth = CGFloat(capacity) * StuffieSize.width
                   + CGFloat(capacity - 1) * 8  // gap between stuffie slots
                   + 40  // horizontal padding
        let rect = CGRect(
            x: -plankWidth / 2,
            y: -BridgeLayout.height / 2,
            width: plankWidth,
            height: BridgeLayout.height
        )
        plank = SKShapeNode(rect: rect, cornerRadius: 8)
        plank.fillColor = .systemBrown
        plank.strokeColor = .brown
        plank.lineWidth = 3
        plank.physicsBody = nil
        super.init()
        addChild(plank)
        zPosition = ZPosition.bridge
    }

    required init?(coder: NSCoder) { fatalError() }

    func contains(point scenePoint: CGPoint) -> Bool {
        let local = convert(scenePoint, from: parent ?? self)
        return plank.frame.contains(local)
    }
}
