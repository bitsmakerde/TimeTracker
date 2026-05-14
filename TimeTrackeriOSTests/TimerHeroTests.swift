import SwiftUI
import Testing
@testable import TimeTrackeriOS

@Suite("Timer Hero")
@MainActor
struct TimerHeroTests {
    @Test("Timer hero can be constructed for running and idle projects")
    func timerHeroSupportsRunningState() {
        let runningHero = TimerHero(
            clientName: "Acme",
            projectName: "Website",
            taskName: "Design",
            projectColor: .blue,
            elapsed: 3_600,
            hourlyRate: 85,
            billed: 85,
            budgetProgress: 0.5,
            runningSinceLabel: "09:00",
            compact: true,
            isThisRunning: true,
            onStart: nil,
            onPause: {},
            onStop: {}
        )
        let idleHero = TimerHero(
            clientName: "Acme",
            projectName: "Website",
            taskName: nil,
            projectColor: .blue,
            elapsed: 0,
            hourlyRate: 85,
            billed: nil,
            budgetProgress: nil,
            runningSinceLabel: nil,
            compact: true,
            isThisRunning: false,
            onStart: {},
            onPause: nil,
            onStop: nil
        )

        _ = runningHero
        _ = idleHero
    }
}
