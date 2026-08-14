import Foundation

struct BusinessCashEntry: Identifiable, Equatable {
    let id: UUID
    let clientCode: String
    let serviceNameSnapshot: String
    let kind: PaymentTransactionKind
    let method: PaymentMethod
    let amountCents: Int
    let occurredAt: Date
    let note: String
    let sourceName: String

    var signedCashCents: Int {
        guard kind != .balanceOffset else { return 0 }
        return kind == .refund ? -amountCents : amountCents
    }

    var displayAmountCents: Int { kind == .refund ? -amountCents : amountCents }
}

struct BusinessServiceSummary: Identifiable, Equatable {
    let serviceName: String
    let appointmentCount: Int
    let completedCount: Int
    let netCashCents: Int

    var id: String { serviceName }
    var paidPriceCents: Int { netCashCents }
}

struct BusinessSummary: Equatable {
    let appointmentCount: Int
    let serviceOrderCount: Int
    let completedCount: Int
    let cancelledCount: Int
    let noShowCount: Int
    let pendingPaymentCount: Int
    let partialPaymentCount: Int
    let cashIncomeCents: Int
    let refundCents: Int
    let netCashCents: Int
    let servicePaymentCents: Int
    let rushFeeCents: Int
    let rescheduleFeeCents: Int
    let otherIncomeCents: Int
    let balanceOffsetCents: Int
    let unverifiedLegacyCount: Int
    let rescheduleFeeNoteCount: Int
    let paymentStatusCounts: [PaymentStatus: Int]
    let services: [BusinessServiceSummary]
    let recentTransactions: [BusinessCashEntry]

    var paidPriceCents: Int { servicePaymentCents }
    var balancePriceCents: Int { balanceOffsetCents }
    var refundedPriceCents: Int { refundCents }

    static let empty = BusinessSummary(
        appointmentCount: 0, serviceOrderCount: 0, completedCount: 0, cancelledCount: 0,
        noShowCount: 0, pendingPaymentCount: 0, partialPaymentCount: 0,
        cashIncomeCents: 0, refundCents: 0, netCashCents: 0, servicePaymentCents: 0,
        rushFeeCents: 0, rescheduleFeeCents: 0, otherIncomeCents: 0, balanceOffsetCents: 0,
        unverifiedLegacyCount: 0, rescheduleFeeNoteCount: 0, paymentStatusCounts: [:],
        services: [], recentTransactions: []
    )
}

