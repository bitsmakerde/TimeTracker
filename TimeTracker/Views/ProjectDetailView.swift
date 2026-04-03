import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let project: ClientProject
    let activeSession: WorkSession?
    let onStart: () -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onEditSession: (WorkSession) -> Void
    let onDeleteSession: (WorkSession) -> Void
    let onArchiveProject: () -> Void
    let onRestoreProject: () -> Void
    let onDeleteProject: () -> Void

    @State private var hourlyRateText = ""
    @State private var isEditingHourlyRate = false
    @State private var billingErrorMessage: String?
    @State private var isConfirmingProjectArchive = false
    @State private var isConfirmingProjectDeletion = false
    @State private var sessionPendingDeletion: WorkSession?

    private var isActiveProject: Bool {
        activeSession?.project?.id == project.id
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.teal.opacity(0.08),
                    Color.orange.opacity(0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard

                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        summaryRow(referenceDate: timeline.date)
                    }

                    if shouldShowBillingCard {
                        billingCard
                    }

                    sessionsCard
                }
                .padding(28)
            }
        }
        .onAppear(perform: syncHourlyRateText)
        .onChange(of: project.id) { _, _ in
            syncHourlyRateText()
            isEditingHourlyRate = false
        }
        .alert("Speichern fehlgeschlagen", isPresented: billingAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(billingErrorMessage ?? "")
        }
        .confirmationDialog(
            "Projekt abschliessen?",
            isPresented: $isConfirmingProjectArchive,
            titleVisibility: .visible
        ) {
            Button("Projekt archivieren", role: .destructive, action: onArchiveProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt wird ins Archiv verschoben und nicht mehr bei den aktiven Kundenprojekten angezeigt.")
        }
        .confirmationDialog(
            "Projekt loeschen?",
            isPresented: $isConfirmingProjectDeletion,
            titleVisibility: .visible
        ) {
            Button("Projekt loeschen", role: .destructive, action: onDeleteProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt und alle zugehoerigen Zeiteintraege werden dauerhaft geloescht.")
        }
        .confirmationDialog(
            "Zeiteintrag loeschen?",
            isPresented: sessionDeletionIsPresented,
            titleVisibility: .visible
        ) {
            if let sessionPendingDeletion {
                Button("Zeiteintrag loeschen", role: .destructive) {
                    onDeleteSession(sessionPendingDeletion)
                    self.sessionPendingDeletion = nil
                }
            }

            Button("Abbrechen", role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            if let sessionPendingDeletion {
                Text("Der Eintrag vom \(TimeFormatting.shortDate(sessionPendingDeletion.startedAt)) wird dauerhaft geloescht.")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(project.displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text(project.displayClientName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    if !project.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(project.notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    actionButton
                    if !project.isArchived {
                        manualEntryButton
                    }
                    projectActionsButton

                    if !project.isArchived,
                       let activeSession,
                       let activeProject = activeSession.project,
                       activeProject.id != project.id {
                        Text("Beim Start wird \(activeProject.displayName) automatisch gestoppt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 260, alignment: .trailing)
                    }
                }
            }

            if let archivedAt = project.archivedAt {
                archiveStatusBadge(archivedAt: archivedAt)
            }

            if isActiveProject, let activeSession {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(.teal)

                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text("Laeuft seit \(TimeFormatting.shortTime(activeSession.startedAt)) - \(TimeFormatting.digitalDuration(activeSession.duration(referenceDate: timeline.date)))")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.55))
                )
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.92), Color.teal.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 12)
    }

    private var actionButton: some View {
        Button(action: {
            if project.isArchived {
                onRestoreProject()
            } else if isActiveProject {
                onStop()
            } else {
                onStart()
            }
        }) {
            Label(
                actionButtonTitle,
                systemImage: actionButtonSystemImage
            )
            .frame(minWidth: 220)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(actionButtonTint)
    }

    private var projectActionsButton: some View {
        Menu {
            if project.isArchived {
                Button(action: onRestoreProject) {
                    Label("Projekt reaktivieren", systemImage: "arrow.uturn.backward.circle")
                }
            } else {
                Button {
                    isConfirmingProjectArchive = true
                } label: {
                    Label("Projekt abschliessen", systemImage: "archivebox.fill")
                }
            }

            Divider()

            Button(role: .destructive) {
                isConfirmingProjectDeletion = true
            } label: {
                Label("Projekt loeschen", systemImage: "trash")
            }
        } label: {
            Label("Projekt", systemImage: "ellipsis.circle")
                .frame(minWidth: 220)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.large)
    }

    private func archiveStatusBadge(archivedAt: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.secondary)

            Text("Archiviert am \(TimeFormatting.shortDate(archivedAt))")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.55))
        )
    }

    private var billingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(project.hasHourlyRate ? "Stundensatz bearbeiten" : "Stundensatz hinterlegen")
                    .font(.title2.weight(.semibold))

                Spacer()

                if project.hasHourlyRate {
                    Button("Schliessen") {
                        isEditingHourlyRate = false
                        syncHourlyRateText()
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stundensatz")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("z. B. 95,00", text: $hourlyRateText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)

                        Text("EUR pro Stunde")
                            .foregroundStyle(.secondary)
                    }

                    Text(hourlyRateHint)
                        .font(.caption)
                        .foregroundStyle(hasInvalidHourlyRate ? .red : .secondary)
                }

                Button("Stundensatz speichern", action: saveHourlyRate)
                    .buttonStyle(.borderedProminent)
                    .disabled(hasInvalidHourlyRate)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Aktueller Satz")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(hourlyRateSummary)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background.opacity(0.94))
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)
        )
    }

    private var manualEntryButton: some View {
        Button(action: onAddManualEntry) {
            Label("Eintrag nachtragen", systemImage: "calendar.badge.plus")
                .frame(minWidth: 220)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private func summaryRow(referenceDate: Date) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 180), spacing: 18),
            ],
            spacing: 18
        ) {
            SummaryCard(
                title: "Gesamtzeit",
                value: TimeFormatting.compactDuration(totalDuration(referenceDate: referenceDate)),
                subtitle: "\(project.sessions.count) Sitzungen"
            )

            SummaryCard(
                title: "Gesamtwert",
                value: totalValueText(referenceDate: referenceDate),
                subtitle: project.hasHourlyRate ? "Aus Zeit und Stundensatz" : "Stundensatz fehlt"
            )

            SummaryCard(
                title: "Heute",
                value: TimeFormatting.compactDuration(todayDuration(referenceDate: referenceDate)),
                subtitle: "Seit 00:00 Uhr"
            )

            SummaryCard(
                title: "Stundensatz",
                value: hourlyRateSummary,
                subtitle: project.hasHourlyRate ? "Pro Stunde" : "Noch nicht hinterlegt",
                accessorySystemImage: "gearshape.fill",
                accessoryAction: toggleHourlyRateEditing
            )
        }
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Letzte Eintraege")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(action: onAddManualEntry) {
                    Label("Nachtragen", systemImage: "plus.circle")
                }

                Text("\(project.sessions.count) gesamt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if project.sortedSessions.isEmpty {
                Text("Noch keine Zeit erfasst. Starte oben den ersten Timer fuer dieses Projekt.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 18)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(project.sortedSessions) { session in
                        SessionRow(
                            session: session,
                            hourlyRate: project.hourlyRate,
                            onEdit: session.isActive ? nil : {
                                onEditSession(session)
                            },
                            onDelete: session.isActive ? nil : {
                                sessionPendingDeletion = session
                            }
                        )
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background.opacity(0.94))
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)
        )
    }

    private func totalDuration(referenceDate: Date) -> TimeInterval {
        project.sessions.reduce(into: 0) { partialResult, session in
            partialResult += session.duration(referenceDate: referenceDate)
        }
    }

    private func todayDuration(referenceDate: Date) -> TimeInterval {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? referenceDate

        return project.sessions.reduce(into: 0) { partialResult, session in
            let sessionEnd = session.endedAt ?? referenceDate
            let overlapStart = max(session.startedAt, dayStart)
            let overlapEnd = min(sessionEnd, nextDayStart)

            guard overlapEnd > overlapStart else {
                return
            }

            partialResult += overlapEnd.timeIntervalSince(overlapStart)
        }
    }

    private var actionButtonTitle: String {
        if project.isArchived {
            return "Projekt reaktivieren"
        }

        return isActiveProject ? "Zeiterfassung stoppen" : "Zeiterfassung starten"
    }

    private var actionButtonSystemImage: String {
        if project.isArchived {
            return "arrow.uturn.backward.circle.fill"
        }

        return isActiveProject ? "stop.fill" : "play.fill"
    }

    private var actionButtonTint: Color {
        if project.isArchived {
            return .blue
        }

        return isActiveProject ? .orange : .teal
    }

    private var parsedHourlyRate: Double? {
        TimeFormatting.parseDecimalInput(hourlyRateText)
    }

    private var hasInvalidHourlyRate: Bool {
        let trimmed = hourlyRateText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return false
        }

        guard let parsedHourlyRate else {
            return true
        }

        return parsedHourlyRate < 0
    }

    private var hourlyRateHint: String {
        if hasInvalidHourlyRate {
            return "Bitte gib einen gueltigen nicht-negativen Betrag ein."
        }

        return "Leer lassen, wenn das Projekt noch keinen Stundensatz hat."
    }

    private var hourlyRateSummary: String {
        guard project.hasHourlyRate else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(project.effectiveHourlyRate)
    }

    private var shouldShowBillingCard: Bool {
        !project.hasHourlyRate || isEditingHourlyRate
    }

    private var billingAlertIsPresented: Binding<Bool> {
        Binding(
            get: { billingErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    billingErrorMessage = nil
                }
            }
        )
    }

    private var sessionDeletionIsPresented: Binding<Bool> {
        Binding(
            get: { sessionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    sessionPendingDeletion = nil
                }
            }
        )
    }

    private func totalValueText(referenceDate: Date) -> String {
        guard let billedAmount = project.billedAmount(for: totalDuration(referenceDate: referenceDate)) else {
            return "Offen"
        }

        return TimeFormatting.euroAmount(billedAmount)
    }

    private func syncHourlyRateText() {
        hourlyRateText = TimeFormatting.decimalInput(project.hourlyRate)
    }

    private func toggleHourlyRateEditing() {
        if project.hasHourlyRate {
            isEditingHourlyRate.toggle()
        } else {
            isEditingHourlyRate = true
        }

        syncHourlyRateText()
    }

    private func saveHourlyRate() {
        guard !hasInvalidHourlyRate else {
            billingErrorMessage = "Der Stundensatz ist ungueltig."
            return
        }

        let previousHourlyRate = project.hourlyRate
        project.hourlyRate = parsedHourlyRate

        do {
            try modelContext.save()
            syncHourlyRateText()
            isEditingHourlyRate = false
        } catch {
            project.hourlyRate = previousHourlyRate
            billingErrorMessage = "Der Stundensatz konnte nicht gespeichert werden."
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    var accessorySystemImage: String? = nil
    var accessoryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let accessoryAction {
                    Button(action: accessoryAction) {
                        Image(systemName: accessorySystemImage ?? "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background.opacity(0.92))
                .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 6)
        )
    }
}

private struct SessionRow: View {
    let session: WorkSession
    let hourlyRate: Double?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(TimeFormatting.shortDate(session.startedAt))
                    .font(.headline)

                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge

            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button(action: onEdit) {
                            Label("Bearbeiten", systemImage: "square.and.pencil")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Loeschen", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            VStack(alignment: .trailing, spacing: 6) {
                SessionDurationText(session: session)

                billedAmountView
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var timeRangeText: String {
        if let endedAt = session.endedAt {
            return "\(TimeFormatting.shortTime(session.startedAt)) - \(TimeFormatting.shortTime(endedAt))"
        }

        return "Seit \(TimeFormatting.shortTime(session.startedAt))"
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(session.isActive ? "Aktiv" : "Beendet")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(session.isActive ? Color.teal.opacity(0.16) : Color.gray.opacity(0.16))
            )
            .foregroundStyle(session.isActive ? .teal : .secondary)
    }

    @ViewBuilder
    private var billedAmountView: some View {
        if let hourlyRate {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    amountLabel(
                        amount: max(session.duration(referenceDate: timeline.date) / 3600, 0) * max(hourlyRate, 0)
                    )
                }
            } else {
                amountLabel(
                    amount: max(session.recordedDuration / 3600, 0) * max(hourlyRate, 0)
                )
            }
        }
    }

    private func amountLabel(amount: Double) -> some View {
        Text(TimeFormatting.euroAmount(amount))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

private struct SessionDurationText: View {
    let session: WorkSession

    var body: some View {
        Group {
            if session.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    durationLabel(interval: session.duration(referenceDate: timeline.date))
                }
            } else {
                durationLabel(interval: session.recordedDuration)
            }
        }
    }

    private func durationLabel(interval: TimeInterval) -> some View {
        Text(TimeFormatting.digitalDuration(interval))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }
}
