import SpriteKit

// Full-screen "meet the stuffies" card shown when a level loads (INTRO state).
// Purely visual — one row per conflicting pair, no text. Tap anywhere to dismiss.
//
// Subclasses SKSpriteNode rather than SKNode so the node has a real size to
// hit-test against; the dimming is a separate child so parent alpha stays 1.0
// (SpriteKit multiplies child alpha by parent alpha).
final class IntroOverlayNode: SKSpriteNode {

    static let nodeName = "introOverlay"

    var onDismiss: (() -> Void)?

    private enum Layout {
        static let backdropAlpha: CGFloat = 0.72
        static let cardWidth: CGFloat = 480
        static let cardCornerRadius: CGFloat = 24
        static let rowHeight: CGFloat = 80
        static let cardPadding: CGFloat = 100
        static let portraitSize: CGFloat = 48
        static let pairGap: CGFloat = 72
    }

    init(level: Level, sceneSize: CGSize) {
        super.init(texture: nil, color: .clear, size: sceneSize)
        name = IntroOverlayNode.nodeName
        isUserInteractionEnabled = true
        zPosition = ZPosition.overlay
        buildLayout(level: level, sceneSize: sceneSize)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func buildLayout(level: Level, sceneSize: CGSize) {
        let backdrop = SKSpriteNode(color: .black, size: sceneSize)
        backdrop.alpha = Layout.backdropAlpha
        backdrop.position = .zero
        addChild(backdrop)

        // Sort on both ids — several pairs share the same `a` (bunny-lion, bunny-duck).
        let pairs = level.conflicts.sorted { ($0.a, $0.b) < ($1.a, $1.b) }
        let cardHeight = CGFloat(pairs.count) * Layout.rowHeight + Layout.cardPadding
        let cardSize = CGSize(width: Layout.cardWidth, height: cardHeight)

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: Layout.cardCornerRadius)
        card.fillColor = .white
        card.strokeColor = .clear
        card.position = .zero
        addChild(card)

        let totalHeight = CGFloat(max(pairs.count - 1, 0)) * Layout.rowHeight
        for (i, pair) in pairs.enumerated() {
            let y = totalHeight / 2 - CGFloat(i) * Layout.rowHeight + 24
            addConflictRow(pair: pair, level: level, y: y)
        }

        let tapLabel = SKLabelNode(text: "▶  tap to play")
        tapLabel.fontName = "AvenirNext-Medium"
        tapLabel.fontSize = 18
        tapLabel.fontColor = SKColor(white: 0.45, alpha: 1)
        tapLabel.verticalAlignmentMode = .center
        tapLabel.position = CGPoint(x: 0, y: -(cardHeight / 2) + 36)
        addChild(tapLabel)

        tapLabel.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])))
    }

    private func addConflictRow(pair: ConflictPair, level: Level, y: CGFloat) {
        if let a = level.stuffies.first(where: { $0.id == pair.a }) {
            let node = StuffieNode.portrait(for: a, isEscort: a.id == level.mandatoryEscortId, size: Layout.portraitSize)
            node.position = CGPoint(x: -Layout.pairGap, y: y)
            addChild(node)
        }

        let marker = SKLabelNode(text: "✕")
        marker.fontName = "AvenirNext-Bold"
        marker.fontSize = 32
        marker.fontColor = .red
        marker.verticalAlignmentMode = .center
        marker.position = CGPoint(x: 0, y: y)
        addChild(marker)

        if let b = level.stuffies.first(where: { $0.id == pair.b }) {
            let node = StuffieNode.portrait(for: b, isEscort: b.id == level.mandatoryEscortId, size: Layout.portraitSize)
            node.position = CGPoint(x: Layout.pairGap, y: y)
            addChild(node)
        }
    }

    // MARK: - Dismiss

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dismiss()
    }

    func dismiss() {
        guard isUserInteractionEnabled else { return }
        isUserInteractionEnabled = false
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.run { [weak self] in self?.onDismiss?() },
            SKAction.removeFromParent()
        ]))
    }
}
