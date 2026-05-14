import SwiftData
import SwiftUI

struct ContentView: View {
    let trackingStatus: TrackingStatusStore
    let dependencies: AppDependencies

    @AppStorage("tt.projectColorVariant") private var variantRaw: String = ProjectColorVariant.chromed.rawValue

    private var variant: ProjectColorVariant {
        ProjectColorVariant(rawValue: variantRaw) ?? .chromed
    }

    var body: some View {
        TabView {
            Tab("Aufnehmen", systemImage: "record.circle") {
                NavigationStack {
                    TrackingScreen(
                        trackingStatus: trackingStatus,
                        dependencies: dependencies
                    )
                }
            }

            Tab("Auswertung", systemImage: "chart.bar.xaxis") {
                NavigationStack {
                    AnalyticsScreen()
                }
            }
        }
        .tint(TTColors.accent)
        .environment(\.projectColorVariant, variant)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.regularMaterial, for: .tabBar)
    }
}

#Preview {
    let previewContainer: ModelContainer = {
        do {
            return try TimeTrackerSchema.makeModelContainer(
                isStoredInMemoryOnly: true
            )
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()

    return ContentView(
        trackingStatus: TrackingStatusStore(modelContainer: previewContainer),
        dependencies: AppDependencies.live(
            configuration: TimeTrackerTargetConfiguration.iOS
        )
    )
    .modelContainer(previewContainer)
}
