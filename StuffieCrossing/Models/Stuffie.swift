import Foundation

struct Stuffie: Identifiable {
    let id: String
    let displayName: String
    let spriteName: String
    // Unidirectional — check both directions: a.conflictsWith(b) || b.conflictsWith(a)
    let conflicts: Set<String>

    func conflictsWith(_ other: Stuffie) -> Bool {
        conflicts.contains(other.id) || other.conflicts.contains(id)
    }
}
