import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TrackingStatusStore {
    struct ActiveSessionSnapshot: Equatable {
        let projectName: String
        let clientName: String
        let startedAt: Date
    }

    private(set) var activeSession: ActiveSessionSnapshot?
    private(set) var referenceDate: Date = .now

    @ObservationIgnored
    private let modelContainer: ModelContainer
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        refresh()
        startRefreshTask()
    }

    deinit {
        refreshTask?.cancel()
    }

    var isTracking: Bool {
        activeSession != nil
    }

    var menuBarDurationText: String {
        guard let activeSession else {
            return "0:00"
        }

        return TimeFormatting.menuBarDuration(
            referenceDate.timeIntervalSince(activeSession.startedAt)
        )
    }

    func refresh() {
        referenceDate = .now

        let descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate<WorkSession> { session in
                session.endedAt == nil
            },
            sortBy: [SortDescriptor(\WorkSession.startedAt, order: .reverse)]
        )

        do {
            let session = try modelContainer.mainContext.fetch(descriptor).first

            guard let session, let project = session.project else {
                activeSession = nil
                return
            }

            activeSession = ActiveSessionSnapshot(
                projectName: project.displayName,
                clientName: project.displayClientName,
                startedAt: session.startedAt
            )
        } catch {
            activeSession = nil
        }
    }

    private func startRefreshTask() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                guard let self else {
                    return
                }

                self.refresh()
            }
        }
    }
}
