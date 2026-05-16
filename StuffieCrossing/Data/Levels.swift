import Foundation

enum Levels {

    static let bear = Stuffie(
        id: "bear",
        displayName: "Bear",
        spriteName: "stuffie_bear",
        conflicts: []
    )

    static let bunny = Stuffie(
        id: "bunny",
        displayName: "Bunny",
        spriteName: "stuffie_bunny",
        conflicts: []
    )

    static let lion = Stuffie(
        id: "lion",
        displayName: "Lion",
        spriteName: "stuffie_lion",
        conflicts: ["bunny"]   // Lion scares Bunny
    )

    // Level 1: 3 stuffies, 1 conflict, bridge capacity 2
    // Valid solution: send Bear+Bunny, Bear comes back, send Bear+Lion (or other valid paths)
    static let level1 = Level(
        id: 1,
        environment: .water,
        bridgeCapacity: 2,
        stuffies: [bear, bunny, lion],
        hintSequence: [
            ["bear", "bunny"],  // move 1: send Bear and Bunny right
            ["bear"],           // move 2: send Bear back left
            ["bear", "lion"],   // move 3: send Bear and Lion right
        ],
        isUnlocked: true
    )

    // Level 2: 3 stuffies, 2 conflict pairs, bridge capacity 2
    // Adds: Bear scared of Lion too — forces the escort-back insight
    static let level2Bear = Stuffie(
        id: "bear",
        displayName: "Bear",
        spriteName: "stuffie_bear",
        conflicts: ["lion"]    // Bear is also scared of Lion in level 2
    )

    // Level 2 solution: send Bear+Bunny right (Lion alone left = safe),
    // then send Lion right. Lion can never be left alone with Bear or Bunny.
    static let level2 = Level(
        id: 2,
        environment: .water,
        bridgeCapacity: 2,
        stuffies: [level2Bear, bunny, lion],
        hintSequence: [
            ["bear", "bunny"],  // move 1: Bear and Bunny cross right; Lion alone on left
            ["lion"],           // move 2: Lion crosses right; win
        ],
        isUnlocked: false
    )

    static func allLevels() -> [Level] {
        let completed = GameStateManager.completedLevelIds()
        var l2 = level2
        l2.isUnlocked = completed.contains(1)
        return [level1, l2]
    }
}
