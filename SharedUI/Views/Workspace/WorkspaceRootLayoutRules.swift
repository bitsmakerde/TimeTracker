import SwiftUI

struct WorkspaceRootLayoutRules {
    static func usesTabRoot(
        horizontalSizeClass: UserInterfaceSizeClass?,
        forcedWorkspaceSection: WorkspaceSection?,
        prefersNativeTabBar: Bool
    ) -> Bool {
        prefersNativeTabBar && horizontalSizeClass == .compact && forcedWorkspaceSection == nil
    }
}
