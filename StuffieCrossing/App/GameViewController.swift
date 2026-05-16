import UIKit
import SpriteKit
import AVFoundation

// Transparent overlay that only intercepts touches landing on a subview (i.e. a button).
// Everything else falls through to the SKView beneath it.
private class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit == self ? nil : hit
    }
}

class GameViewController: UIViewController {

    private var overlayView: UIView!
    private var goButton: UIButton!
    private var hintButton: UIButton!
    private var undoButton: UIButton!
    private var restartButton: UIButton!
    private var initialScenePresented = false

    override func loadView() {
        view = SKView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureAudioSession()
        configureSKView()
        configureOverlay()
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureSKView() {
        guard let skView = view as? SKView else { return }
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.ignoresSiblingOrder = true
    }

    private func presentMenuScene() {
        guard let skView = view as? SKView else { return }
        let scene = MenuScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    private func configureOverlay() {
        overlayView = PassthroughView(frame: view.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.isUserInteractionEnabled = true
        overlayView.backgroundColor = .clear
        overlayView.isHidden = true
        view.addSubview(overlayView)

        goButton = makeButton(title: "Go!", action: #selector(didTapGo))
        hintButton = makeButton(title: "Hint", action: #selector(didTapHint))
        undoButton = makeButton(title: "Undo", action: #selector(didTapUndo))
        restartButton = makeButton(title: "Restart", action: #selector(didTapRestart))

        [goButton, hintButton, undoButton, restartButton].forEach {
            overlayView.addSubview($0!)
        }
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 22)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !initialScenePresented {
            initialScenePresented = true
            presentMenuScene()
        }

        let safe = view.safeAreaInsets
        let bw: CGFloat = 110
        let bh: CGFloat = 50
        let bottom = view.bounds.height - safe.bottom - 20
        let spacing: CGFloat = 16
        let totalW = bw * 4 + spacing * 3
        var x = (view.bounds.width - totalW) / 2

        for btn in [goButton, undoButton, hintButton, restartButton] {
            btn?.frame = CGRect(x: x, y: bottom - bh, width: bw, height: bh)
            x += bw + spacing
        }
    }

    func showGameOverlay(gameScene: GameScene) {
        overlayView.isHidden = false
        gameScene.overlayDelegate = self
        updateGoButton(enabled: false)
    }

    func hideGameOverlay() {
        overlayView.isHidden = true
    }

    func updateGoButton(enabled: Bool) {
        goButton.isEnabled = enabled
        goButton.alpha = enabled ? 1.0 : 0.4
    }

    @objc private func didTapGo() {
        currentGameScene?.handleGoTapped()
    }

    @objc private func didTapHint() {
        currentGameScene?.handleHintTapped()
    }

    @objc private func didTapUndo() {
        currentGameScene?.handleUndoTapped()
    }

    @objc private func didTapRestart() {
        currentGameScene?.handleRestartTapped()
    }

    private var currentGameScene: GameScene? {
        (view as? SKView)?.scene as? GameScene
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}

extension GameViewController: GameOverlayDelegate {
    func gameStateDidChange(canGo: Bool) {
        updateGoButton(enabled: canGo)
    }
}
