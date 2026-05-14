import SwiftUI

struct ProjectsDrawer: View {
    let projects: [ClientProject]
    let activeProjectId: UUID?
    let onSelect: (UUID) -> Void
    let onAddProject: (String) -> Void

    @State private var search = ""

    private var filtered: [(client: String, items: [ClientProject])] {
        let active = projects.filter { !$0.isArchived }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = q.isEmpty ? active : active.filter { p in
            p.displayName.localizedStandardContains(q)
                || p.displayClientName.localizedStandardContains(q)
        }
        let grouped = Dictionary(grouping: matched, by: \.displayClientName)
        return grouped
            .map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                searchBar
                newClientButton
                SectionCard("Alle Kunden") {
                    VStack(spacing: 12) {
                        ForEach(filtered, id: \.client) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                clientHeader(for: group.client)
                                ForEach(group.items, id: \.id) { project in
                                    projectRow(project)
                                }
                            }
                        }
                        if filtered.isEmpty {
                            Text("Keine Treffer")
                                .font(.system(size: 13))
                                .foregroundStyle(TTColors.text2)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(TTColors.bg.ignoresSafeArea())
        .navigationTitle("Projekte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Projekt", systemImage: "plus") {
                    onAddProject("")
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(TTColors.text2)
            TextField("Suchen", text: $search).textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Capsule().fill(TTColors.fill3))
    }

    private var newClientButton: some View {
        PillButton("Neuer Kunde", systemImage: "plus", variant: .primary, tint: ClientProject.primaryActionColor) {
            onAddProject("")
        }
    }

    private func clientHeader(for clientName: String) -> some View {
        HStack(spacing: 8) {
            Text(clientName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TTColors.text2)
            Spacer()
            Button {
                onAddProject(clientName)
            } label: {
                Label("Projekt", systemImage: "plus")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .frame(height: 28)
            }
            .buttonStyle(PillButtonStyle(variant: .tinted, tint: ClientProject.primaryActionColor))
        }
        .padding(.top, 4)
    }

    private func projectRow(_ project: ClientProject) -> some View {
        Button {
            onSelect(project.id)
        } label: {
            HStack(spacing: 10) {
                if activeProjectId == project.id {
                    PulseDot(color: project.projectAccentColor, size: 8)
                } else {
                    Circle().fill(project.projectAccentColor).frame(width: 8, height: 8)
                }
                Text(project.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TTColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TTColors.text3)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: TTRadius.md, style: .continuous)
                    .fill(TTColors.fill4)
            )
        }
        .buttonStyle(.plain)
    }
}