enum BusinessAnalytics {
    /// 预约和订单数量按建立/服务时间归期；现金金额按流水发生时间归期。
    static func summary(
        appointments: [Appointment],
        transactions: [PaymentTransaction] = [],
        serviceOrders: [ServiceOrder] = [],
        orderTransactions: [OrderPaymentTransaction] = [],
        interval: DateInterval? = nil
    ) -> BusinessSummary {
        let validAppointments = appointments.filter { $0.status != .rescheduled && $0.status != .pendingRules }
        let validAppointmentIDs = Set(validAppointments.map(\.id))
        let periodAppointments = validAppointments.filter { isInPeriod($0.startAt, interval: interval) }
        let periodOrders = serviceOrders.filter { isInPeriod($0.placedAt, interval: interval) }
        let validOrderIDs = Set(serviceOrders.map(\.id))

        let appointmentEntries = transactions.filter {
            validAppointmentIDs.contains($0.appointmentID) && isInPeriod($0.occurredAt, interval: interval)
        }.map(entry)
        let orderEntries = orderTransactions.filter {
            validOrderIDs.contains($0.orderID) && isInPeriod($0.occurredAt, interval: interval)
        }.map(entry)
        let entries = appointmentEntries + orderEntries

        let servicePayments = amount(entries, kinds: [.servicePayment])
        let rushFees = amount(entries, kinds: [.rushFee])
        let rescheduleFees = amount(entries, kinds: [.rescheduleFee])
        let otherIncome = amount(entries, kinds: [.otherIncome])
        let refunds = amount(entries, kinds: [.refund])
        let balance = amount(entries, kinds: [.balanceOffset])
        let cashIncome = servicePayments + rushFees + rescheduleFees + otherIncome

        let pendingAppointments = periodAppointments.filter {
            ![.cancelled, .noShow].contains($0.status) && [.unpaid, .partial].contains($0.paymentStatus)
        }
        let pendingOrders = periodOrders.filter {
            $0.status != .cancelled && [.unpaid, .partial].contains($0.paymentStatus)
        }

        var paymentStatusCounts: [PaymentStatus: Int] = [:]
        PaymentStatus.allCases.forEach { status in
            paymentStatusCounts[status] = periodAppointments.filter { $0.paymentStatus == status }.count
        }

        let appointmentGroups = Dictionary(grouping: periodAppointments, by: \.serviceNameSnapshot)
        let entryGroups = Dictionary(grouping: entries, by: \.serviceNameSnapshot)
        let serviceNames = Set(appointmentGroups.keys).union(entryGroups.keys)
        let services = serviceNames.map { serviceName in
            let serviceAppointments = appointmentGroups[serviceName, default: []]
            let serviceEntries = entryGroups[serviceName, default: []]
            return BusinessServiceSummary(
                serviceName: serviceName,
                appointmentCount: serviceAppointments.count,
                completedCount: serviceAppointments.filter { $0.status == .completed }.count,
                netCashCents: serviceEntries.reduce(0) { $0 + $1.signedCashCents }
            )
        }.sorted {
            if $0.netCashCents == $1.netCashCents {
                if $0.appointmentCount == $1.appointmentCount {
                    return $0.serviceName.localizedStandardCompare($1.serviceName) == .orderedAscending
                }
                return $0.appointmentCount > $1.appointmentCount
            }
            return $0.netCashCents > $1.netCashCents
        }

        return BusinessSummary(
            appointmentCount: periodAppointments.count,
            serviceOrderCount: periodOrders.count,
            completedCount: periodAppointments.filter { $0.status == .completed }.count,
            cancelledCount: periodAppointments.filter { $0.status == .cancelled }.count,
            noShowCount: periodAppointments.filter { $0.status == .noShow }.count,
            pendingPaymentCount: pendingAppointments.count + pendingOrders.count,
            partialPaymentCount: periodAppointments.filter { $0.paymentStatus == .partial }.count + periodOrders.filter { $0.paymentStatus == .partial }.count,
            cashIncomeCents: cashIncome,
            refundCents: refunds,
            netCashCents: cashIncome - refunds,
            servicePaymentCents: servicePayments,
            rushFeeCents: rushFees,
            rescheduleFeeCents: rescheduleFees,
            otherIncomeCents: otherIncome,
            balanceOffsetCents: balance,
            unverifiedLegacyCount: entries.filter { $0.method == .legacy }.count,
            rescheduleFeeNoteCount: appointments.filter {
                $0.status == .rescheduled && isInPeriod($0.startAt, interval: interval) &&
                ($0.notes.contains("记录 200 元调整费") || $0.notes.contains("已实收 200 元调整费"))
            }.count,
            paymentStatusCounts: paymentStatusCounts,
            services: services,
            recentTransactions: Array(entries.sorted { $0.occurredAt > $1.occurredAt }.prefix(12))
        )
    }

    static func transactions(
        _ transactions: [PaymentTransaction],
        appointments: [Appointment],
        orderTransactions: [OrderPaymentTransaction] = [],
        serviceOrders: [ServiceOrder] = [],
        interval: DateInterval?
    ) -> [BusinessCashEntry] {
        let validAppointmentIDs = Set(appointments.filter {
            $0.status != .rescheduled && $0.status != .pendingRules
        }.map(\.id))
        let validOrderIDs = Set(serviceOrders.map(\.id))
        let appointmentEntries = transactions.filter {
            validAppointmentIDs.contains($0.appointmentID) && isInPeriod($0.occurredAt, interval: interval)
        }.map(entry)
        let orderEntries = orderTransactions.filter {
            validOrderIDs.contains($0.orderID) && isInPeriod($0.occurredAt, interval: interval)
        }.map(entry)
        return (appointmentEntries + orderEntries).sorted { $0.occurredAt < $1.occurredAt }
    }

    private static func entry(_ value: PaymentTransaction) -> BusinessCashEntry {
        BusinessCashEntry(id: value.id, clientCode: value.clientCode, serviceNameSnapshot: value.serviceNameSnapshot,
                          kind: value.kind, method: value.method, amountCents: value.amountCents,
                          occurredAt: value.occurredAt, note: value.note, sourceName: "预约")
    }

    private static func entry(_ value: OrderPaymentTransaction) -> BusinessCashEntry {
        BusinessCashEntry(id: value.id, clientCode: value.clientCode, serviceNameSnapshot: value.serviceNameSnapshot,
                          kind: value.kind, method: value.method, amountCents: value.amountCents,
                          occurredAt: value.occurredAt, note: value.note, sourceName: "套餐/项目订单")
    }

    private static func amount(_ entries: [BusinessCashEntry], kinds: Set<PaymentTransactionKind>) -> Int {
        entries.filter { kinds.contains($0.kind) }.reduce(0) { $0 + $1.amountCents }
    }

    private static func isInPeriod(_ date: Date, interval: DateInterval?) -> Bool {
        guard let interval else { return true }
        return date >= interval.start && date < interval.end
    }
}
