import Foundation

struct SessionEditor: Identifiable {
    let project: ClientProject
    let session: WorkSession

    var id: UUID {
        session.id
    }
}
