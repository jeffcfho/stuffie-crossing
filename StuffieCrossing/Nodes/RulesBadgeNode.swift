import SpriteKit

// A slim, always-visible strip of the level's conflict rules, laid out horizontally
// along the top of the scene.
//
// The intro card states the rules once and then disappears; a 3-year-old mid-puzzle
// has no way to re-check them short of hitting Restart. This keeps them on screen
// for the whole level. Same shape language as IntroOverlayNode — deliberately, so
// the strip reads as the card the child already saw, just smaller.
final class RulesBadgeNode: SKNode {

    private enum Layout {
        static let portraitSize: CGFloat = 32
        static let markerFontSize: CGFloat = 18
        static let innerGap: CGFloat = 14      // portrait <-> x marker
        static let pairGap: CGFloat = 28       // between one pair and the next
        static let padding: CGFloat = 16
        static let height: CGFloat = 64
        static let cornerRadius: CGFloat = 14
        static let topMargin: CGFloat = 50     // strip centre, down from the top edge
    }

    // Height is fixed, so callers can reserve space without building the node first.
    static var stripHeight: CGFloat { Layout.height }

    // nil when the level has no conflicts — nothing to show, so don't add the node.
    init?(level: Level) {
        guard !level.conflicts.isEmpty else { return nil }
        super.init()
        zPosition = ZPosition.rulesBadge
        buildLayout(level: level)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    // Scene-space position for a given scene size: centred horizontally, pinned near
    // the top. The banks are centred vertically, so this clears them.
    static func position(in sceneSize: CGSize) -> CGPoint {
        CGPoint(x: sceneSize.width / 2, y: sceneSize.height - Layout.topMargin)
    }

    private func buildLayout(level: Level) {
        // Same ordering as the intro card: sort on both ids, since several pairs
        // share their first id (bunny-lion, bunny-duck).
        let pairs = level.conflicts.sorted { ($0.a, $0.b) < ($1.a, $1.b) }

        let pairWidth = Layout.portraitSize * 2
                      + Layout.innerGap * 2
                      + Layout.markerFontSize
        let totalWidth = CGFloat(pairs.count) * pairWidth
                       + CGFloat(max(pairs.count - 1, 0)) * Layout.pairGap
                       + Layout.padding * 2

        let backing = SKShapeNode(
            rectOf: CGSize(width: totalWidth, height: Layout.height),
            cornerRadius: Layout.cornerRadius
        )
        backing.fillColor = SKColor(white: 1.0, alpha: 0.82)
        backing.strokeColor = SKColor(white: 1.0, alpha: 0.95)
        backing.lineWidth = 2
        addChild(backing)

        // Walk left to right from the inner edge of the padding.
        var x = -totalWidth / 2 + Layout.padding + Layout.portraitSize / 2
        for pair in pairs {
            addPair(pair, level: level, centredOnFirstPortraitX: x)
            x += pairWidth + Layout.pairGap
        }
    }

    private func addPair(_ pair: ConflictPair, level: Level, centredOnFirstPortraitX x: CGFloat) {
        let step = Layout.portraitSize / 2 + Layout.innerGap + Layout.markerFontSize / 2

        if let a = level.stuffies.first(where: { $0.id == pair.a }) {
            let node = StuffieNode.portrait(for: a,
                                            isEscort: a.id == level.mandatoryEscortId,
                                            size: Layout.portraitSize)
            node.position = CGPoint(x: x, y: 0)
            addChild(node)
        }

        let marker = SKLabelNode(text: "✕")
        marker.fontName = "AvenirNext-Bold"
        marker.fontSize = Layout.markerFontSize
        marker.fontColor = .red
        marker.verticalAlignmentMode = .center
        marker.horizontalAlignmentMode = .center
        marker.position = CGPoint(x: x + step, y: 0)
        addChild(marker)

        if let b = level.stuffies.first(where: { $0.id == pair.b }) {
            let node = StuffieNode.portrait(for: b,
                                            isEscort: b.id == level.mandatoryEscortId,
                                            size: Layout.portraitSize)
            node.position = CGPoint(x: x + step * 2, y: 0)
            addChild(node)
        }
    }
}
