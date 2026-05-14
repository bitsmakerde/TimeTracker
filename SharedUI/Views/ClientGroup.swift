import Foundation

struct ClientGroup {
    let displayName: String
    let rawClientName: String
    let projects: [ClientProject]

    var client: String {
        displayName
    }
}
