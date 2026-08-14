import Foundation

struct OrderPaymentSummary: Equatable {
    let servicePaymentsCents: Int
    let refundsCents: Int
    let balanceOffsetCents: Int
    let netCashCents: Int
    let coveredOrderCents: Int
}

enum OrderPaymentLedgerService {
    static func summary(
        transactions: [OrderPaymentTransaction],
        orderPriceCents: Int
    ) -> OrderPaymentSummary {
        let payments = transactions.filter { $0.kind == .servicePayment }.reduce(0) { $0 + $1.amountCents }
        let refunds = transactions.filter { $0.kind == .refund }.reduce(0) { $0 + $1.amountCents }
        let balance = transactions.filter { $0.kind == .balanceOffset }.reduce(0) { $0 + $1.amountCents }
        let netCash = payments - refunds
        let covered = max(0, payments + balance - refunds)
        return OrderPaymentSummary(
            servicePaymentsCents: payments,
            refundsCents: refunds,
            balanceOffsetCents: balance,
            netCashCents: netCash,
            coveredOrderCents: min(covered, max(orderPriceCents, 0))
        )
    }

    static func remainingCents(
        transactions: [OrderPaymentTransaction],
        orderPriceCents: Int
    ) -> Int {
        max(0, orderPriceCents - summary(transactions: transactions, orderPriceCents: orderPriceCents).coveredOrderCents)
    }

    static func paymentStatus(
        transactions: [OrderPaymentTransaction],
        orderPriceCents: Int
    ) -> PaymentStatus {
        let value = summary(transactions: transactions, orderPriceCents: orderPriceCents)
        if value.refundsCents > 0 && value.coveredOrderCents == 0 && value.servicePaymentsCents > 0 { return .refunded }
        if orderPriceCents > 0 && value.coveredOrderCents >= orderPriceCents {
            return value.servicePaymentsCents > value.refundsCents ? .paid : .balance
        }
        if value.coveredOrderCents > 0 { return .partial }
        return .unpaid
    }

    static func validate(
        kind: PaymentTransactionKind,
        amountCents: Int,
        transactions: [OrderPaymentTransaction],
        orderPriceCents: Int
    ) throws {
        guard amountCents > 0 else { throw PaymentLedgerError.invalidAmount }
        switch kind {
        case .servicePayment, .balanceOffset:
            let remaining = remainingCents(transactions: transactions, orderPriceCents: orderPriceCents)
            guard amountCents <= remaining else { throw PaymentLedgerError.serviceOverpayment(remaining) }
        case .refund:
            let available = max(0, summary(transactions: transactions, orderPriceCents: orderPriceCents).netCashCents)
            guard amountCents <= available else { throw PaymentLedgerError.refundExceedsCash(available) }
        case .rushFee, .rescheduleFee, .otherIncome:
            break
        }
    }

    @MainActor
    static func refreshOrderStatus(
        _ order: ServiceOrder,
        transactions: [OrderPaymentTransaction],
        reference: Date = .now
    ) {
        order.paymentStatus = paymentStatus(transactions: transactions, orderPriceCents: order.totalPriceCents)
        if order.status == .completed || order.status == .cancelled {
            order.updatedAt = reference
            return
        }
        let canActivate = [.paid, .balance].contains(order.paymentStatus)
            || (order.paymentStatus == .partial && order.productKind == .project)
        if canActivate {
            if order.activatedAt == nil {
                order.activatedAt = reference
                order.validFrom = reference
                if let validDays = order.validDaysSnapshot, validDays > 0 {
                    order.expiresAt = Calendar.current.date(byAdding: .day, value: validDays, to: reference)
                }
            }
            if let expiresAt = order.expiresAt, expiresAt < reference {
                order.status = .expired
            } else {
                order.status = .active
            }
        } else {
            order.status = .pendingPayment
        }
        order.updatedAt = reference
    }
}

enum EntitlementService {
    static func usedSessions(orderID: UUID, redemptions: [EntitlementRedemption]) -> Int {
        redemptions.filter { $0.orderID == orderID && !$0.isReversed }.count
    }

    static func reservedSessions(orderID: UUID, redemptions: [EntitlementRedemption]) -> Int {
        redemptions.filter { $0.orderID == orderID && !$0.isReversed && $0.state == .reserved }.count
    }

    static func consumedSessions(orderID: UUID, redemptions: [EntitlementRedemption]) -> Int {
        redemptions.filter { $0.orderID == orderID && !$0.isReversed && $0.state == .consumed }.count
    }

    static func remainingSessions(order: ServiceOrder, redemptions: [EntitlementRedemption]) -> Int {
        max(0, order.includedSessions - usedSessions(orderID: order.id, redemptions: redemptions))
    }

    static func canRedeem(order: ServiceOrder, redemptions: [EntitlementRedemption], at date: Date) -> Bool {
        guard order.status == .active,
              order.productKind == .package,
              date >= order.validFrom,
              order.expiresAt.map({ date <= $0 }) ?? true else { return false }
        return remainingSessions(order: order, redemptions: redemptions) > 0
    }

