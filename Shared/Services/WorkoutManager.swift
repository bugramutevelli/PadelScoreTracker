#if os(watchOS)
import Foundation
import HealthKit
import Combine

final class WorkoutManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var metrics = WorkoutMetrics()
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var startDate: Date?
    private var hasFinishedCollection = false

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            await setError("Apple Sağlık bu cihazda kullanılamıyor.")
            return false
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate)
        ]
        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            await MainActor.run { self.isAuthorized = true }
            return true
        } catch {
            await setError(error.localizedDescription)
            return false
        }
    }

    func startWorkout() {
        guard !isRunning else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            self.startDate = Date()
            self.metrics = WorkoutMetrics()
            self.hasFinishedCollection = false
            self.isRunning = true

            let start = startDate!
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] success, error in
                if !success, let error { self?.publishError(error) }
            }
            startTimer()
        } catch {
            publishError(error)
        }
    }

    func endWorkout() {
        session?.end()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.startDate else { return }
            self.metrics.duration = Date().timeIntervalSince(startDate)
            self.refreshSteps()
        }
    }

    private func refreshSteps() {
        guard let startDate, let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let value = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            DispatchQueue.main.async { self?.metrics.steps = value }
        }
        healthStore.execute(query)
    }

    private func updateStatistics(for type: HKQuantityType) {
        guard let statistics = builder?.statistics(for: type) else { return }
        switch type.identifier {
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            metrics.activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? metrics.activeCalories
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            metrics.distanceMeters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? metrics.distanceMeters
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            metrics.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? metrics.heartRate
        default:
            break
        }
    }

    private func finishCollection(at date: Date) {
        guard !hasFinishedCollection, let builder else { return }
        hasFinishedCollection = true
        timer?.invalidate()
        timer = nil
        metrics.duration = date.timeIntervalSince(startDate ?? date)
        refreshSteps()
        builder.endCollection(withEnd: date) { [weak self] _, error in
            if let error { self?.publishError(error) }
            builder.finishWorkout { _, error in
                if let error { self?.publishError(error) }
                DispatchQueue.main.async { self?.isRunning = false }
            }
        }
    }

    private func publishError(_ error: Error) {
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }

    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended {
            DispatchQueue.main.async { self.finishCollection(at: date) }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        publishError(error)
        DispatchQueue.main.async { self.isRunning = false }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        DispatchQueue.main.async {
            for case let quantityType as HKQuantityType in collectedTypes {
                self.updateStatistics(for: quantityType)
            }
        }
    }
}

#if DEBUG
extension WorkoutManager {
    static func preview(running: Bool = true) -> WorkoutManager {
        let manager = WorkoutManager()
        manager.isAuthorized = true
        manager.isRunning = running
        manager.metrics = WorkoutMetrics(
            duration: 3258,
            activeCalories: 286,
            steps: 4218,
            distanceMeters: 3140,
            heartRate: 142
        )
        return manager
    }
}
#endif
#endif
