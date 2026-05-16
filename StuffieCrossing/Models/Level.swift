import Foundation

enum BridgeEnvironment {
    case water, lava, rope, steel
}

struct Level {
    let id: Int
    let environment: BridgeEnvironment
    let bridgeCapacity: Int
    let stuffies: [Stuffie]
    // Each entry is the set of stuffie IDs to send on that move
    let hintSequence: [[String]]
    var isUnlocked: Bool
}
