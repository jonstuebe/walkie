import HealthKit
import SwiftData
import Foundation

@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    var isAuthorized = false
    var authorizationError: Error?
    var todaySteps: Int = 0

    private let stepType = HKQuantityType(.stepCount)
    private var observerQuery: HKObserverQuery?

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
        } catch {
            authorizationError = error
        }
    }

    func enableBackgroundDelivery() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        await withCheckedContinuation { continuation in
            store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in
                continuation.resume()
            }
        }
    }

    // Registers a long-lived HKObserverQuery. HealthKit will wake the app
    // in the background whenever new step data is available and call this handler.
    // The completionHandler MUST be called or iOS will throttle future deliveries.
    func startObserving(container: ModelContainer) {
        if let existing = observerQuery { store.stop(existing) }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self, error == nil else { completionHandler(); return }
            Task {
                let steps = await self.stepsToday()
                let updater = BackgroundPetUpdater(modelContainer: container)
                await updater.update(todaySteps: steps, healthKit: self)
                completionHandler()
            }
        }

        store.execute(query)
        observerQuery = query
    }

    func stepsToday() async -> Int {
        let count = await steps(for: Date())
        await MainActor.run { self.todaySteps = count }
        return count
    }

    func steps(for date: Date) async -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return await stepsInRange(from: start, to: end)
    }

    func stepsInRange(from start: Date, to end: Date) async -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count))
            }
            store.execute(query)
        }
    }

    func stepTier(for steps: Int, goal: Int = 10_000) -> StepTier {
        let half = Int(Double(goal) * 0.50)
        let quarter = Int(Double(goal) * 0.25)
        switch steps {
        case goal...: return .thriving
        case half..<goal: return .barelyAlive
        case quarter..<half: return .hungry
        default: return .starving
        }
    }
}

// Bamboo ledger: linear earning at 1 bamboo per 10% of the daily step goal.
// Hitting goal earns enough bamboo (10) to fully restore an empty koala.
// Walking past goal keeps earning at the same rate. No hard cap — feeds gate
// on health < 100%, so excess bamboo simply goes unused for the day.
enum BambooLedger {
    /// Step interval that awards 1 bamboo (== goal / 10).
    static func stepsPerBamboo(goal: Int) -> Int {
        max(1, goal / 10)
    }

    /// Total bamboo earned today for the given step count.
    static func earned(steps: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return steps / stepsPerBamboo(goal: goal)
    }

    /// Steps remaining until the next bamboo unlocks.
    static func stepsToNextBamboo(steps: Int, goal: Int) -> Int {
        let stride = stepsPerBamboo(goal: goal)
        return stride - (steps % stride)
    }
}

enum StepTier {
    case thriving, barelyAlive, hungry, starving

    var title: String {
        switch self {
        case .thriving: return "Thriving"
        case .barelyAlive: return "Barely Alive"
        case .hungry: return "Hungry"
        case .starving: return "Starving"
        }
    }

    var canFeed: Bool { self != .starving }
}
