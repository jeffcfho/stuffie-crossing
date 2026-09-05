import CoreGraphics

enum StuffieSize {
    static let width: CGFloat = 80
    static let height: CGFloat = 80
    static let anchorX: CGFloat = 0.5
    static let anchorY: CGFloat = 0.5
    static let liftScale: CGFloat = 1.2
    static let bridgeSnapScale: CGFloat = 1.0
}

enum BridgeLayout {
    static let width: CGFloat = 200
    static let height: CGFloat = 60
    static let yPosition: CGFloat = 0   // center of scene
}

enum BankLayout {
    static let width: CGFloat = 200
    static let height: CGFloat = 340
    static let stuffieSpacing: CGFloat = 20
}

enum ZPosition {
    static let bank: CGFloat = 0
    static let bridge: CGFloat = 1
    static let stuffieResting: CGFloat = 2
    static let stuffieDragging: CGFloat = 10
    static let overlay: CGFloat = 100
}

// Filenames in StuffieCrossing/Sounds/. See POLISH.md for the CC0 candidate links.
enum Sounds {
    static let crossing = "crossing.mp3"
    static let plop     = "plop.mp3"
    static let snapback = "snapback.mp3"
    static let win      = "win.mp3"
}
