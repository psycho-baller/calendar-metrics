import Foundation

enum DraftStatus: String, Codable, Equatable {
    case draft
    case archived
}

struct Draft: Identifiable, Codable, Equatable {
    var id: UUID
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var status: DraftStatus // New property

    init(id: UUID = UUID(), content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), status: DraftStatus = .draft) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.status = status
    }
}