    @MainActor
    static func consume(
        redemption: EntitlementRedemption,
        order: ServiceOrder,
        allRedemptions: [EntitlementRedemption],
        at date: Date = .now
    ) {
        guard !redemption.isReversed else { return }
        redemption.state = .consumed
        redemption.redeemedAt = date
        redemption.note = "咨询完成后核销 1 次套餐权益"
        if consumedSessions(orderID: order.id, redemptions: allRedemptions) >= order.includedSessions {
            order.status = .completed
        }
        order.updatedAt = date
    }

    static func activeRedemption(
        appointmentID: UUID,
        redemptions: [EntitlementRedemption]
    ) -> EntitlementRedemption? {
        redemptions.first { $0.appointmentID == appointmentID && !$0.isReversed }
    }

    @MainActor
    static func returnSession(
        redemption: EntitlementRedemption,
        order: ServiceOrder,
        allRedemptions: [EntitlementRedemption],
        reason: String,
        at date: Date = .now
    ) {
        redemption.reversedAt = date
        redemption.reversalReason = reason
        guard order.status != .cancelled else {
            order.updatedAt = date
            return
        }

        if let expiresAt = order.expiresAt, expiresAt < date {
            order.status = .expired
        } else if remainingSessions(order: order, redemptions: allRedemptions) > 0,
                  [.paid, .balance].contains(order.paymentStatus) {
            order.status = .active
        }
        order.updatedAt = date
    }
}

enum ServiceOrderChangeError: LocalizedError, Equatable {
    case packageRequired
    case missingExpiration
    case expirationMustMoveForward
    case expirationMustBeFuture
    case extensionAlreadyUsed
    case extensionExceedsLimit
    case reasonRequired

    var errorDescription: String? {
        switch self {
        case .packageRequired: return "只有多次套餐可以延期。"
        case .missingExpiration: return "当前套餐没有有效期，请先核对产品与服务设置。"
        case .expirationMustMoveForward: return "新的有效期必须晚于当前有效期。"
        case .expirationMustBeFuture: return "新的有效期必须晚于今天。"
        case .extensionAlreadyUsed: return "该套餐已经人工延期过 1 次，不能再次延期。"
        case .extensionExceedsLimit: return "单次延期最多 30 天。"
        case .reasonRequired: return "请填写延期或变更原因。"
        }
    }
}

enum ServiceOrderChangeService {
    static func validateExtension(
        order: ServiceOrder,
        newExpiration: Date,
        reason: String,
        referenceDate: Date = .now,
        existingChanges: [ServiceOrderChange] = []
    ) throws {
        guard order.productKind == .package else { throw ServiceOrderChangeError.packageRequired }
        guard let currentExpiration = order.expiresAt else { throw ServiceOrderChangeError.missingExpiration }
        guard newExpiration > currentExpiration else { throw ServiceOrderChangeError.expirationMustMoveForward }
        guard newExpiration > referenceDate else { throw ServiceOrderChangeError.expirationMustBeFuture }
        guard !existingChanges.contains(where: { $0.kind == .expirationExtended }) else {
            throw ServiceOrderChangeError.extensionAlreadyUsed
        }
        let extensionBase = max(currentExpiration, referenceDate)
        let maximumExpiration = Calendar.current.date(byAdding: .day, value: 30, to: extensionBase)
            ?? extensionBase.addingTimeInterval(30 * 86_400)
        guard newExpiration <= maximumExpiration else {
            throw ServiceOrderChangeError.extensionExceedsLimit
        }
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceOrderChangeError.reasonRequired
        }
    }

    @MainActor
    static func extendPackage(
        order: ServiceOrder,
        newExpiration: Date,
        reason: String,
        existingChanges: [ServiceOrderChange] = [],
        at date: Date = .now
    ) throws -> ServiceOrderChange {
        try validateExtension(
            order: order,
            newExpiration: newExpiration,
            reason: reason,
            referenceDate: date,
            existingChanges: existingChanges
        )
        let previous = order.expiresAt!
        order.expiresAt = newExpiration
        if order.status == .expired, [.paid, .balance].contains(order.paymentStatus) {
            order.status = .active
        }
        order.updatedAt = date
        return ServiceOrderChange(
            orderID: order.id,
            clientID: order.clientID,
            clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot,
            kind: .expirationExtended,
            title: "套餐有效期延期",
            beforeValue: previous.formatted(date: .abbreviated, time: .omitted),
            afterValue: newExpiration.formatted(date: .abbreviated, time: .omitted),
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: date
        )
    }

    static func audit(
        order: ServiceOrder,
        kind: ServiceOrderChangeKind,
        title: String,
        beforeValue: String = "",
        afterValue: String = "",
        reason: String,
        at date: Date = .now
    ) -> ServiceOrderChange {
        ServiceOrderChange(
            orderID: order.id,
            clientID: order.clientID,
            clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot,
            kind: kind,
            title: title,
            beforeValue: beforeValue,
            afterValue: afterValue,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: date
        )
    }
}
