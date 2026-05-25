import Foundation

enum BridgeEnvironment {
    case water, lava, rope, steel
}

struct ConflictPair: Hashable {
    let a: String  // canonical: a < b lexicographically
    let b: String
    init(_ x: String, _ y: String) { a = min(x, y); b = max(x, y) }
    func involves(_ id: String) -> Bool { a == id || b == id }
}

struct Level {
    let id: Int
    let environment: BridgeEnvironment
    let bridgeCapacity: Int
    let stuffies: [Stuffie]
    let conflicts: Set<ConflictPair>
    let mandatoryEscortId: String?
    let hintSequence: [[String]]
    var isUnlocked: Bool
}
