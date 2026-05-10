import CoreData
import Foundation
import Observation
import SwiftData

enum CrossDeviceTrackingLifecycle: String, Codable, Equatable, Sendable {
    case started
    case stopped
}

struct CrossDeviceTrackingSnapshot: Codable, Equatable, Sendable {
    let sourceDeviceID: String
    let projectName: String
    let clientName: String
    let taskTitle: String
    let startedAt: Date
    let lifecycle: CrossDeviceTrackingLifecycle
    let updatedAt: Date
}

@MainActor
protocol CrossDeviceTrackingChannelProtocol: AnyObject {
    func start(onChange: @escaping (CrossDeviceTrackingSnapshot?) -> Void)
    func publish(_ snapshot: CrossDeviceTrackingSnapshot)
    func refresh()
}

@MainActor
final class NoopCrossDeviceTrackingChannel: CrossDeviceTrackingChannelProtocol {
    func start(onChange: @escaping (CrossDeviceTrackingSnapshot?) -> Void) {
        onChange(nil)
    }

    func publish(_ snapshot: CrossDeviceTrackingSnapshot) {}

    func refresh() {}
}

@MainActor
final class ICloudKeyValueCrossDeviceTrackingChannel: CrossDeviceTrackingChannelProtocol {
    private static let storageKey = "timeTracker.crossDeviceTrackingSnapshot"

    private let keyValueStore: NSUbiquitousKeyValueStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var notificationTask: Task<Void, Never>?
    private var onChange: ((CrossDeviceTrackingSnapshot?) -> Void)?

    init(
        keyValueStore: NSUbiquitousKeyValueStore = .default
    ) {
        self.keyValueStore = keyValueStore
    }

    deinit {
        notificationTask?.cancel()
    }

    func start(onChange: @escaping (CrossDeviceTrackingSnapshot?) -> Void) {
        self.onChange = onChange
        refresh()
        startListeningForExternalChanges()
    }

    func publish(_ snapshot: CrossDeviceTrackingSnapshot) {
        guard let encodedSnapshot = try? encoder.encode(snapshot) else {
            return
        }

        keyValueStore.set(encodedSnapshot, forKey: Self.storageKey)
        keyValueStore.synchronize()
    }

    func refresh() {
        keyValueStore.synchronize()
        onChange?(currentSnapshot())
    }

    private func currentSnapshot() -> CrossDeviceTrackingSnapshot? {
        guard let encodedSnapshot = keyValueStore.data(forKey: Self.storageKey) else {
            return nil
        }

        return try? decoder.decode(CrossDeviceTrackingSnapshot.self, from: encodedSnapshot)
    }

    private func startListeningForExternalChanges() {
        guard notificationTask == nil else {
            return
        }

        notificationTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            ) {
                guard Task.isCancelled == false else {
                    return
                }

                self?.handleExternalChange(notification)
            }
        }
    }

    private func handleExternalChange(_ notification: Notification) {
        guard let changedStore = notification.object as? NSUbiquitousKeyValueStore,
              changedStore === keyValueStore else {
            return
        }

        refresh()
    }
}

enum CloudKitSyncOperation: Equatable, Sendable {
    case setup
    case importData
    case export
}

enum CloudSyncStatus: Equatable, Sendable {
    case localOnly
    case waitingForCloud
    case syncing(operation: CloudKitSyncOperation, startedAt: Date)
    case upToDate(lastSyncAt: Date?)
    case failed(message: String, at: Date)
}

struct CloudKitSyncEventSnapshot: Equatable, Sendable {
    let eventType: CloudKitSyncOperation
    let startDate: Date
    let endDate: Date?
    let succeeded: Bool
    let errorDescription: String?

    var completedAt: Date {
        endDate ?? startDate
    }
}

@MainActor
@Observable
final class TrackingStatusStore {
    struct ActiveSessionSnapshot: Equatable {
        let projectName: String
        let clientName: String
        let taskTitle: String
        let startedAt: Date
    }

    private(set) var activeSession: ActiveSessionSnapshot?
    private(set) var referenceDate: Date = .now
    private(set) var syncStatus: CloudSyncStatus
    private(set) var lastSuccessfulImportAt: Date?
    private(set) var lastSuccessfulExportAt: Date?
    private(set) var lastSyncErrorMessage: String?
    private(set) var crossDeviceTrackingSnapshot: CrossDeviceTrackingSnapshot?

    @ObservationIgnored
    private let modelContainer: ModelContainer
    @ObservationIgnored
    private let syncMode: TimeTrackerSyncMode
    @ObservationIgnored
    private let crossDeviceChannel: any CrossDeviceTrackingChannelProtocol
    @ObservationIgnored
    private let deviceID: String
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var cloudKitEventTask: Task<Void, Never>?
    @ObservationIgnored
    private var lastPublishedBroadcastSignature: CrossDeviceTrackingBroadcastSignature?
    @ObservationIgnored
    private var lastRunningSessionForBroadcast: ActiveSessionSnapshot?
    @ObservationIgnored
    private var remotelyStoppedSessionStartedAt: Date?

