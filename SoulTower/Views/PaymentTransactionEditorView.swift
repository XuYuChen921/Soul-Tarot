import SwiftData
import SwiftUI

struct PaymentTransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let appointment: Appointment
    @Query private var transactions: [PaymentTransaction]

    @State private var kind: PaymentTransactionKind = .servicePayment
    @State private var method: PaymentMethod = .wechat
    @State private var amountText = ""
    @State private var occurredAt = Date.now
    @State private var note = ""
    @State private var errorMessage = ""

    init(appointment: Appointment) {
        self.appointment = appointment
        let appointmentID = appointment.id
        _transactions = Query(
            filter: #Predicate<PaymentTransaction> { $0.appointmentID == appointmentID },
            sort: \PaymentTransaction.occurredAt,
            order: .reverse
        )
    }

    private var suggestedAmountCents: Int {
        switch kind {
        case .servicePayment, .balanceOffset:
            return PaymentLedgerService.remainingServiceCents(
                transactions: transactions,
                appointmentPriceCents: appointment.priceCents
            )
        case .rushFee:
            return DefaultBusinessRules.expeditedFeeCents
        case .rescheduleFee:
            return DefaultBusinessRules.lateRescheduleFeeCents
        case .refund:
            return max(0, PaymentLedgerService.summary(
                transactions: transactions,
                appointmentPriceCents: appointment.priceCents
            ).netCashCents)
        case .otherIncome:
            return 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("本次流水") {
                    Picker("类型", selection: $kind) {
                        ForEach(availableKinds) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    Picker("方式", selection: $method) {
                        ForEach(availableMethods) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    TextField("金额（元）", text: $amountText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    DatePicker("发生时间", selection: $occurredAt)
                    TextField("备注（可不填）", text: $note, axis: .vertical)
                }

                Section("当前预约") {
                    LabeledContent("服务标价", value: appointment.priceCents.yuanText)
                    if appointment.serviceOrderID != nil {
                        LabeledContent("咨询费来源", value: "套餐权益核销")
                    } else {
                        LabeledContent("已覆盖咨询费", value: paymentSummary.coveredServiceCents.yuanText)
                        LabeledContent("仍待收咨询费", value: remainingCents.yuanText)
                    }
                    LabeledContent("现金净实收", value: paymentSummary.netCashCents.yuanText)
                    if paymentSummary.balanceOffsetCents > 0 {
                        LabeledContent("余额抵扣", value: paymentSummary.balanceOffsetCents.yuanText)
                    }
                }

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("记录收付款")
            .compactNavigationTitleOnPhone()
            .onAppear {
                if appointment.serviceOrderID != nil { kind = .rushFee }
                fillSuggestedAmount()
            }
            .onChange(of: kind) {
                if kind == .balanceOffset { method = .balance }
                else if method == .balance { method = .wechat }
                fillSuggestedAmount()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存流水") { save() }
                }
            }
        }
        .adaptiveEditorSheet(macWidth: 430, macHeight: 540)
    }

    private var availableMethods: [PaymentMethod] {
        if kind == .balanceOffset { return [.balance] }
        return [.wechat, .bankTransfer, .cash, .other]
    }

    private var availableKinds: [PaymentTransactionKind] {
        if appointment.serviceOrderID != nil {
            return [.rushFee, .rescheduleFee, .otherIncome, .refund]
        }
        return PaymentTransactionKind.allCases
    }

    private var paymentSummary: AppointmentPaymentSummary {
        PaymentLedgerService.summary(
            transactions: transactions,
            appointmentPriceCents: appointment.priceCents
        )
    }

    private var remainingCents: Int {
        PaymentLedgerService.remainingServiceCents(
            transactions: transactions,
            appointmentPriceCents: appointment.priceCents
        )
    }

    private func fillSuggestedAmount() {
        amountText = suggestedAmountCents > 0
            ? NSDecimalNumber(value: suggestedAmountCents).dividing(by: 100).stringValue
            : ""
        errorMessage = ""
    }

    private func save() {
        guard let amountCents = PaymentLedgerService.yuanTextToCents(amountText) else {
            errorMessage = PaymentLedgerError.invalidAmount.localizedDescription
            return
        }

        do {
            try PaymentLedgerService.validate(
                kind: kind,
                amountCents: amountCents,
                transactions: transactions,
                appointmentPriceCents: appointment.priceCents
            )
            let transaction = PaymentTransaction(
                appointmentID: appointment.id,
                clientID: appointment.clientID,
                clientCode: appointment.clientCode,
                serviceNameSnapshot: appointment.serviceNameSnapshot,
                kind: kind,
                method: kind == .balanceOffset ? .balance : method,
                amountCents: amountCents,
                occurredAt: occurredAt,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            context.insert(transaction)
            let projectedTransactions = transactions + [transaction]
            let wasConfirmed = appointment.status == .confirmed
            PaymentLedgerService.refreshAppointmentStatus(appointment, transactions: projectedTransactions)
            try context.save()

            if !wasConfirmed && appointment.status == .confirmed && appointment.startAt > .now {
                Task { @MainActor in
                    if (try? await NotificationScheduler.requestAuthorization()) == true,
                       let identifiers = try? await NotificationScheduler.schedule(for: appointment) {
                        appointment.reminder24Identifier = identifiers.0
                        appointment.reminder1Identifier = identifiers.1
                        try? context.save()
                    }
                }
            }
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
