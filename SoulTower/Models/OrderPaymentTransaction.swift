import Foundation
import SwiftData

@Model
final class OrderPaymentTransaction {
    @Attribute(.unique) var id: UUID
    var orderID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var kindRaw: String
    var methodRaw: String
    var amountCents: Int
    var occurredAt: Date
    var note: String
    var createdAt: Date

    var kind: PaymentTransactionKind {
        get { PaymentTransactionKind(rawValue: kindRaw) ?? .servicePayment }
        set { kindRaw = newValue.rawValue }
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .wechat }
        set { methodRaw = newValue.rawValue }
    }

    var signedCashCents: Int {
        guard kind != .balanceOffset else { return 0 }
        return kind == .refund ? -amountCents : amountCents
    }

    var displayAmountCents: Int {
        kind == .refund ? -amountCents : amountCents
    }

    init(
        id: UUID = UUID(),
        orderID: UUID,
        clientID: UUID,
        clientCode: String,
        serviceNameSnapshot: String,
        kind: PaymentTransactionKind,
        method: PaymentMethod,
        amountCents: Int,
        occurredAt: Date = .now,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.orderID = orderID
        self.clientID = clientID
        self.clientCode = clientCode
        self.serviceNameSnapshot = serviceNameSnapshot
        self.kindRaw = kind.rawValue
        self.methodRaw = method.rawValue
        self.amountCents = amountCents
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = createdAt
    }
}
