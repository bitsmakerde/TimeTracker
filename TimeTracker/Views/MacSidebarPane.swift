import SwiftUI

struct MacSidebarPane: View {
    let projects: [ClientProject]
    let activeProjectId: UUID?
    @Binding var search: String
    @Binding var selectedId: UUID?
    let onAddProject: () -> Void

    @State private var collapsedClients: Set<String> = []

    private var grouped: [(client: String, items: [ClientProject])] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = query.isEmpty ? projects : projects.filter { project in
            project.displayName.localizedStandardContains(query)
                || project.displayClientName.localizedStandardContains(query)
        }

        return Dictionary(grouping: matched, by: \.displayClientName)
            .map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            ScrollView {
                VStack(alignment: .leading, spacing: TTSpacing.sm) {
                    ForEach(grouped, id: \.client) { group in
                        clientGroup(name: group.client, items: group.items)
                    }
                    Button(action: onAddProject) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 11))
                            Text("Neuer Kunde").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(TTColors.text2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, TTSpacing.sm)
                .padding(.bottom, TTSpacing.md)
            }
        }
        .background(.regularMaterial)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TTColors.text3)
                .font(.system(size: 11))
            TextField("Suchen", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, TTSpacing.sm)
        .frame(height: 28)
        .background(TTColors.fill3, in: .rect(cornerRadius: 7, style: .continuous))
        .padding(.horizontal, TTSpacing.sm)
        .padding(.top, TTSpacing.sm)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func clientGroup(name: String, items: [ClientProject]) -> some View {
        let isOpen = !collapsedClients.contains(name)
        VStack(alignment: .leading, spacing: 1) {
            Button {
                if isOpen { collapsedClients.insert(name) } else { collapsedClients.remove(name) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                    Spacer()
                }
                .foregroundStyle(TTColors.text2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                ForEach(items, id: \.id) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func projectRow(_ project: ClientProject) -> some View {
        let selected = selectedId == project.id
        let totalMinutes = Int(project.sessionList.reduce(0.0) { $0 + $1.recordedDuration } / 60)

        return Button {
            selectedId = project.id
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(project.projectAccentColor)
                    .frame(width: 3, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.displayName)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(TTColors.text)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(project.displayClientName.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(TTColors.text3)
                        Circle().fill(TTColors.text3).frame(width: 2, height: 2)
                        Text(totalMinutes > 0 ? "\(totalMinutes / 60)h \(totalMinutes % 60)m" : "0m")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(TTColors.text3)
                    }
                }
                Spacer(minLength: 0)
                if activeProjectId == project.id {
                    PulseDot(color: TTColors.live, size: 6)
                }
            }
            .padding(.horizontal, TTSpacing.sm)
            .padding(.vertical, 5)
            .background(selected ? TTColors.fill3 : .clear, in: .rect(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Mac sidebar pane") {
    MacSidebarPanePreviewHost()
}

@MainActor
private struct MacSidebarPanePreviewHost: View {
    private let preview = PreviewWorkspaceSnapshot()
    @State private var search = ""
    @State private var selectedProjectID: UUID?

    var body: some View {
        MacSidebarPane(
            projects: preview.projects.filter { !$0.isArchived },
            activeProjectId: preview.activeSessions.first?.project?.id,
            search: $search,
            selectedId: $selectedProjectID,
            onAddProject: {}
        )
        .frame(width: 280, height: 700)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = preview.projects.first?.id
            }
        }
    }
}
