import Foundation
import SwiftData

@Model
final class EntitlementRedemption {
    @Attribute(.unique) var id: UUID
    var orderID: UUID
    var appointmentID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var stateRaw: String?
    var redeemedAt: Date
    var note: String
    var reversedAt: Date?
    var reversalReason: String?
    var createdAt: Date

    var isReversed: Bool { reversedAt != nil }
    var state: EntitlementRedemptionState {
        get { stateRaw.flatMap(EntitlementRedemptionState.init(rawValue:)) ?? .reserved }
        set { stateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        orderID: UUID,
        appointmentID: UUID,
        clientID: UUID,
        clientCode: String,
        serviceNameSnapshot: String,
        state: EntitlementRedemptionState = .reserved,
        redeemedAt: Date = .now,
        note: String = "",
        reversedAt: Date? = nil,
        reversalReason: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.orderID = orderID
        self.appointmentID = appointmentID
        self.clientID = clientID
        self.clientCode = clientCode
        self.serviceNameSnapshot = serviceNameSnapshot
        self.stateRaw = state.rawValue
        self.redeemedAt = redeemedAt
        self.note = note
        self.reversedAt = reversedAt
        self.reversalReason = reversalReason
        self.createdAt = createdAt
    }
}
