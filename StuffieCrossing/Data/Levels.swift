import Foundation

enum Levels {

    static let ellie = Stuffie(id: "ellie", displayName: "Ellie", spriteName: "stuffie_ellie")
    static let lion  = Stuffie(id: "lion",  displayName: "Lion",  spriteName: "stuffie_lion")
    static let bunny = Stuffie(id: "bunny", displayName: "Bunny", spriteName: "stuffie_bunny")
    static let duck  = Stuffie(id: "duck",  displayName: "Duck",  spriteName: "stuffie_duck")
    static let bear  = Stuffie(id: "bear",  displayName: "Bear",  spriteName: "stuffie_bear")

    // Level 1 — Tutorial (3 stuffies, capacity 2)
    // Ellie must be on every crossing. Two valid first moves: E+Lion or E+Bunny.
    // Optimal: 3 moves. Teaches the escort mechanic.
    static let level1 = Level(
        id: 1,
        environment: .water,
        bridgeCapacity: 2,
        stuffies: [ellie, lion, bunny],
        conflicts: [ConflictPair("bunny", "lion")],
        mandatoryEscortId: "ellie",
        hintSequence: [
            ["ellie", "lion"],
            ["ellie"],
            ["ellie", "bunny"],
        ],
        isUnlocked: true
    )

    // Level 2 — Classic Puzzle (4 stuffies, capacity 2)
    // Wolf-goat-cabbage: only E+Bunny valid first move. Escort-back forced mid-puzzle.
    // Optimal: 7 moves.
    static let level2 = Level(
        id: 2,
        environment: .water,
        bridgeCapacity: 2,
        stuffies: [ellie, lion, bunny, duck],
        conflicts: [
            ConflictPair("bunny", "lion"),
            ConflictPair("bunny", "duck"),
        ],
        mandatoryEscortId: "ellie",
        hintSequence: [
            ["ellie", "bunny"],
            ["ellie"],
            ["ellie", "lion"],
            ["ellie", "bunny"],
            ["ellie", "duck"],
            ["ellie"],
            ["ellie", "bunny"],
        ],
        isUnlocked: false
    )

    // Level 3 — Four Passengers (5 stuffies, capacity 2)
    // Bear introduced. All first moves valid (5 stuffies → 3 left, no 2-alone check).
    // Optimal: 7 moves. Wrong orderings trigger escort-back (9 moves).
    static let level3 = Level(
        id: 3,
        environment: .water,
        bridgeCapacity: 2,
        stuffies: [ellie, lion, bunny, duck, bear],
        conflicts: [
            ConflictPair("bunny", "lion"),
            ConflictPair("bunny", "duck"),
            ConflictPair("lion",  "bear"),
        ],
        mandatoryEscortId: "ellie",
        hintSequence: [
            ["ellie", "duck"],
            ["ellie"],
            ["ellie", "lion"],
            ["ellie"],
            ["ellie", "bunny"],
            ["ellie"],
            ["ellie", "bear"],
        ],
        isUnlocked: false
    )

    // Level 4 — Tighter Constraints (5 stuffies, capacity 2)
    // Add Bear+Duck conflict. Mid-puzzle: after E+Lion first and E back,
    // only E+Duck is valid (E+Bunny leaves Duck+Bear; E+Bear leaves Bunny+Duck).
    // Optimal: 7 moves.
    static let level4 = Level(
        id: 4,
        environment: .lava,
        bridgeCapacity: 2,
        stuffies: [ellie, lion, bunny, duck, bear],
        conflicts: [
            ConflictPair("bunny", "lion"),
            ConflictPair("bunny", "duck"),
            ConflictPair("lion",  "bear"),
            ConflictPair("bear",  "duck"),
        ],
        mandatoryEscortId: "ellie",
        hintSequence: [
            ["ellie", "lion"],
            ["ellie"],
            ["ellie", "duck"],
            ["ellie"],
            ["ellie", "bunny"],
            ["ellie"],
            ["ellie", "bear"],
        ],
        isUnlocked: false
    )

    // Level 5 — Bigger Boat (5 stuffies, capacity 3)
    // Add Lion+Duck conflict. Bridge now fits Ellie + 2 passengers.
    // Only valid first grouping: E+Lion+Duck (Ellie masks the conflict on bridge).
    // Ellie alone back is forced (leaves Lion+Duck = conflict). Optimal: 5 moves.
    static let level5 = Level(
        id: 5,
        environment: .lava,
        bridgeCapacity: 3,
        stuffies: [ellie, lion, bunny, duck, bear],
        conflicts: [
            ConflictPair("bunny", "lion"),
            ConflictPair("bunny", "duck"),
            ConflictPair("lion",  "bear"),
            ConflictPair("bear",  "duck"),
            ConflictPair("lion",  "duck"),
        ],
        mandatoryEscortId: "ellie",
        hintSequence: [
            ["ellie", "lion", "duck"],
            ["ellie", "duck"],
            ["ellie", "bunny", "bear"],
            ["ellie"],
            ["ellie", "duck"],
        ],
        isUnlocked: false
    )

    static func allLevels() -> [Level] {
        if GameStateManager.isDevModeEnabled() {
            return [level1, level2, level3, level4, level5].map { var l = $0; l.isUnlocked = true; return l }
        }
        let completed = GameStateManager.completedLevelIds()
        var l2 = level2; l2.isUnlocked = completed.contains(1)
        var l3 = level3; l3.isUnlocked = completed.contains(2)
        var l4 = level4; l4.isUnlocked = completed.contains(3)
        var l5 = level5; l5.isUnlocked = completed.contains(4)
        return [level1, l2, l3, l4, l5]
    }
}
