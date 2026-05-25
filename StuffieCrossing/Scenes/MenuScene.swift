import SpriteKit

class MenuScene: SKScene {

    private let levels = Levels.allLevels()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1)

        let title = SKLabelNode(text: "Stuffie Crossing")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 52
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        addChild(title)

        // Center the level list in the space between the title and the bottom margin.
        let bottomMargin: CGFloat = 80
        let topOfList = size.height * 0.68
        let buttonSpacing: CGFloat = 76
        let listHeight = buttonSpacing * CGFloat(levels.count - 1)
        let startY = (topOfList + bottomMargin) / 2 + listHeight / 2

        for (i, level) in levels.enumerated() {
            let label = SKLabelNode(text: "Level \(level.id)")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 38
            label.fontColor = level.isUnlocked ? .systemYellow : .gray
            label.name = level.isUnlocked ? "level_\(level.id)" : nil
            label.position = CGPoint(x: size.width / 2, y: startY - CGFloat(i) * buttonSpacing)
            addChild(label)

            if !level.isUnlocked {
                let lock = SKLabelNode(text: "🔒")
                lock.fontSize = 28
                lock.position = CGPoint(x: label.position.x + 110, y: label.position.y - 4)
                addChild(lock)
            }
        }

        #if DEBUG
        // Debug controls pinned to bottom-left so they never overlap level labels.
        let reset = SKLabelNode(text: "Reset Progress")
        reset.fontName = "AvenirNext-Regular"
        reset.fontSize = 16
        reset.fontColor = .lightGray
        reset.horizontalAlignmentMode = .left
        reset.name = "resetProgress"
        reset.position = CGPoint(x: 24, y: 24)
        addChild(reset)

        let devUnlock = SKLabelNode(text: GameStateManager.isDevModeEnabled() ? "Dev Mode ON" : "Unlock All (Dev)")
        devUnlock.fontName = "AvenirNext-Regular"
        devUnlock.fontSize = 16
        devUnlock.fontColor = GameStateManager.isDevModeEnabled() ? .cyan : .systemTeal
        devUnlock.horizontalAlignmentMode = .left
        devUnlock.name = "devUnlock"
        devUnlock.position = CGPoint(x: 24, y: 48)
        addChild(devUnlock)
        #endif
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, view != nil else { return }
        let location = touch.location(in: self)
        let tapped = self.nodes(at: location).compactMap(\.name)
        for name in tapped {
            if name.hasPrefix("level_"), let id = Int(name.dropFirst(6)),
               let level = levels.first(where: { $0.id == id }) {
                transitionToGame(level: level)
                return
            }
            #if DEBUG
            if name == "resetProgress" {
                GameStateManager.resetProgress()
                let fresh = MenuScene(size: size)
                fresh.scaleMode = .resizeFill
                view?.presentScene(fresh)
                return
            }
            if name == "devUnlock" {
                if GameStateManager.isDevModeEnabled() {
                    GameStateManager.disableDevMode()
                } else {
                    GameStateManager.enableDevMode()
                }
                let fresh = MenuScene(size: size)
                fresh.scaleMode = .resizeFill
                view?.presentScene(fresh)
                return
            }
            #endif
        }
    }

    private func transitionToGame(level: Level) {
        guard let view = view else { return }
        let scene = GameScene(level: level, size: size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
        if let vc = view.next as? GameViewController {
            vc.showGameOverlay(gameScene: scene)
        }
    }
}
