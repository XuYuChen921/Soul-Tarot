import Foundation
import SwiftData

@Model
final class PaymentTransaction {
    @Attribute(.unique) var id: UUID
    var appointmentID: UUID
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

    /// 退款以负数计入现金净额；余额抵扣不属于现金流水。
    var signedCashCents: Int {
        guard kind != .balanceOffset else { return 0 }
        return kind == .refund ? -amountCents : amountCents
    }

    /// 用于逐笔展示；余额抵扣显示抵扣额，但仍不进入现金统计。
    var displayAmountCents: Int {
        kind == .refund ? -amountCents : amountCents
    }

    init(
        id: UUID = UUID(),
        appointmentID: UUID,
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
        self.appointmentID = appointmentID
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
