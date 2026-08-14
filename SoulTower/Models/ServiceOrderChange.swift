import Foundation
import SwiftData

@Model
final class ServiceOrderChange {
    @Attribute(.unique) var id: UUID
    var orderID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var kindRaw: String
    var title: String
    var beforeValue: String
    var afterValue: String
    var reason: String
    var occurredAt: Date
    var createdAt: Date

    var kind: ServiceOrderChangeKind {
        get { ServiceOrderChangeKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        orderID: UUID,
        clientID: UUID,
        clientCode: String,
        serviceNameSnapshot: String,
        kind: ServiceOrderChangeKind,
        title: String,
        beforeValue: String = "",
        afterValue: String = "",
        reason: String,
        occurredAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.orderID = orderID
        self.clientID = clientID
        self.clientCode = clientCode
        self.serviceNameSnapshot = serviceNameSnapshot
        self.kindRaw = kind.rawValue
        self.title = title
        self.beforeValue = beforeValue
        self.afterValue = afterValue
        self.reason = reason
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}
