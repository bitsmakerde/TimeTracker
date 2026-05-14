import SwiftData
import SwiftUI

struct ProjectDetailLayoutMetrics {
    static func contentPadding(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    static func sectionPadding(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    static func summaryGridMinimum(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 140 : 180
    }

    static func usesStackedRow(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        if horizontalSizeClass == .compact {
            return true
        }
        return dynamicTypeSize >= .accessibility1
    }

    static func sessionRowSpacing(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        ) ? 10 : 12
    }

    static func sessionRowPadding(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        usesStackedRow(
            dynamicTypeSize: dynamicTypeSize,
            horizontalSizeClass: horizontalSizeClass
        ) ? 12 : 18
    }

    static func sectionCornerRadius(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 22 : 28
    }

    static func headerCornerRadius(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .compact ? 24 : 30
    }

    static func sectionCardGradient(colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.07), Color.black.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(0.98), Color(red: 0.95, green: 0.97, blue: 0.995)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func sectionCardStroke(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    static func sectionCardShadow(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.14) : Color.black.opacity(0.08)
    }
}

struct ProjectExportSelection: Equatable {
    let format: ProjectExportFormat
    let mode: ProjectExportContentMode

    static func current(
        format: ProjectExportFormat,
        selectedMode: ProjectExportContentMode,
        hasHourlyRate: Bool
    ) -> ProjectExportSelection {
        let mode: ProjectExportContentMode = hasHourlyRate ? selectedMode : .hoursOnly
        return ProjectExportSelection(format: format, mode: mode)
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    let project: ClientProject
    let activeSession: WorkSession?
    let onStart: () -> Void
    let onStartTask: (ProjectTask) -> Void
    let onStop: () -> Void
    let onAddManualEntry: () -> Void
    let onEditSession: (WorkSession) -> Void
    let onDeleteSession: (WorkSession) -> Void
    let onArchiveProject: () -> Void
    let onRestoreProject: () -> Void
    let onDeleteProject: () -> Void

    @State private var viewModel: ProjectDetailViewModel

    init(
        project: ClientProject,
        activeSession: WorkSession?,
        onStart: @escaping () -> Void,
        onStartTask: @escaping (ProjectTask) -> Void,
        onStop: @escaping () -> Void,
        onAddManualEntry: @escaping () -> Void,
        onEditSession: @escaping (WorkSession) -> Void,
        onDeleteSession: @escaping (WorkSession) -> Void,
        onArchiveProject: @escaping () -> Void,
        onRestoreProject: @escaping () -> Void,
        onDeleteProject: @escaping () -> Void
    ) {
        self.project = project
        self.activeSession = activeSession
        self.onStart = onStart
        self.onStartTask = onStartTask
        self.onStop = onStop
        self.onAddManualEntry = onAddManualEntry
        self.onEditSession = onEditSession
        self.onDeleteSession = onDeleteSession
        self.onArchiveProject = onArchiveProject
        self.onRestoreProject = onRestoreProject
        self.onDeleteProject = onDeleteProject
        _viewModel = State(initialValue: ProjectDetailViewModel(project: project, activeSession: activeSession))
    }

    var contentPadding: CGFloat {
        ProjectDetailLayoutMetrics.contentPadding(horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            pageBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProjectDetailHeaderCard(
                        viewModel: viewModel,
                        onStart: onStart,
                        onStartTask: onStartTask,
                        onStop: onStop,
                        onAddManualEntry: onAddManualEntry,
                        onArchiveProject: onArchiveProject,
                        onRestoreProject: onRestoreProject,
                        onDeleteProject: onDeleteProject
                    )

                    ProjectDetailSummaryRow(viewModel: viewModel)

                    if viewModel.shouldShowBillingCard {
                        ProjectDetailBillingCard(viewModel: viewModel)
                    }

                    ProjectDetailTasksCard(
                        viewModel: viewModel,
                        onStartTask: onStartTask,
                        onStop: onStop
                    )

                    ProjectDetailSessionsCard(
                        viewModel: viewModel,
                        onAddManualEntry: onAddManualEntry,
                        onEditSession: onEditSession
                    )
                }
                .padding(contentPadding)
            }
        }
        .onAppear {
            viewModel.syncHourlyRateText()
            viewModel.syncBudgetEditor()
            viewModel.syncExportConfiguration()
            viewModel.syncSelectedTaskForStart()
        }
        .onChange(of: project.id) { _, _ in
            viewModel.project = project
            viewModel.activeSession = activeSession
            viewModel.onProjectChanged()
        }
        .onChange(of: activeSession?.id) { _, _ in
            viewModel.activeSession = activeSession
        }
        .onChange(of: viewModel.exportFormat) { _, _ in
            viewModel.invalidatePreparedExport()
        }
        .onChange(of: viewModel.exportContentMode) { _, _ in
            viewModel.invalidatePreparedExport()
        }
        .onChange(of: viewModel.selectedBudgetUnit) { oldUnit, newUnit in
            viewModel.convertBudgetEditorValue(from: oldUnit, to: newUnit)
        }
        .onChange(of: viewModel.isPresentingBudgetSheet) { _, isPresented in
            if !isPresented {
                viewModel.isEditingBudgetInSheet = false
            }
        }
        .alert("Speichern fehlgeschlagen", isPresented: vm.billingAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.billingErrorMessage ?? "")
        }
        .confirmationDialog(
            "Projekt abschliessen?",
            isPresented: $vm.isConfirmingProjectArchive,
            titleVisibility: .visible
        ) {
            Button("Projekt archivieren", role: .destructive, action: onArchiveProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt wird ins Archiv verschoben und nicht mehr bei den aktiven Kundenprojekten angezeigt.")
        }
        .confirmationDialog(
            "Projekt loeschen?",
            isPresented: $vm.isConfirmingProjectDeletion,
            titleVisibility: .visible
        ) {
            Button("Projekt loeschen", role: .destructive, action: onDeleteProject)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt und alle zugehoerigen Zeiteintraege werden dauerhaft geloescht.")
        }
        .confirmationDialog(
            "Zeiteintrag loeschen?",
            isPresented: vm.sessionDeletionIsPresented,
            titleVisibility: .visible
        ) {
            if let sessionPendingDeletion = viewModel.sessionPendingDeletion {
                Button("Zeiteintrag loeschen", role: .destructive) {
                    onDeleteSession(sessionPendingDeletion)
                    viewModel.sessionPendingDeletion = nil
                }
            }

            Button("Abbrechen", role: .cancel) {
                viewModel.sessionPendingDeletion = nil
            }
        } message: {
            if let sessionPendingDeletion = viewModel.sessionPendingDeletion {
                Text("Der Eintrag vom \(TimeFormatting.shortDate(sessionPendingDeletion.startedAt)) wird dauerhaft geloescht.")
            }
        }
        .sheet(item: $vm.sessionPendingTaskCreation) { session in
            NewTaskAssignmentSheet(
                project: viewModel.project,
                session: session
            ) { title in
                viewModel.createTaskAndAssignSession(title: title, to: session, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $vm.isPresentingBudgetSheet) {
            ProjectDetailBudgetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $vm.isPresentingExportSheet) {
            ProjectDetailExportSheet(viewModel: viewModel)
        }
    }

    var pageBackgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    .platformWindowBackground,
                    viewModel.project.projectAccentColor.opacity(0.16),
                    Color.black.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 0.98),
                viewModel.project.projectAccentColor.opacity(0.16),
                Color.white.opacity(0.60),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension Color {
    static var platformWindowBackground: Color {
#if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
#elseif canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
#else
        return .background
#endif
    }
}

#Preview {
    let project = ClientProject(
        clientName: "Acme Corp",
        name: "Website Redesign",
        hourlyRate: 85,
        budgetUnitRaw: ProjectBudgetUnit.hours.rawValue,
        budgetTarget: 20,
        accentRed: 0.0,
        accentGreen: 0.5,
        accentBlue: 1.0
    )
    ProjectDetailView(
        project: project,
        activeSession: nil,
        onStart: {},
        onStartTask: { _ in },
        onStop: {},
        onAddManualEntry: {},
        onEditSession: { _ in },
        onDeleteSession: { _ in },
        onArchiveProject: {},
        onRestoreProject: {},
        onDeleteProject: {}
    )
}