    init(
        modelContainer: ModelContainer,
        syncMode: TimeTrackerSyncMode = .localOnly,
        crossDeviceChannel: (any CrossDeviceTrackingChannelProtocol)? = nil,
        deviceID: String? = nil
    ) {
        self.modelContainer = modelContainer
        self.syncMode = syncMode
        self.syncStatus = syncMode == .localOnly ? .localOnly : .waitingForCloud
        self.crossDeviceChannel = crossDeviceChannel
            ?? Self.defaultCrossDeviceChannel(syncMode: syncMode)
        self.deviceID = deviceID ?? Self.defaultDeviceIdentifier()
        startCrossDeviceChannel()
        refresh()
        startRefreshTask()
        startCloudKitObserverIfNeeded()
    }

    deinit {
        refreshTask?.cancel()
        cloudKitEventTask?.cancel()
    }

    var isTracking: Bool {
        activeSession != nil
    }

    var isTrackingOnAnotherDevice: Bool {
        crossDeviceTrackingSnapshot?.lifecycle == .started
    }

    var menuBarDurationText: String {
        guard let activeSession else {
            return "0:00"
        }

        return TimeFormatting.menuBarDuration(
            referenceDate.timeIntervalSince(activeSession.startedAt)
        )
    }

    var menuBarCrossDeviceDurationText: String? {
        guard let crossDeviceTrackingSnapshot,
              crossDeviceTrackingSnapshot.lifecycle == .started else {
            return nil
        }

        return TimeFormatting.menuBarDuration(
            referenceDate.timeIntervalSince(crossDeviceTrackingSnapshot.startedAt)
        )
    }

    func refresh() {
        referenceDate = .now
        crossDeviceChannel.refresh()

        let descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate<WorkSession> { session in
                session.endedAt == nil
            },
            sortBy: [SortDescriptor(\WorkSession.startedAt, order: .forward)]
        )

