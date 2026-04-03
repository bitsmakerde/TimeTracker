import Foundation
import SwiftData

@MainActor
final class TrackingStatusStore: ObservableObject {
    struct ActiveSessionSnapshot: Equatable {
        let projectName: String
        let clientName: String
        let startedAt: Date
    }

    @Published private(set) var activeSession: ActiveSessionSnapshot?
    @Published private(set) var referenceDate: Date = .now

    private let modelContainer: ModelContainer
    private var timer: Timer?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        refresh()
        startTimer()
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

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
}
