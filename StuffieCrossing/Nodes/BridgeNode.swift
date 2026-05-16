import SpriteKit

class BridgeNode: SKNode {

    private let plank: SKShapeNode
    var isHighlighted: Bool = false {
        didSet { plank.strokeColor = isHighlighted ? .systemYellow : .brown }
    }

    override init() {
        let rect = CGRect(
            x: -BridgeLayout.width / 2,
            y: -BridgeLayout.height / 2,
            width: BridgeLayout.width,
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
