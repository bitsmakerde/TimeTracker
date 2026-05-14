import Foundation
import Testing

@Suite("View Preview Coverage")
struct ViewPreviewCoverageTests {
    @Test("Every SwiftUI view file includes a preview")
    func everySwiftUIViewFileIncludesPreview() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectories = ["SharedUI", "TimeTracker", "TimeTrackeriOS"]
            .map { repositoryRoot.appending(path: $0) }

        let missingPreviewFiles = sourceDirectories
            .flatMap(swiftFiles(in:))
            .filter(fileDefinesView)
            .filter { fileHasPreview($0) == false }
            .map { $0.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "") }
            .sorted()

        if missingPreviewFiles.isEmpty == false {
            Issue.record(
                """
                Missing previews:
                \(missingPreviewFiles.joined(separator: "\n"))
                """
            )
        }

        #expect(missingPreviewFiles.isEmpty)
    }

    private func swiftFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return enumerator.compactMap { element in
            guard let url = element as? URL,
                  url.pathExtension == "swift" else {
                return nil
            }

            return url
        }
    }

    private func fileDefinesView(_ fileURL: URL) -> Bool {
        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }

        return source.range(
            of: #"(?m)^\s*(private\s+)?(struct|enum|final class)\s+\w+\s*:\s*View\b"#,
            options: .regularExpression
        ) != nil
    }

    private func fileHasPreview(_ fileURL: URL) -> Bool {
        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }

        return source.contains("#Preview") || source.contains("PreviewProvider")
    }
}
