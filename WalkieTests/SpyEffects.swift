import Foundation
@testable import Walkie

/// Records lifecycle fan-out so tests can assert "died once", "one snapshot", etc.
/// All calls arrive serially from the single PetLifecycle actor; the lock guards
/// against the test thread reading mid-flight.
final class SpyEffects: LifecycleEffects, @unchecked Sendable {
    private let lock = NSLock()

    private var _hatched = 0
    private var _died = 0
    private var _snapshotUpdates = 0
    private var _snapshotClears = 0
    private var _lastHealthState: Pet.HealthState?

    var hatched: Int { lock.withLock { _hatched } }
    var died: Int { lock.withLock { _died } }
    var snapshotUpdates: Int { lock.withLock { _snapshotUpdates } }
    var snapshotClears: Int { lock.withLock { _snapshotClears } }
    var lastHealthState: Pet.HealthState? { lock.withLock { _lastHealthState } }

    func petHatched(name: String, colorHex: String) { lock.withLock { _hatched += 1 } }
    func snapshotUpdated(_ snapshot: PetSnapshot) { lock.withLock { _snapshotUpdates += 1 } }
    func snapshotCleared() { lock.withLock { _snapshotClears += 1 } }
    func petDied(name: String) { lock.withLock { _died += 1 } }
    func healthChanged(to state: Pet.HealthState, name: String) { lock.withLock { _lastHealthState = state } }
}
