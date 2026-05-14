import Testing
@testable import TimeTracker

@Suite("Project Detail Preview")
@MainActor
struct ProjectDetailViewPreviewTests {
    @Test("Preview view can be constructed from sample data")
    func previewViewCanBeConstructed() {
        let preview = ProjectDetailPreviewFactory.makeView()

        _ = preview
    }
}
