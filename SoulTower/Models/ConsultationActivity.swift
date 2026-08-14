import Foundation
import SwiftData

@Model
final class ConsultationActivity {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var clientID: UUID
    var kindRaw: String
    var title: String
    var detail: String
    var occurredAt: Date
    var createdAt: Date

    var kind: ConsultationActivityKind {
        get { ConsultationActivityKind(rawValue: kindRaw) ?? .recordCreated }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        recordID: UUID,
        clientID: UUID,
        kind: ConsultationActivityKind,
        title: String,
        detail: String = "",
        occurredAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recordID = recordID
        self.clientID = clientID
        self.kindRaw = kind.rawValue
        self.title = title
        self.detail = detail
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}
