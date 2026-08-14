import XCTest
import SwiftData
@testable import SoulTower

final class BusinessRulesTests: XCTestCase {
    func testBusinessSummaryExcludesRescheduleHistoryAndPendingRules() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 16)))
        let clientID = UUID()
        let serviceID = UUID()

        let completed = Appointment(
            clientID: clientID,
            clientCode: "C-0001",
            clientNameSnapshot: "测试客户",
            serviceID: serviceID,
            serviceNameSnapshot: "单项咨询",
            startAt: day,
            endAt: day.addingTimeInterval(2_400),
            status: .completed,
            paymentStatus: .paid,
            priceCents: 66_600,
            policyVersion: "TEST"
        )
        let cancelledPaid = Appointment(
            clientID: clientID,
            clientCode: "C-0001",
            clientNameSnapshot: "测试客户",
            serviceID: serviceID,
            serviceNameSnapshot: "深度咨询",
            startAt: day.addingTimeInterval(86_400),
            endAt: day.addingTimeInterval(90_000),
            status: .cancelled,
            paymentStatus: .paid,
            priceCents: 111_100,
            policyVersion: "TEST"
        )
        let rescheduleHistory = Appointment(
            clientID: clientID,
            clientCode: "C-0001",
            clientNameSnapshot: "测试客户",
            serviceID: serviceID,
            serviceNameSnapshot: "单项咨询",
            startAt: day,
            endAt: day.addingTimeInterval(2_400),
            status: .rescheduled,
            paymentStatus: .paid,
            priceCents: 66_600,
            policyVersion: "TEST",
            notes: "记录 200 元调整费"
        )
        let pendingRules = Appointment(
            clientID: clientID,
            clientCode: "C-0001",
            clientNameSnapshot: "测试客户",
            serviceID: serviceID,
            serviceNameSnapshot: "不应统计",
            startAt: day,
            endAt: day.addingTimeInterval(2_400),
            status: .pendingRules,
            paymentStatus: .paid,
            priceCents: 999_900,
            policyVersion: "TEST"
        )

        let summary = BusinessAnalytics.summary(
            appointments: [completed, cancelledPaid, rescheduleHistory, pendingRules],
            transactions: [
                PaymentTransaction(appointmentID: completed.id, clientID: clientID, clientCode: "C-0001", serviceNameSnapshot: completed.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 66_600),
                PaymentTransaction(appointmentID: cancelledPaid.id, clientID: clientID, clientCode: "C-0001", serviceNameSnapshot: cancelledPaid.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 111_100),
                PaymentTransaction(appointmentID: rescheduleHistory.id, clientID: clientID, clientCode: "C-0001", serviceNameSnapshot: rescheduleHistory.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 66_600)
            ]
        )

        XCTAssertEqual(summary.appointmentCount, 2)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.cancelledCount, 1)
        XCTAssertEqual(summary.paidPriceCents, 177_700)
        XCTAssertEqual(summary.rescheduleFeeNoteCount, 1)
        XCTAssertEqual(summary.services.count, 2)
    }

    func testBusinessSummaryKeepsCashBalanceRefundAndPendingSeparate() {
        let day = Date(timeIntervalSince1970: 1_786_550_400)
        func appointment(payment: PaymentStatus, status: AppointmentStatus = .confirmed, price: Int) -> Appointment {
            Appointment(
                clientID: UUID(),
                clientCode: "C-TEST",
                clientNameSnapshot: "测试客户",
                serviceID: UUID(),
                serviceNameSnapshot: "测试服务",
                startAt: day,
                endAt: day.addingTimeInterval(3_600),
                status: status,
                paymentStatus: payment,
                priceCents: price,
                policyVersion: "TEST"
            )
        }

        let paid = appointment(payment: .paid, price: 66_600)
        let balance = appointment(payment: .balance, price: 36_800)
        let refunded = appointment(payment: .refunded, price: 99_900)
        let unpaid = appointment(payment: .unpaid, price: 111_100)
        let partial = appointment(payment: .partial, price: 166_600)
        let cancelled = appointment(payment: .unpaid, status: .cancelled, price: 399_900)
        let summary = BusinessAnalytics.summary(
            appointments: [paid, balance, refunded, unpaid, partial, cancelled],
            transactions: [
                PaymentTransaction(appointmentID: paid.id, clientID: paid.clientID, clientCode: paid.clientCode, serviceNameSnapshot: paid.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 66_600, occurredAt: day),
                PaymentTransaction(appointmentID: balance.id, clientID: balance.clientID, clientCode: balance.clientCode, serviceNameSnapshot: balance.serviceNameSnapshot, kind: .balanceOffset, method: .balance, amountCents: 36_800, occurredAt: day),
                PaymentTransaction(appointmentID: refunded.id, clientID: refunded.clientID, clientCode: refunded.clientCode, serviceNameSnapshot: refunded.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 99_900, occurredAt: day),
                PaymentTransaction(appointmentID: refunded.id, clientID: refunded.clientID, clientCode: refunded.clientCode, serviceNameSnapshot: refunded.serviceNameSnapshot, kind: .refund, method: .wechat, amountCents: 99_900, occurredAt: day),
                PaymentTransaction(appointmentID: partial.id, clientID: partial.clientID, clientCode: partial.clientCode, serviceNameSnapshot: partial.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 20_000, occurredAt: day)
            ]
        )

        XCTAssertEqual(summary.paidPriceCents, 186_500)
        XCTAssertEqual(summary.balancePriceCents, 36_800)
        XCTAssertEqual(summary.refundedPriceCents, 99_900)
        XCTAssertEqual(summary.netCashCents, 86_600)
        XCTAssertEqual(summary.pendingPaymentCount, 2)
        XCTAssertEqual(summary.partialPaymentCount, 1)
        XCTAssertEqual(summary.paymentStatusCounts[.unpaid], 2)
    }

    func testBusinessSummaryUsesHalfOpenDateInterval() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let end = start.addingTimeInterval(86_400)
        func appointment(at date: Date) -> Appointment {
            Appointment(
                clientID: UUID(),
                clientCode: "C-TEST",
                clientNameSnapshot: "测试客户",
                serviceID: UUID(),
                serviceNameSnapshot: "测试服务",
                startAt: date,
                endAt: date.addingTimeInterval(3_600),
                priceCents: 66_600,
                policyVersion: "TEST"
            )
        }

        let included = appointment(at: start)
        let excluded = appointment(at: end)
        let summary = BusinessAnalytics.summary(
            appointments: [included, excluded],
            transactions: [
                PaymentTransaction(appointmentID: included.id, clientID: included.clientID, clientCode: included.clientCode, serviceNameSnapshot: included.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 66_600, occurredAt: start),
                PaymentTransaction(appointmentID: excluded.id, clientID: excluded.clientID, clientCode: excluded.clientCode, serviceNameSnapshot: excluded.serviceNameSnapshot, kind: .servicePayment, method: .wechat, amountCents: 66_600, occurredAt: end)
            ],
            interval: DateInterval(start: start, end: end)
        )

        XCTAssertEqual(summary.appointmentCount, 1)
        XCTAssertEqual(summary.paidPriceCents, 66_600)
    }

    func testPaymentLedgerSupportsPartialPaymentFeeAndRefund() throws {
        let appointmentID = UUID()
        let clientID = UUID()
        let partial = PaymentTransaction(
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: "C-PAY",
            serviceNameSnapshot: "测试服务",
            kind: .servicePayment,
            method: .wechat,
            amountCents: 20_000
        )
        let fee = PaymentTransaction(
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: "C-PAY",
            serviceNameSnapshot: "测试服务",
            kind: .rushFee,
            method: .wechat,
            amountCents: 20_000
        )
        let refund = PaymentTransaction(
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: "C-PAY",
            serviceNameSnapshot: "测试服务",
            kind: .refund,
            method: .wechat,
            amountCents: 10_000
        )

        let summary = PaymentLedgerService.summary(
            transactions: [partial, fee, refund],
            appointmentPriceCents: 66_600
        )

        XCTAssertEqual(summary.coveredServiceCents, 10_000)
        XCTAssertEqual(summary.feeIncomeCents, 20_000)
        XCTAssertEqual(summary.netCashCents, 30_000)
        XCTAssertEqual(PaymentLedgerService.paymentStatus(transactions: [partial, fee, refund], appointmentPriceCents: 66_600), .partial)
        XCTAssertThrowsError(try PaymentLedgerService.validate(kind: .refund, amountCents: 30_001, transactions: [partial, fee, refund], appointmentPriceCents: 66_600))
    }

    func testYuanTextParserRoundsToCentsAndRejectsEmpty() {
        XCTAssertEqual(PaymentLedgerService.yuanTextToCents("￥666.25"), 66_625)
        XCTAssertEqual(PaymentLedgerService.yuanTextToCents("200"), 20_000)
        XCTAssertNil(PaymentLedgerService.yuanTextToCents(""))
        XCTAssertNil(PaymentLedgerService.yuanTextToCents("0"))
    }

    @MainActor
    func testOrderPaymentRequiresFullCoverageBeforeActivation() throws {
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-ORDER", clientNameSnapshot: "测试客户",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, policyVersion: "TEST"
        )
        let partial = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 100_000
        )

        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: [partial])
        XCTAssertEqual(order.paymentStatus, .partial)
        XCTAssertEqual(order.status, .pendingPayment)

        let final = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 299_900
        )
        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: [partial, final])
        XCTAssertEqual(order.paymentStatus, .paid)
        XCTAssertEqual(order.status, .active)
    }

    @MainActor
    func testPackageValidityStartsWhenOrderActuallyActivates() {
        let activationDate = Date(timeIntervalSince1970: 1_786_550_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-ACTIVATE", clientNameSnapshot: "激活测试",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            productKind: .package, deliveryType: .video, pricingMode: .fixed,
            totalPriceCents: 399_900, includedSessions: 4, validDaysSnapshot: 120,
            policyVersion: "TEST"
        )
        let partial = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 100_000
        )

        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: [partial], reference: activationDate)
        XCTAssertNil(order.activatedAt)
        XCTAssertNil(order.expiresAt)

        let final = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 299_900
        )
        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: [partial, final], reference: activationDate)

        XCTAssertEqual(order.activatedAt, activationDate)
        XCTAssertEqual(order.validFrom, activationDate)
        XCTAssertEqual(order.expiresAt, Calendar.current.date(byAdding: .day, value: 120, to: activationDate))
    }

    @MainActor
    func testProjectOrderCanStartAfterPartialDeposit() {
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-PROJECT", clientNameSnapshot: "测试客户",
            serviceID: UUID(), serviceNameSnapshot: "成人改名焕新", categorySnapshot: "起名/改名",
            deliveryType: .project, pricingMode: .startingAt, totalPriceCents: 444_400,
            status: .pendingPayment, paymentStatus: .unpaid, policyVersion: "TEST"
        )
        let deposit = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 222_200
        )

        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: [deposit])

        XCTAssertEqual(order.paymentStatus, .partial)
        XCTAssertEqual(order.status, .active)
    }

    func testPackageEntitlementChecksRemainingSessionsAndExpiry() {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-PACKAGE", clientNameSnapshot: "测试客户",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 2, status: .active, paymentStatus: .paid,
            policyVersion: "TEST", validFrom: now.addingTimeInterval(-3_600),
            expiresAt: now.addingTimeInterval(86_400)
        )
        let used = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: order.clientID,
            clientCode: order.clientCode, serviceNameSnapshot: order.serviceNameSnapshot,
            redeemedAt: now
        )

        XCTAssertTrue(EntitlementService.canRedeem(order: order, redemptions: [used], at: now))
        XCTAssertEqual(EntitlementService.remainingSessions(order: order, redemptions: [used]), 1)

        let second = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: order.clientID,
            clientCode: order.clientCode, serviceNameSnapshot: order.serviceNameSnapshot,
            redeemedAt: now
        )
        XCTAssertFalse(EntitlementService.canRedeem(order: order, redemptions: [used, second], at: now))
        XCTAssertFalse(EntitlementService.canRedeem(order: order, redemptions: [], at: now.addingTimeInterval(172_800)))
    }

    @MainActor
    func testPackageReservationOnlyCompletesAfterConsultationConsumption() {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-RESERVE", clientNameSnapshot: "占用测试",
            serviceID: UUID(), serviceNameSnapshot: "一次套餐", categorySnapshot: "周期疗愈套餐",
            productKind: .package, deliveryType: .video, pricingMode: .fixed,
            totalPriceCents: 99_900, includedSessions: 1, status: .active,
            paymentStatus: .paid, policyVersion: "TEST", validFrom: now.addingTimeInterval(-60)
        )
        let reservation = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: order.clientID,
            clientCode: order.clientCode, serviceNameSnapshot: order.serviceNameSnapshot,
            state: .reserved, redeemedAt: now
        )

        XCTAssertEqual(EntitlementService.reservedSessions(orderID: order.id, redemptions: [reservation]), 1)
        XCTAssertEqual(EntitlementService.consumedSessions(orderID: order.id, redemptions: [reservation]), 0)
        XCTAssertEqual(order.status, .active)

        EntitlementService.consume(
            redemption: reservation,
            order: order,
            allRedemptions: [reservation],
            at: now
        )

        XCTAssertEqual(reservation.state, .consumed)
        XCTAssertEqual(EntitlementService.consumedSessions(orderID: order.id, redemptions: [reservation]), 1)
        XCTAssertEqual(order.status, .completed)
    }

    @MainActor
    func testReturnedEntitlementKeepsAuditAndReactivatesPackage() {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-RETURN", clientNameSnapshot: "返还测试",
            serviceID: UUID(), serviceNameSnapshot: "两次套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 199_900,
            includedSessions: 2, status: .completed, paymentStatus: .paid,
            policyVersion: "TEST", validFrom: now.addingTimeInterval(-86_400),
            expiresAt: now.addingTimeInterval(86_400)
        )
        let first = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: order.clientID,
            clientCode: order.clientCode, serviceNameSnapshot: order.serviceNameSnapshot
        )
        let returned = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: order.clientID,
            clientCode: order.clientCode, serviceNameSnapshot: order.serviceNameSnapshot
        )

        EntitlementService.returnSession(
            redemption: returned,
            order: order,
            allRedemptions: [first, returned],
            reason: "客户提前取消，双方确认返还",
            at: now
        )

        XCTAssertNotNil(returned.reversedAt)
        XCTAssertEqual(returned.reversalReason, "客户提前取消，双方确认返还")
        XCTAssertEqual(EntitlementService.usedSessions(orderID: order.id, redemptions: [first, returned]), 1)
        XCTAssertEqual(EntitlementService.remainingSessions(order: order, redemptions: [first, returned]), 1)
        XCTAssertEqual(order.status, .active)
    }

    @MainActor
    func testExpiredPackageCanBeExtendedWithChangeRecord() throws {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let oldExpiration = now.addingTimeInterval(-86_400)
        let newExpiration = now.addingTimeInterval(30 * 86_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-EXTEND", clientNameSnapshot: "延期测试",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, status: .expired, paymentStatus: .paid,
            policyVersion: "TEST", validFrom: now.addingTimeInterval(-90 * 86_400),
            expiresAt: oldExpiration
        )

        let change = try ServiceOrderChangeService.extendPackage(
            order: order,
            newExpiration: newExpiration,
            reason: "双方协商延期 30 天",
            at: now
        )

        XCTAssertEqual(order.expiresAt, newExpiration)
        XCTAssertEqual(order.status, .active)
        XCTAssertEqual(change.kind, .expirationExtended)
        XCTAssertEqual(change.reason, "双方协商延期 30 天")
        XCTAssertThrowsError(try ServiceOrderChangeService.validateExtension(
            order: order, newExpiration: oldExpiration, reason: "日期倒退", referenceDate: now
        ))

        let longExpiredOrder = ServiceOrder(
            clientID: UUID(), clientCode: "C-EXTEND-PAST", clientNameSnapshot: "延期测试",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, status: .expired, paymentStatus: .paid,
            policyVersion: "TEST", validFrom: now.addingTimeInterval(-400 * 86_400),
            expiresAt: now.addingTimeInterval(-365 * 86_400)
        )
        XCTAssertThrowsError(try ServiceOrderChangeService.validateExtension(
            order: longExpiredOrder,
            newExpiration: now.addingTimeInterval(-30 * 86_400),
            reason: "仍然在过去",
            referenceDate: now
        )) { error in
            XCTAssertEqual(error as? ServiceOrderChangeError, .expirationMustBeFuture)
        }

        let previousExtension = ServiceOrderChangeService.audit(
            order: order,
            kind: .expirationExtended,
            title: "套餐有效期延期",
            reason: "第一次延期",
            at: now
        )
        XCTAssertThrowsError(try ServiceOrderChangeService.validateExtension(
            order: order,
            newExpiration: newExpiration.addingTimeInterval(10 * 86_400),
            reason: "尝试第二次延期",
            referenceDate: now,
            existingChanges: [previousExtension]
        )) { error in
            XCTAssertEqual(error as? ServiceOrderChangeError, .extensionAlreadyUsed)
        }

        let limitOrder = ServiceOrder(
            clientID: UUID(), clientCode: "C-EXTEND-LIMIT", clientNameSnapshot: "延期测试",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, status: .active, paymentStatus: .paid,
            policyVersion: "TEST", validFrom: now,
            expiresAt: now.addingTimeInterval(10 * 86_400)
        )
        XCTAssertThrowsError(try ServiceOrderChangeService.validateExtension(
            order: limitOrder,
            newExpiration: now.addingTimeInterval(41 * 86_400),
            reason: "超过三十天",
            referenceDate: now
        )) { error in
            XCTAssertEqual(error as? ServiceOrderChangeError, .extensionExceedsLimit)
        }
    }

    func testBusinessSummaryIncludesOrderCashButNotEntitlementAppointmentPriceAgain() {
        let now = Date(timeIntervalSince1970: 1_786_550_400)
        let order = ServiceOrder(
            clientID: UUID(), clientCode: "C-PACKAGE", clientNameSnapshot: "测试客户",
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, status: .active, paymentStatus: .paid,
            policyVersion: "TEST", placedAt: now
        )
        let orderPayment = OrderPaymentTransaction(
            orderID: order.id, clientID: order.clientID, clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 399_900, occurredAt: now
        )
        let appointment = Appointment(
            clientID: order.clientID, clientCode: order.clientCode, clientNameSnapshot: order.clientNameSnapshot,
            serviceID: order.serviceID, serviceOrderID: order.id, serviceNameSnapshot: order.serviceNameSnapshot,
            startAt: now, endAt: now.addingTimeInterval(3_600), status: .confirmed,
            paymentStatus: .entitlement, priceCents: 399_900, policyVersion: "TEST"
        )

        let summary = BusinessAnalytics.summary(
            appointments: [appointment], serviceOrders: [order], orderTransactions: [orderPayment]
        )
        XCTAssertEqual(summary.netCashCents, 399_900)
        XCTAssertEqual(summary.serviceOrderCount, 1)
        XCTAssertEqual(summary.paymentStatusCounts[.entitlement], 1)
    }

    func testVoiceTranscriptRetentionKeepsLiveTextWhenFinalResultIsEmpty() {
        let text = VoiceTranscriptRetention.resolvedText(
            current: "客户称呼小林，预约下周四下午四点",
            lastNonEmpty: "客户称呼小林",
            recognitionCandidate: ""
        )

        XCTAssertEqual(text, "客户称呼小林，预约下周四下午四点")
    }

    func testVoiceTranscriptRetentionCanRestoreLastNonEmptyText() {
        let text = VoiceTranscriptRetention.resolvedText(
            current: "",
            lastNonEmpty: "已经识别到的内容",
            recognitionCandidate: "  \n"
        )

        XCTAssertEqual(text, "已经识别到的内容")
    }

    func testVoiceTranscriptRetentionRejectsShorterNonEmptyRollback() {
        let text = VoiceTranscriptRetention.resolvedText(
            current: "客户称呼小林，预约下周四下午四点",
            lastNonEmpty: "客户称呼小林，预约下周四下午四点",
            recognitionCandidate: "预约下周四"
        )

        XCTAssertEqual(text, "客户称呼小林，预约下周四下午四点")
    }

    func testVoiceTranscriptRetentionMergesRecognizerRestartByOverlap() {
        let text = VoiceTranscriptRetention.resolvedText(
            current: "客户称呼小林，预约下周四",
            lastNonEmpty: "客户称呼小林，预约下周四",
            recognitionCandidate: "下周四下午四点，项目是单项咨询"
        )

        XCTAssertEqual(text, "客户称呼小林，预约下周四下午四点，项目是单项咨询")
    }

    @MainActor
    func testConfirmedVoiceArchivePersistsClientAppointmentAndFiveConsents() throws {
        let schema = Schema([Client.self, ServiceItem.self, Appointment.self, ConsentRecord.self, ConsultationRecord.self, MediaAsset.self, PaymentTransaction.self, ServiceOrder.self, OrderPaymentTransaction.self, EntitlementRedemption.self, ServiceOrderChange.self, ConsultationActivity.self, ConsultationSummaryRevision.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let client = Client(clientCode: "C-VOICE-TEST", displayName: "语音建档测试", birthDate: Date(timeIntervalSince1970: 631_152_000))
        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: UUID(),
            serviceNameSnapshot: "测试服务",
            startAt: Date.now.addingTimeInterval(86_400),
            endAt: Date.now.addingTimeInterval(90_000),
            priceCents: 66_600,
            policyVersion: "TEST"
        )
        context.insert(client)
        context.insert(appointment)
        for type in [ConsentType.servicePolicy, .recording, .photo, .localAI, .longTermRetention] {
            context.insert(ConsentRecord(
                clientID: client.id,
                appointmentID: appointment.id,
                type: type,
                textVersion: "TEST",
                textSnapshot: "测试告知",
                accepted: true
            ))
        }

        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Client>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Appointment>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ConsentRecord>()), 5)
    }

    func testLocalAIModelPolicyUsesFourBForSixteenGB() {
        XCTAssertEqual(LocalAIModelPolicy.recommendedModel(memoryGiB: 16), "qwen3.5:4b")
        XCTAssertTrue(LocalAIModelPolicy.recommendationText(memoryGiB: 16).contains("视频通话"))
    }

    func testLocalAIModelPolicyUsesNineBWhenMemoryHasMoreHeadroom() {
        XCTAssertEqual(LocalAIModelPolicy.recommendedModel(memoryGiB: 24), "qwen3.5:9b")
    }

    @MainActor
    func testConsultationArchiveRequiresConsentDeliveryTranscriptAndApprovedSummary() throws {
        let appointmentID = UUID()
        let clientID = UUID()
        let record = ConsultationRecord(
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: "C-WORKFLOW",
            clientNameSnapshot: "归档测试",
            serviceName: "测试咨询"
        )
        let consents = [ConsentType.recording, .photo, .localAI, .longTermRetention].map {
            ConsentRecord(
                clientID: clientID,
                appointmentID: appointmentID,
                type: $0,
                textVersion: "TEST",
                textSnapshot: "测试同意",
                accepted: true
            )
        }
        let audio = MediaAsset(
            sessionID: record.id,
            clientID: clientID,
            kind: .audio,
            originalFilename: "test.m4a",
            relativePath: "test/test.m4a",
            fileSize: 100,
            sha256: "abc"
        )

        var result = ConsultationWorkflowService.assessment(
            record: record,
            assets: [audio],
            consents: consents
        )
        XCTAssertTrue(result.missingItems.contains("文字转写"))
        XCTAssertTrue(result.missingItems.contains("录音已交付客户"))
        XCTAssertFalse(result.canArchive)

        record.transcriptText = "仅用于测试的文字转写"
        record.formalSummary = "人工核对后的正式摘要"
        record.formalSummaryVersion = 1
        record.approvedAt = .now
        record.recordingDeliveredAt = .now
        result = ConsultationWorkflowService.assessment(
            record: record,
            assets: [audio],
            consents: consents
        )
        XCTAssertEqual(result.status, .review)
        XCTAssertTrue(result.canArchive)
        XCTAssertNoThrow(try ConsultationWorkflowService.validateArchive(
            record: record,
            assets: [audio],
            consents: consents
        ))
    }

    @MainActor
    func testConsultationImportAndAIRequireSeparateConsents() {
        let appointmentID = UUID()
        let clientID = UUID()
        let record = ConsultationRecord(
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: "C-CONSENT",
            clientNameSnapshot: "同意测试",
            serviceName: "测试咨询"
        )
        let retention = ConsentRecord(
            clientID: clientID,
            appointmentID: appointmentID,
            type: .longTermRetention,
            textVersion: "TEST",
            textSnapshot: "长期保存测试同意",
            accepted: true
        )

        XCTAssertThrowsError(try ConsultationWorkflowService.validateImport(
            kind: .audio,
            record: record,
            consents: [retention]
        )) { error in
            XCTAssertEqual(error as? ConsultationWorkflowError, .missingRecordingConsent)
        }
        XCTAssertThrowsError(try ConsultationWorkflowService.validateImport(
            kind: .image,
            record: record,
            consents: [retention]
        )) { error in
            XCTAssertEqual(error as? ConsultationWorkflowError, .missingPhotoConsent)
        }
        XCTAssertThrowsError(try ConsultationWorkflowService.validateLocalAI(
            record: record,
            consents: [retention]
        )) { error in
            XCTAssertEqual(error as? ConsultationWorkflowError, .missingLocalAIConsent)
        }
    }

    func testLocalTranscriptionMergeNeverErasesExistingText() {
        XCTAssertEqual(
            ConsultationWorkflowService.mergedTranscript(existing: "", generated: "新的转写"),
            "新的转写"
        )
        XCTAssertEqual(
            ConsultationWorkflowService.mergedTranscript(existing: "人工备注", generated: "新的转写"),
            "人工备注\n\n--- 本机录音转写 ---\n新的转写"
        )
        XCTAssertEqual(
            ConsultationWorkflowService.mergedTranscript(existing: "人工备注", generated: "  "),
            "人工备注"
        )
    }

    @MainActor
    func testAppStateMigratesLegacyFallbackToHardwareRecommendation() throws {
        let suiteName = "SoulTowerTests.ModelPolicy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(LocalAIModelPolicy.fallbackModel, forKey: "aiModelName")

        let state = AppState(defaults: defaults)

        XCTAssertEqual(state.aiModelName, LocalAIModelPolicy.recommendedModel)
        XCTAssertEqual(defaults.string(forKey: "aiModelName"), LocalAIModelPolicy.recommendedModel)
    }

    func testConsultationHoursAcceptMorningAndEvening() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12)))
        let morningStart = try XCTUnwrap(calendar.date(byAdding: .hour, value: 10, to: day))
        let morningEnd = try XCTUnwrap(calendar.date(byAdding: .minute, value: 40, to: morningStart))
        let eveningStart = try XCTUnwrap(calendar.date(byAdding: .hour, value: 16, to: day))
        let eveningEnd = try XCTUnwrap(calendar.date(byAdding: .minute, value: 90, to: eveningStart))

        XCTAssertTrue(DefaultBusinessRules.isWithinConsultationHours(start: morningStart, end: morningEnd))
        XCTAssertTrue(DefaultBusinessRules.isWithinConsultationHours(start: eveningStart, end: eveningEnd))
    }

    func testConsultationHoursRejectNoonGap() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12)))
        let start = try XCTUnwrap(calendar.date(byAdding: .hour, value: 13, to: day))
        let end = try XCTUnwrap(calendar.date(byAdding: .minute, value: 40, to: start))
        XCTAssertFalse(DefaultBusinessRules.isWithinConsultationHours(start: start, end: end))
    }

    func testAdultBoundary() throws {
        let calendar = Calendar(identifier: .gregorian)
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12)))
        let exactlyEighteen = try XCTUnwrap(calendar.date(from: DateComponents(year: 2008, month: 8, day: 12)))
        let underEighteen = try XCTUnwrap(calendar.date(from: DateComponents(year: 2008, month: 8, day: 13)))
        XCTAssertTrue(DefaultBusinessRules.isAdult(birthDate: exactlyEighteen, reference: reference))
        XCTAssertFalse(DefaultBusinessRules.isAdult(birthDate: underEighteen, reference: reference))
    }

    func testAppointmentConflictIncludesFifteenMinuteBuffer() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 16)))
        let existing = Appointment(
            clientID: UUID(),
            clientCode: "C-0001",
            clientNameSnapshot: "测试客户",
            serviceID: UUID(),
            serviceNameSnapshot: "测试服务",
            startAt: day,
            endAt: day.addingTimeInterval(60 * 60),
            priceCents: 66_600,
            policyVersion: "TEST"
        )

        XCTAssertTrue(DefaultBusinessRules.hasConflict(
            start: day.addingTimeInterval(65 * 60),
            end: day.addingTimeInterval(95 * 60),
            appointments: [existing]
        ))
        XCTAssertFalse(DefaultBusinessRules.hasConflict(
            start: day.addingTimeInterval(75 * 60),
            end: day.addingTimeInterval(105 * 60),
            appointments: [existing]
        ))
    }

    func testScheduleSyncPackageDoesNotContainNameOrPrice() throws {
        let appointment = Appointment(
            clientID: UUID(),
            clientCode: "C-0099",
            clientNameSnapshot: "不应导出的真实姓名",
            serviceID: UUID(),
            serviceNameSnapshot: "不应导出的咨询主题",
            startAt: .now,
            endAt: .now.addingTimeInterval(60 * 60),
            priceCents: 999_999,
            policyVersion: "TEST"
        )
        let data = try JSONEncoder().encode(ScheduleSyncPackage(appointments: [appointment]))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("不应导出的真实姓名"))
        XCTAssertFalse(text.contains("不应导出的咨询主题"))
        XCTAssertFalse(text.contains("999999"))
        XCTAssertTrue(text.contains("C-0099"))
    }

    func testPasswordCryptoRoundTripAndWrongPassword() throws {
        let salt = Data(repeating: 7, count: 16)
        let correct = try PasswordCrypto.deriveKey(password: "正确密码123", salt: salt, iterations: 100_000)
        let wrong = try PasswordCrypto.deriveKey(password: "错误密码123", salt: salt, iterations: 100_000)
        let source = Data("只保存在本机的测试内容".utf8)
        let encrypted = try PasswordCrypto.seal(source, keyData: correct)

        XCTAssertEqual(try PasswordCrypto.open(encrypted, keyData: correct), source)
        XCTAssertThrowsError(try PasswordCrypto.open(encrypted, keyData: wrong))
    }

    @MainActor
    func testMigrationBackfillsEmptyConsentSnapshot() throws {
        let schema = Schema([Client.self, ServiceItem.self, Appointment.self, ConsentRecord.self, ConsultationRecord.self, MediaAsset.self, PaymentTransaction.self, ServiceOrder.self, OrderPaymentTransaction.self, EntitlementRedemption.self, ServiceOrderChange.self, ConsultationActivity.self, ConsultationSummaryRevision.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let clientID = UUID()
        let consent = ConsentRecord(
            clientID: clientID,
            type: .recording,
            textVersion: "TEST",
            textSnapshot: "",
            accepted: true
        )
        container.mainContext.insert(consent)
        try container.mainContext.save()

        try AppMigrationService.backfillConsentSnapshots(context: container.mainContext)

        XCTAssertEqual(consent.textSnapshot, DefaultBusinessRules.recordingConsentNotice)
    }

    @MainActor
    func testV07MigrationPreservesLegacyFormalSummaryAsVersionOne() throws {
        let schema = Schema([Client.self, ServiceItem.self, Appointment.self, ConsentRecord.self, ConsultationRecord.self, MediaAsset.self, PaymentTransaction.self, ServiceOrder.self, OrderPaymentTransaction.self, EntitlementRedemption.self, ServiceOrderChange.self, ConsultationActivity.self, ConsultationSummaryRevision.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let record = ConsultationRecord(
            clientID: UUID(),
            clientCode: "C-V07-MIGRATION",
            clientNameSnapshot: "迁移测试",
            serviceName: "测试服务",
            transcriptText: "旧版转写",
            formalSummary: "旧版已经批准的正式摘要",
            aiStatus: .approved,
            approvedAt: .now
        )
        container.mainContext.insert(record)
        try container.mainContext.save()

        try AppMigrationService.backfillConsultationArchiveHistory(context: container.mainContext)

        let revisions = try container.mainContext.fetch(FetchDescriptor<ConsultationSummaryRevision>())
        let activities = try container.mainContext.fetch(FetchDescriptor<ConsultationActivity>())
        XCTAssertEqual(record.formalSummaryVersion, 1)
        XCTAssertEqual(revisions.first?.content, "旧版已经批准的正式摘要")
        XCTAssertEqual(revisions.first?.version, 1)
        XCTAssertEqual(activities.first?.kind, .recordCreated)
    }

    @MainActor
    func testPaymentMigrationBackfillsLegacyPaidAppointmentOnlyOnce() throws {
        let schema = Schema([Client.self, ServiceItem.self, Appointment.self, ConsentRecord.self, ConsultationRecord.self, MediaAsset.self, PaymentTransaction.self, ServiceOrder.self, OrderPaymentTransaction.self, EntitlementRedemption.self, ServiceOrderChange.self, ConsultationActivity.self, ConsultationSummaryRevision.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let appointment = Appointment(
            clientID: UUID(),
            clientCode: "C-MIGRATION",
            clientNameSnapshot: "迁移测试",
            serviceID: UUID(),
            serviceNameSnapshot: "测试服务",
            startAt: .now,
            endAt: .now.addingTimeInterval(3_600),
            status: .completed,
            paymentStatus: .paid,
            priceCents: 66_600,
            policyVersion: "TEST"
        )
        container.mainContext.insert(appointment)
        try container.mainContext.save()

        try AppMigrationService.backfillLegacyPaymentTransactions(context: container.mainContext)
        try AppMigrationService.backfillLegacyPaymentTransactions(context: container.mainContext)

        let transactions = try container.mainContext.fetch(FetchDescriptor<PaymentTransaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.amountCents, 66_600)
        XCTAssertEqual(transactions.first?.method, .legacy)
    }

    func testEncryptedBackupCanBeValidated() async throws {
        let client = Client(clientCode: "C-TEST", displayName: "加密备份测试")
        let payment = PaymentTransaction(
            appointmentID: UUID(),
            clientID: client.id,
            clientCode: client.clientCode,
            serviceNameSnapshot: "测试服务",
            kind: .servicePayment,
            method: .wechat,
            amountCents: 66_600
        )
        let order = ServiceOrder(
            clientID: client.id, clientCode: client.clientCode, clientNameSnapshot: client.displayName,
            serviceID: UUID(), serviceNameSnapshot: "季度套餐", categorySnapshot: "周期疗愈套餐",
            deliveryType: .video, pricingMode: .fixed, totalPriceCents: 399_900,
            includedSessions: 4, status: .active, paymentStatus: .paid, policyVersion: "TEST"
        )
        let orderPayment = OrderPaymentTransaction(
            orderID: order.id, clientID: client.id, clientCode: client.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot, kind: .servicePayment,
            method: .wechat, amountCents: 399_900
        )
        let redemption = EntitlementRedemption(
            orderID: order.id, appointmentID: UUID(), clientID: client.id,
            clientCode: client.clientCode, serviceNameSnapshot: order.serviceNameSnapshot
        )
        redemption.reversedAt = .now
        redemption.reversalReason = "备份返还测试"
        let orderChange = ServiceOrderChange(
            orderID: order.id, clientID: client.id, clientCode: client.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot,
            kind: .entitlementReturned, title: "预约取消返还 1 次",
            beforeValue: "剩余 2 次", afterValue: "剩余 3 次", reason: "备份变更测试"
        )
        let record = ConsultationRecord(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceName: "测试咨询",
            transcriptText: "备份转写测试",
            summaryDraft: "备份摘要草稿",
            formalSummary: "备份正式摘要",
            aiStatus: .approved,
            aiModelName: "qwen3.5:4b",
            approvedAt: .now,
            transcriptSource: .onDeviceAudio,
            transcriptUpdatedAt: .now,
            formalSummaryVersion: 2,
            recordingDeliveredAt: .now,
            archivedAt: .now
        )
        let activity = ConsultationWorkflowService.activity(
            record: record,
            kind: .archived,
            title: "备份归档测试"
        )
        let revision = ConsultationSummaryRevision(
            recordID: record.id,
            clientID: client.id,
            version: 2,
            content: record.formalSummary,
            aiModelName: record.aiModelName
        )
        let snapshot = BackupSnapshot(
            formatVersion: BackupSnapshot.formatVersion,
            createdAt: .now,
            appVersion: "TEST",
            clients: [BackupClient(client)],
            services: [],
            appointments: [],
            consents: [],
            records: [BackupConsultation(record)],
            mediaAssets: [],
            payments: [BackupPaymentTransaction(payment)],
            serviceOrders: [BackupServiceOrder(order)],
            orderPayments: [BackupOrderPaymentTransaction(orderPayment)],
            entitlementRedemptions: [BackupEntitlementRedemption(redemption)],
            serviceOrderChanges: [BackupServiceOrderChange(orderChange)],
            consultationActivities: [BackupConsultationActivity(activity)],
            consultationSummaryRevisions: [BackupConsultationSummaryRevision(revision)],
            mediaFiles: []
        )
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SoulTowerBackupTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let package = try await BackupService.createBackup(snapshot: snapshot, password: "backup-pass-123", destinationFolder: folder)
        let restored = try await BackupService.validateBackup(at: package, password: "backup-pass-123")

        XCTAssertEqual(restored.clients.count, 1)
        XCTAssertEqual(restored.clients.first?.clientCode, "C-TEST")
        XCTAssertEqual(restored.payments?.first?.amountCents, 66_600)
        XCTAssertEqual(restored.serviceOrders?.first?.includedSessions, 4)
        XCTAssertEqual(restored.orderPayments?.first?.amountCents, 399_900)
        XCTAssertEqual(restored.entitlementRedemptions?.count, 1)
        XCTAssertEqual(restored.entitlementRedemptions?.first?.reversalReason, "备份返还测试")
        XCTAssertEqual(restored.serviceOrderChanges?.first?.kindRaw, ServiceOrderChangeKind.entitlementReturned.rawValue)
        XCTAssertEqual(restored.records.first?.transcriptSourceRaw, TranscriptSource.onDeviceAudio.rawValue)
        XCTAssertEqual(restored.records.first?.formalSummaryVersion, 2)
        XCTAssertNotNil(restored.records.first?.archivedAt)
        XCTAssertEqual(restored.consultationActivities?.first?.title, "备份归档测试")
        XCTAssertEqual(restored.consultationSummaryRevisions?.first?.content, "备份正式摘要")
        do {
            _ = try await BackupService.validateBackup(at: package, password: "wrong-pass-123")
            XCTFail("错误密码不应通过验证")
        } catch {
            XCTAssertNotNil(error as? LocalizedError)
        }
    }

    func testEncryptedBackupPreservesChunkedMedia() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SoulTowerMediaBackupTest-\(UUID().uuidString)", isDirectory: true)
        let mediaRoot = folder.appendingPathComponent("SourceMedia", isDirectory: true)
        let destination = folder.appendingPathComponent("Backups", isDirectory: true)
        let relativePath = "client/session/sample.bin"
        let sourceURL = mediaRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let sourceData = Data(repeating: 0x5A, count: 4 * 1024 * 1024 + 123)
        try sourceData.write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: folder) }

        let asset = MediaAsset(
            sessionID: UUID(),
            clientID: UUID(),
            kind: .audio,
            originalFilename: "sample.bin",
            relativePath: relativePath,
            fileSize: Int64(sourceData.count)
        )
        let snapshot = BackupSnapshot(
            formatVersion: BackupSnapshot.formatVersion,
            createdAt: .now,
            appVersion: "TEST",
            clients: [],
            services: [],
            appointments: [],
            consents: [],
            records: [],
            mediaAssets: [BackupMediaAsset(asset)],
            mediaFiles: []
        )

        let package = try await BackupService.createBackup(
            snapshot: snapshot,
            password: "media-pass-123",
            destinationFolder: destination,
            mediaRoot: mediaRoot
        )
        let prepared = try await BackupService.prepareRestore(from: package, password: "media-pass-123")
        defer { try? FileManager.default.removeItem(at: prepared.stagedMediaRoot.deletingLastPathComponent()) }
        let restoredData = try Data(contentsOf: prepared.stagedMediaRoot.appendingPathComponent(relativePath))

        XCTAssertEqual(restoredData, sourceData)
        XCTAssertEqual(prepared.snapshot.mediaFiles.first?.chunkCount, 2)
    }

    func testV07BackupModelsDecodeV06CompatiblePayloadWithoutNewFields() throws {
        let record = ConsultationRecord(
            clientID: UUID(),
            clientCode: "C-LEGACY-BACKUP",
            clientNameSnapshot: "旧版备份",
            serviceName: "测试服务",
            transcriptText: "旧版转写"
        )
        let asset = MediaAsset(
            sessionID: record.id,
            clientID: record.clientID,
            kind: .transcript,
            originalFilename: "legacy.txt",
            relativePath: "legacy/legacy.txt",
            fileSize: 10
        )
        let snapshot = BackupSnapshot(
            formatVersion: BackupSnapshot.formatVersion,
            createdAt: .now,
            appVersion: "0.6.0",
            clients: [], services: [], appointments: [], consents: [],
            records: [BackupConsultation(record)],
            mediaAssets: [BackupMediaAsset(asset)],
            mediaFiles: []
        )
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "consultationActivities")
        object.removeValue(forKey: "consultationSummaryRevisions")
        var records = try XCTUnwrap(object["records"] as? [[String: Any]])
        records[0].removeValue(forKey: "transcriptSourceRaw")
        records[0].removeValue(forKey: "transcriptUpdatedAt")
        records[0].removeValue(forKey: "formalSummaryVersion")
        records[0].removeValue(forKey: "recordingDeliveredAt")
        records[0].removeValue(forKey: "archivedAt")
        object["records"] = records
        var assets = try XCTUnwrap(object["mediaAssets"] as? [[String: Any]])
        assets[0].removeValue(forKey: "sha256")
        object["mediaAssets"] = assets
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(BackupSnapshot.self, from: legacyData)
        XCTAssertNil(decoded.consultationActivities)
        XCTAssertNil(decoded.consultationSummaryRevisions)
        XCTAssertNil(decoded.records.first?.transcriptSourceRaw)
        XCTAssertNil(decoded.mediaAssets.first?.sha256)
        XCTAssertEqual(decoded.records.first?.model().transcriptSource, .manual)
    }

    func testVoiceIntakeParsesStructuredAIResponseWithoutInventingConsent() throws {
        let response = """
        ```json
        {
          "displayName": "小林",
          "wechatNickname": "林林",
          "phone": null,
          "source": "朋友介绍",
          "birthDate": "1993-05-18",
          "serviceName": "新客塔罗心理咨询",
          "appointmentStart": "2026-08-20 16:00",
          "videoDevice": "Mac",
          "paymentStatus": "已付款",
          "policyAccepted": true,
          "recordingAccepted": false,
          "photoAccepted": null,
          "localAIAccepted": "同意",
          "retentionAccepted": "不同意",
          "archiveSummary": "第一次咨询，想梳理关系压力。",
          "missingFields": ["是否同意牌阵照片"]
        }
        ```
        """

        let draft = try VoiceIntakeDraft.parseAIResponse(response)

        XCTAssertEqual(draft.displayName, "小林")
        XCTAssertEqual(draft.videoDevice, .mac)
        XCTAssertEqual(draft.paymentStatus, .paid)
        XCTAssertEqual(draft.policyConsent, .accepted)
        XCTAssertEqual(draft.recordingConsent, .declined)
        XCTAssertEqual(draft.photoConsent, .unknown)
        XCTAssertEqual(draft.localAIConsent, .accepted)
        XCTAssertEqual(draft.retentionConsent, .declined)
        XCTAssertEqual(draft.modelReportedMissingFields, ["是否同意牌阵照片"])
    }

    func testVoiceIntakeDateParserUsesExplicitLocalFormats() throws {
        XCTAssertNotNil(VoiceIntakeDateParser.birthDate("1993-05-18"))
        XCTAssertNotNil(VoiceIntakeDateParser.appointmentStart("2026-08-20 16:00"))
        XCTAssertNil(VoiceIntakeDateParser.appointmentStart("明天下午四点"))
    }

    func testVoiceIntakeGroundingRejectsHallucinationsAndUsesExplicitStatements() throws {
        let transcript = "新客户称呼小林，微信昵称林林，阳历出生日期1993年5月18日，来源朋友介绍。预约新客塔罗心理咨询，2026年8月20日下午4点，使用Mac视频，已经付款。已同意服务规则；同意录音；不同意拍照；同意本地AI；同意长期保存。备注第一次咨询，想梳理关系压力。"
        var aiDraft = VoiceIntakeDraft()
        aiDraft.displayName = "林林"
        aiDraft.wechatNickname = "林林"
        aiDraft.phone = "13800000000"
        aiDraft.source = "朋友介绍"
        aiDraft.birthDateText = "1993-05-18"
        aiDraft.serviceName = "新客塔罗心理咨询"
        aiDraft.appointmentStartText = "2026-08-20 14:00"
        aiDraft.videoDevice = .iPhone
        aiDraft.paymentStatus = nil
        aiDraft.policyConsent = .unknown
        aiDraft.recordingConsent = .unknown
        aiDraft.photoConsent = .unknown
        aiDraft.localAIConsent = .unknown
        aiDraft.retentionConsent = .unknown

        let grounded = VoiceIntakeGroundingService.ground(aiDraft, transcript: transcript)

        XCTAssertEqual(grounded.displayName, "小林")
        XCTAssertEqual(grounded.wechatNickname, "林林")
        XCTAssertEqual(grounded.phone, "")
        XCTAssertEqual(grounded.birthDateText, "1993-05-18")
        XCTAssertEqual(grounded.appointmentStartText, "2026-08-20 16:00")
        XCTAssertEqual(grounded.videoDevice, .mac)
        XCTAssertEqual(grounded.paymentStatus, .paid)
        XCTAssertEqual(grounded.policyConsent, .accepted)
        XCTAssertEqual(grounded.recordingConsent, .accepted)
        XCTAssertEqual(grounded.photoConsent, .declined)
        XCTAssertEqual(grounded.localAIConsent, .accepted)
        XCTAssertEqual(grounded.retentionConsent, .accepted)
    }
}