        do {
            let context = modelContainer.mainContext
            let activeSessions = try context.fetch(descriptor)
            let winningSession = activeSessions.first { session in
                session.project != nil
            }

            var didResolveConflict = false

            if activeSessions.count > 1 {
                for session in activeSessions {
                    guard session.id != winningSession?.id else {
                        continue
                    }

                    session.endedAt = session.startedAt
                    didResolveConflict = true
                }
            }

            if didResolveConflict {
                try context.save()
            }

            guard let winningSession,
                  let project = winningSession.project else {
                remotelyStoppedSessionStartedAt = nil
                activeSession = nil
                publishCrossDeviceTrackingUpdate(localSession: nil)
                return
            }

            if let remotelyStoppedSessionStartedAt,
               winningSession.startedAt == remotelyStoppedSessionStartedAt {
                activeSession = nil
                return
            }

            remotelyStoppedSessionStartedAt = nil

            activeSession = ActiveSessionSnapshot(
                projectName: project.displayName,
                clientName: project.displayClientName,
                taskTitle: winningSession.displayTaskTitle,
                startedAt: winningSession.startedAt
            )
            publishCrossDeviceTrackingUpdate(localSession: activeSession)
        } catch {
            activeSession = nil
        }
    }

    func handleCloudKitEvent(_ event: CloudKitSyncEventSnapshot) {
        guard syncMode != .localOnly else {
            return
        }

        if event.endDate == nil {
            syncStatus = .syncing(
                operation: event.eventType,
                startedAt: event.startDate
            )
            return
        }

        if event.succeeded {
            switch event.eventType {
            case .setup:
                break
            case .importData:
                lastSuccessfulImportAt = event.completedAt
            case .export:
                lastSuccessfulExportAt = event.completedAt
            }

            let latestSyncAt = [
                lastSuccessfulImportAt,
                lastSuccessfulExportAt,
                event.completedAt,
            ]
                .compactMap(\.self)
                .max()
            syncStatus = .upToDate(lastSyncAt: latestSyncAt)
            lastSyncErrorMessage = nil
        } else {
            let fallbackMessage = "CloudKit-Synchronisierung fehlgeschlagen."
            let normalizedMessage = event.errorDescription?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = if let normalizedMessage,
                             normalizedMessage.isEmpty == false {
                normalizedMessage
            } else {
                fallbackMessage
            }

            syncStatus = .failed(
                message: message,
                at: event.completedAt
            )
            lastSyncErrorMessage = message
        }
    }

    private func startRefreshTask() {
        refreshTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))

                guard let self else {
                    return
                }

                self.refresh()
            }
        }
    }

    private func startCloudKitObserverIfNeeded() {
        guard syncMode != .localOnly else {
            return
        }

        cloudKitEventTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification
            ) {
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                    continue
                }

                let snapshot = CloudKitSyncEventSnapshot(
                    eventType: Self.syncOperation(from: event.type),
                    startDate: event.startDate,
                    endDate: event.endDate,
                    succeeded: event.succeeded,
                    errorDescription: event.error?.localizedDescription
                )

                self?.handleCloudKitEvent(snapshot)
            }
        }
    }

    private static func syncOperation(
        from eventType: NSPersistentCloudKitContainer.EventType
    ) -> CloudKitSyncOperation {
        switch eventType {
        case .setup:
            return .setup
        case .import:
            return .importData
        case .export:
            return .export
        @unknown default:
            return .export
        }
    }

    private func startCrossDeviceChannel() {
        crossDeviceChannel.start { [weak self] snapshot in
            self?.handleCrossDeviceTrackingSnapshot(snapshot)
        }
    }

    private func handleCrossDeviceTrackingSnapshot(
        _ snapshot: CrossDeviceTrackingSnapshot?
    ) {
        guard let snapshot else {
            if crossDeviceTrackingSnapshot != nil {
                crossDeviceTrackingSnapshot = nil
            }
            return
        }

        guard snapshot.sourceDeviceID != deviceID else {
            return
        }

        if snapshot.lifecycle == .stopped {
            remotelyStoppedSessionStartedAt = snapshot.startedAt

            if activeSession?.startedAt == snapshot.startedAt {
                activeSession = nil
            }
        } else {
            remotelyStoppedSessionStartedAt = nil
        }

        guard crossDeviceTrackingSnapshot != snapshot else {
            return
        }

        crossDeviceTrackingSnapshot = snapshot
    }

    private func publishCrossDeviceTrackingUpdate(localSession: ActiveSessionSnapshot?) {
        guard syncMode != .localOnly else {
            return
        }

        let snapshotToPublish: CrossDeviceTrackingSnapshot?
        if let localSession {
            lastRunningSessionForBroadcast = localSession
            snapshotToPublish = CrossDeviceTrackingSnapshot(
                sourceDeviceID: deviceID,
                projectName: localSession.projectName,
                clientName: localSession.clientName,
                taskTitle: localSession.taskTitle,
                startedAt: localSession.startedAt,
                lifecycle: .started,
                updatedAt: .now
            )
        } else if let lastRunningSessionForBroadcast {
            snapshotToPublish = CrossDeviceTrackingSnapshot(
                sourceDeviceID: deviceID,
                projectName: lastRunningSessionForBroadcast.projectName,
                clientName: lastRunningSessionForBroadcast.clientName,
                taskTitle: lastRunningSessionForBroadcast.taskTitle,
                startedAt: lastRunningSessionForBroadcast.startedAt,
                lifecycle: .stopped,
                updatedAt: .now
            )
        } else {
            snapshotToPublish = nil
        }

        guard let snapshotToPublish else {
            return
        }

        let signature = CrossDeviceTrackingBroadcastSignature(snapshot: snapshotToPublish)
        guard signature != lastPublishedBroadcastSignature else {
            return
        }

        lastPublishedBroadcastSignature = signature
        crossDeviceChannel.publish(snapshotToPublish)
    }

    private static func defaultCrossDeviceChannel(
        syncMode: TimeTrackerSyncMode
    ) -> any CrossDeviceTrackingChannelProtocol {
        guard syncMode != .localOnly else {
            return NoopCrossDeviceTrackingChannel()
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return NoopCrossDeviceTrackingChannel()
        }

        return ICloudKeyValueCrossDeviceTrackingChannel()
    }

    private static func defaultDeviceIdentifier() -> String {
        let defaults = UserDefaults.standard
        let defaultsKey = "timeTracker.crossDeviceDeviceIdentifier"

        if let existingIdentifier = defaults.string(forKey: defaultsKey),
           existingIdentifier.isEmpty == false {
            return existingIdentifier
        }

        let newIdentifier = UUID().uuidString
        defaults.set(newIdentifier, forKey: defaultsKey)
        return newIdentifier
    }
}

private struct CrossDeviceTrackingBroadcastSignature: Equatable {
    let sourceDeviceID: String
    let projectName: String
    let clientName: String
    let taskTitle: String
    let startedAt: Date
    let lifecycle: CrossDeviceTrackingLifecycle

    init(snapshot: CrossDeviceTrackingSnapshot) {
        sourceDeviceID = snapshot.sourceDeviceID
        projectName = snapshot.projectName
        clientName = snapshot.clientName
        taskTitle = snapshot.taskTitle
        startedAt = snapshot.startedAt
        lifecycle = snapshot.lifecycle
    }
}
