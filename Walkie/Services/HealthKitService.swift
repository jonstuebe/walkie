import HealthKit
import SwiftData
import Foundation

@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    var isAuthorized = false
    var authorizationError: Error?

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
        await steps(for: Date())
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
        let happy = Int(Double(goal) * 0.75)
        let surviving = Int(Double(goal) * 0.30)
        switch steps {
        case goal...: return .thriving
        case happy..<goal: return .happy
        case surviving..<happy: return .surviving
        default: return .starving
        }
    }
}

enum StepTier {
    case thriving, happy, surviving, starving

    var title: String {
        switch self {
        case .thriving: return "Thriving"
        case .happy: return "Happy"
        case .surviving: return "Surviving"
        case .starving: return "Starving"
        }
    }

    var healthDelta: Double {
        switch self {
        case .thriving: return 0.2
        case .happy: return 0.1
        case .surviving: return 0.05
        case .starving: return -0.15
        }
    }

    var canFeed: Bool { self != .starving }
}
