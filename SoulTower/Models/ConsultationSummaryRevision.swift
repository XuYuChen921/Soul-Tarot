import Foundation
import SwiftData

@Model
final class ConsultationSummaryRevision {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var clientID: UUID
    var version: Int
    var content: String
    var aiModelName: String
    var approvedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        clientID: UUID,
        version: Int,
        content: String,
        aiModelName: String = "",
        approvedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recordID = recordID
        self.clientID = clientID
        self.version = version
        self.content = content
        self.aiModelName = aiModelName
        self.approvedAt = approvedAt
        self.createdAt = createdAt
    }
}
