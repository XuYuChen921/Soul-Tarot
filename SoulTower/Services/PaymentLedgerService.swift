import Foundation
import SwiftData

struct AppointmentPaymentSummary: Equatable {
    let servicePaymentsCents: Int
    let refundsCents: Int
    let balanceOffsetCents: Int
    let feeIncomeCents: Int
    let netCashCents: Int
    let coveredServiceCents: Int

}

enum PaymentLedgerError: LocalizedError, Equatable {
    case invalidAmount
    case serviceOverpayment(Int)
    case refundExceedsCash(Int)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "金额必须大于 0 元，最多保留两位小数。"
        case .serviceOverpayment(let remaining):
            return "咨询费收款超过待收金额，当前最多可记录 \(remaining.yuanText)。额外费用请选择加急费、改期费或其他收款。"
        case .refundExceedsCash(let available):
            return "退款超过当前可退现金，最多可记录 \(available.yuanText)。"
        }
    }
}

enum PaymentLedgerService {
    static func summary(transactions: [PaymentTransaction], appointmentPriceCents: Int) -> AppointmentPaymentSummary {
        let servicePayments = transactions
            .filter { $0.kind == .servicePayment }
            .reduce(0) { $0 + $1.amountCents }
        let refunds = transactions
            .filter { $0.kind == .refund }
            .reduce(0) { $0 + $1.amountCents }
        let balance = transactions
            .filter { $0.kind == .balanceOffset }
            .reduce(0) { $0 + $1.amountCents }
        let fees = transactions
            .filter { [.rushFee, .rescheduleFee, .otherIncome].contains($0.kind) }
            .reduce(0) { $0 + $1.amountCents }
        let cashIncome = transactions
            .filter { $0.kind != .refund && $0.kind != .balanceOffset }
            .reduce(0) { $0 + $1.amountCents }
        let netCash = cashIncome - refunds
        let covered = max(0, servicePayments + balance - refunds)
        return AppointmentPaymentSummary(
            servicePaymentsCents: servicePayments,
            refundsCents: refunds,
            balanceOffsetCents: balance,
            feeIncomeCents: fees,
            netCashCents: netCash,
            coveredServiceCents: min(covered, max(appointmentPriceCents, 0))
        )
    }

    static func remainingServiceCents(
        transactions: [PaymentTransaction],
        appointmentPriceCents: Int
    ) -> Int {
        let value = summary(transactions: transactions, appointmentPriceCents: appointmentPriceCents)
        return max(0, appointmentPriceCents - value.coveredServiceCents)
    }

    static func paymentStatus(
        transactions: [PaymentTransaction],
        appointmentPriceCents: Int
    ) -> PaymentStatus {
        let value = summary(transactions: transactions, appointmentPriceCents: appointmentPriceCents)
        if value.refundsCents > 0 && value.coveredServiceCents == 0 && value.servicePaymentsCents > 0 {
            return .refunded
        }
        if appointmentPriceCents > 0 && value.coveredServiceCents >= appointmentPriceCents {
            return value.servicePaymentsCents > value.refundsCents ? .paid : .balance
        }
        if value.coveredServiceCents > 0 { return .partial }
        return .unpaid
    }

    static func validate(
        kind: PaymentTransactionKind,
        amountCents: Int,
        transactions: [PaymentTransaction],
        appointmentPriceCents: Int
    ) throws {
        guard amountCents > 0 else { throw PaymentLedgerError.invalidAmount }
        switch kind {
        case .servicePayment, .balanceOffset:
            let remaining = remainingServiceCents(
                transactions: transactions,
                appointmentPriceCents: appointmentPriceCents
            )
            guard amountCents <= remaining else { throw PaymentLedgerError.serviceOverpayment(remaining) }
        case .refund:
            let available = max(0, summary(
                transactions: transactions,
                appointmentPriceCents: appointmentPriceCents
            ).netCashCents)
            guard amountCents <= available else { throw PaymentLedgerError.refundExceedsCash(available) }
        case .rushFee, .rescheduleFee, .otherIncome:
            break
        }
    }

    @MainActor
    static func refreshAppointmentStatus(
        _ appointment: Appointment,
        transactions: [PaymentTransaction]
    ) {
        if appointment.serviceOrderID != nil {
            appointment.paymentStatus = .entitlement
            if ![.cancelled, .noShow, .completed].contains(appointment.status) {
                appointment.status = .confirmed
            }
            appointment.updatedAt = .now
            return
        }
        appointment.paymentStatus = paymentStatus(
            transactions: transactions,
            appointmentPriceCents: appointment.priceCents
        )
        if appointment.status == .cancelled || appointment.status == .noShow || appointment.status == .completed {
            appointment.updatedAt = .now
            return
        }
        if appointment.paymentStatus == .paid || appointment.paymentStatus == .balance {
            appointment.status = .confirmed
        } else {
            appointment.status = .pendingPayment
        }
        appointment.updatedAt = .now
    }

    static func yuanTextToCents(_ text: String) -> Int? {
        let clean = text
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let decimal = Decimal(string: clean, locale: Locale(identifier: "zh_CN")),
              decimal > 0 else { return nil }
        var value = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != .notANumber,
              number.compare(NSDecimalNumber(value: Int.max)) != .orderedDescending else { return nil }
        return number.intValue
    }
}
