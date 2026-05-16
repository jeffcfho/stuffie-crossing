import SpriteKit

class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1)

        let title = SKLabelNode(text: "Stuffie Crossing")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 52
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        addChild(title)

        let playButton = SKLabelNode(text: "Play")
        playButton.fontName = "AvenirNext-Bold"
        playButton.fontSize = 38
        playButton.fontColor = .systemYellow
        playButton.name = "playButton"
        playButton.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        addChild(playButton)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, view != nil else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        if nodes.contains(where: { $0.name == "playButton" }) {
            transitionToGame()
        }
    }

    private func transitionToGame() {
        guard let view = view else { return }
        let level = Levels.allLevels().first!
        let scene = GameScene(level: level, size: size)
        scene.scaleMode = .resizeFill
        let transition = SKTransition.fade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)

        if let vc = view.next as? GameViewController {
            vc.showGameOverlay(gameScene: scene)
        }
    }
}
