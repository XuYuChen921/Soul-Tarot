import SwiftData
import SwiftUI

struct ServiceOrderDetailView: View {
    @Environment(\.modelContext) private var context
    let order: ServiceOrder
    @Query private var transactions: [OrderPaymentTransaction]
    @Query private var redemptions: [EntitlementRedemption]
    @Query private var changes: [ServiceOrderChange]
    @State private var showingPaymentEditor = false
    @State private var showingExtensionEditor = false
    @State private var showingChangeEditor = false
    @State private var message = ""

    init(order: ServiceOrder) {
        self.order = order
        let orderID = order.id
        _transactions = Query(
            filter: #Predicate<OrderPaymentTransaction> { $0.orderID == orderID },
            sort: \OrderPaymentTransaction.occurredAt,
            order: .reverse
        )
        _redemptions = Query(
            filter: #Predicate<EntitlementRedemption> { $0.orderID == orderID },
            sort: \EntitlementRedemption.redeemedAt,
            order: .reverse
        )
        _changes = Query(
            filter: #Predicate<ServiceOrderChange> { $0.orderID == orderID },
            sort: \ServiceOrderChange.occurredAt,
            order: .reverse
        )
    }

    var body: some View {
        Form {
            Section("订单") {
                LabeledContent("客户", value: "\(order.clientCode) · \(order.clientNameSnapshot)")
                LabeledContent("服务", value: order.serviceNameSnapshot)
                LabeledContent("产品类型", value: order.productKind.rawValue)
                LabeledContent("订单总价", value: order.totalPriceCents.yuanText)
                LabeledContent("付款状态", value: order.paymentStatus.rawValue)
                LabeledContent("订单状态", value: effectiveStatus.rawValue)
                LabeledContent("建立时间", value: order.placedAt.formatted(date: .abbreviated, time: .shortened))
                if let expiresAt = order.expiresAt {
                    LabeledContent("有效期至", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                }
                if order.unitQuantityHundredths != 100 || !order.unitLabel.isEmpty {
                    LabeledContent("约定数量", value: quantityText)
                }
                if !order.guardianName.isEmpty {
                    LabeledContent("提起监护人", value: order.guardianName)
                    LabeledContent("服务对象", value: order.subjectName)
                }
            }

            if order.productKind == .package {
                Section("套餐权益") {
                    LabeledContent("总次数", value: "\(order.includedSessions) 次")
                    LabeledContent("预约占用", value: "\(reservedSessions) 次")
                    LabeledContent("咨询后核销", value: "\(consumedSessions) 次")
                    LabeledContent("仍可预约", value: "\(remainingSessions) 次")
                    if redemptions.isEmpty {
                        Text("创建预约时先占用 1 次；咨询完成并建立资料后才正式核销。取消预约可按双方确认决定是否返还。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(redemptions) { redemption in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened))
                                    Text(redemption.note).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(redemption.isReversed ? "+1 已返还" : redemption.state.rawValue)
                                    .foregroundStyle(redemption.isReversed ? .green : (redemption.state == .consumed ? BrandTheme.teal : .orange))
                            }
                            if let reversedAt = redemption.reversedAt {
                                Text("返还于 \(reversedAt.formatted(date: .abbreviated, time: .shortened))：\(redemption.reversalReason ?? "预约取消")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("人工延长套餐有效期") { showingExtensionEditor = true }
                        .disabled(order.expiresAt == nil || order.status == .cancelled || hasUsedExtension)
                    if hasUsedExtension {
                        Text("该套餐已使用过 1 次人工延期；历史记录保留在下方，不能再次延期。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("订单收付款") {
                LabeledContent("已覆盖订单金额", value: paymentSummary.coveredOrderCents.yuanText)
                LabeledContent("仍待收", value: remainingPaymentCents.yuanText)
                LabeledContent("现金净实收", value: paymentSummary.netCashCents.yuanText)
                ForEach(transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(transaction.kind.rawValue).font(.subheadline.weight(.semibold))
                            Text("\(transaction.method.rawValue) · \(transaction.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(transaction.displayAmountCents.yuanText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(transaction.kind == .refund ? .red : .primary)
                    }
                }
                Button("记录订单收款或退款") { showingPaymentEditor = true }
            }

            Section(order.productKind == .project ? "项目进度" : "订单处理") {
                if order.productKind == .project && order.status != .completed && order.status != .cancelled {
                    Picker("当前阶段", selection: Binding(
                        get: { order.projectStage },
                        set: { updateProjectStage($0) }
                    )) {
                        ForEach(ProjectStage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text("项目阶段与付款状态分别记录；选择“已归档”后订单才正式完成。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if order.status != .cancelled && order.status != .completed {
                    Button("取消订单", role: .destructive) { cancelOrder() }
                }
                if !order.notes.isEmpty { Text(order.notes).foregroundStyle(.secondary) }
            }

            Section("订单变更记录") {
                Button("记录一项人工变更") { showingChangeEditor = true }
                if changes.isEmpty {
                    Text("暂无变更。延期、次数返还和订单状态变化会自动留痕。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(changes) { change in
                        DisclosureGroup {
                            if !change.beforeValue.isEmpty || !change.afterValue.isEmpty {
                                LabeledContent("变更前", value: change.beforeValue.isEmpty ? "未记录" : change.beforeValue)
                                LabeledContent("变更后", value: change.afterValue.isEmpty ? "未记录" : change.afterValue)
                            }
                            Text(change.reason).foregroundStyle(.secondary)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(change.title)
                                Text("\(change.kind.rawValue) · \(change.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if !message.isEmpty { Section { Text(message).foregroundStyle(.secondary) } }
        }
        .formStyle(.grouped)
        .navigationTitle(order.clientCode)
        .sheet(isPresented: $showingPaymentEditor) {
            OrderPaymentEditorView(order: order)
        }
        .sheet(isPresented: $showingExtensionEditor) {
            PackageExtensionEditorView(order: order)
        }
        .sheet(isPresented: $showingChangeEditor) {
            ServiceOrderChangeEditorView(order: order)
        }
        .onAppear { refreshExpiration() }
    }

    private var paymentSummary: OrderPaymentSummary {
        OrderPaymentLedgerService.summary(transactions: transactions, orderPriceCents: order.totalPriceCents)
    }

    private var remainingPaymentCents: Int {
        OrderPaymentLedgerService.remainingCents(transactions: transactions, orderPriceCents: order.totalPriceCents)
    }

    private var remainingSessions: Int {
        EntitlementService.remainingSessions(order: order, redemptions: redemptions)
    }

    private var reservedSessions: Int {
        EntitlementService.reservedSessions(orderID: order.id, redemptions: redemptions)
    }

    private var consumedSessions: Int {
        EntitlementService.consumedSessions(orderID: order.id, redemptions: redemptions)
    }

    private var hasUsedExtension: Bool {
        changes.contains { $0.kind == .expirationExtended }
    }

    private var effectiveStatus: ServiceOrderStatus {
        if order.status != .completed && order.status != .cancelled,
           let expiresAt = order.expiresAt, expiresAt < .now { return .expired }
        return order.status
    }

    private var quantityText: String {
        let value = NSDecimalNumber(value: order.unitQuantityHundredths).dividing(by: 100).stringValue
        return order.unitLabel.isEmpty ? value : "\(value) \(order.unitLabel)"
    }

    private func updateProjectStage(_ stage: ProjectStage) {
        let previous = order.projectStage
        guard previous != stage else { return }
        order.projectStage = stage
        if stage == .archived { order.status = .completed }
        order.updatedAt = .now
        context.insert(ServiceOrderChangeService.audit(
            order: order, kind: .statusChanged, title: "项目阶段更新",
            beforeValue: previous.rawValue, afterValue: stage.rawValue,
            reason: "咨询师人工确认项目进度"
        ))
        do {
            try context.save()
            message = "项目阶段已更新为“\(stage.rawValue)”"
        } catch {
            context.rollback()
            message = "项目阶段保存失败：\(error.localizedDescription)"
        }
    }

    private func cancelOrder() {
        let previous = order.status.rawValue
        order.status = .cancelled
        order.updatedAt = .now
        context.insert(ServiceOrderChangeService.audit(
            order: order, kind: .statusChanged, title: "订单取消",
            beforeValue: previous, afterValue: order.status.rawValue,
            reason: "咨询师人工取消订单，历史付款与变更记录保留"
        ))
        try? context.save()
        message = "订单已取消，历史付款记录仍保留"
    }

    private func refreshExpiration() {
        guard order.status != .completed && order.status != .cancelled,
              let expiresAt = order.expiresAt, expiresAt < .now,
              order.status != .expired else { return }
        let previous = order.status.rawValue
        order.status = .expired
        order.updatedAt = .now
        context.insert(ServiceOrderChangeService.audit(
            order: order, kind: .statusChanged, title: "套餐到期",
            beforeValue: previous, afterValue: order.status.rawValue,
            reason: "系统按订单有效期自动更新"
        ))
        try? context.save()
    }
}

struct PackageExtensionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let order: ServiceOrder
    @Query private var changes: [ServiceOrderChange]
    @State private var newExpiration: Date
    @State private var reason = "双方协商延期"
    @State private var errorMessage = ""

    private static var minimumExpiration: Date {
        Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: .now)
        ) ?? .now.addingTimeInterval(86_400)
    }

    init(order: ServiceOrder) {
        self.order = order
        let orderID = order.id
        _changes = Query(filter: #Predicate<ServiceOrderChange> { $0.orderID == orderID })
        let base = order.expiresAt ?? .now
        let proposed = Calendar.current.date(byAdding: .day, value: 30, to: base)
            ?? base.addingTimeInterval(2_592_000)
        _newExpiration = State(initialValue: max(proposed, Self.minimumExpiration))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("当前套餐") {
                    LabeledContent("客户", value: order.clientCode)
                    LabeledContent("套餐", value: order.serviceNameSnapshot)
                    LabeledContent("当前有效期", value: order.expiresAt?.formatted(date: .abbreviated, time: .omitted) ?? "未设置")
                }
                Section("延期信息") {
                    DatePicker(
                        "新的有效期",
                        selection: $newExpiration,
                        in: Self.minimumExpiration...,
                        displayedComponents: .date
                    )
                    TextField("延期原因（必填）", text: $reason, axis: .vertical)
                    Text("每个套餐只允许人工延期 1 次、最多 30 天。保存后会恢复仍有剩余次数且已经付清的到期套餐，并永久保留延期前后日期。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("套餐延期")
            .compactNavigationTitleOnPhone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认延期") { save() } }
            }
        }
        .adaptiveEditorSheet(macWidth: 440, macHeight: 430)
    }

    private func save() {
        do {
            let change = try ServiceOrderChangeService.extendPackage(
                order: order,
                newExpiration: newExpiration,
                reason: reason,
                existingChanges: changes
            )
            context.insert(change)
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct ServiceOrderChangeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let order: ServiceOrder
    @State private var kind: ServiceOrderChangeKind = .scopeChanged
    @State private var beforeValue = ""
    @State private var afterValue = ""
    @State private var reason = ""
    @State private var errorMessage = ""

    private let availableKinds: [ServiceOrderChangeKind] = [
        .scopeChanged, .scheduleChanged, .priceChanged, .subjectChanged, .other
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("变更内容") {
                    Picker("类型", selection: $kind) {
                        ForEach(availableKinds) { Text($0.rawValue).tag($0) }
                    }
                    TextField("变更前", text: $beforeValue, axis: .vertical)
                    TextField("变更后", text: $afterValue, axis: .vertical)
                    TextField("变更原因或双方约定（必填）", text: $reason, axis: .vertical)
                }
                Section {
                    Text("这里记录约定变化，不会自动改写原订单价格、服务对象或付款流水。涉及费用时还需要另行记录收付款。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("记录订单变更")
            .compactNavigationTitleOnPhone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存记录") { save() } }
            }
        }
        .adaptiveEditorSheet(macWidth: 460, macHeight: 470)
    }

    private func save() {
        let cleanedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedReason.isEmpty else {
            errorMessage = ServiceOrderChangeError.reasonRequired.localizedDescription
            return
        }
        context.insert(ServiceOrderChangeService.audit(
            order: order, kind: kind, title: kind.rawValue,
            beforeValue: beforeValue.trimmingCharacters(in: .whitespacesAndNewlines),
            afterValue: afterValue.trimmingCharacters(in: .whitespacesAndNewlines),
            reason: cleanedReason
        ))
        order.updatedAt = .now
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct OrderPaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let order: ServiceOrder
    @Query private var transactions: [OrderPaymentTransaction]
    @State private var kind: PaymentTransactionKind = .servicePayment
    @State private var method: PaymentMethod = .wechat
    @State private var amountText = ""
    @State private var occurredAt = Date.now
    @State private var note = ""
    @State private var errorMessage = ""

    init(order: ServiceOrder) {
        self.order = order
        let orderID = order.id
        _transactions = Query(filter: #Predicate<OrderPaymentTransaction> { $0.orderID == orderID })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("本次流水") {
                    Picker("类型", selection: $kind) {
                        ForEach([PaymentTransactionKind.servicePayment, .refund, .balanceOffset]) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    Picker("方式", selection: $method) {
                        ForEach(availableMethods) { item in Text(item.rawValue).tag(item) }
                    }
                    TextField("金额（元）", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    DatePicker("发生时间", selection: $occurredAt)
                    TextField("备注（可不填）", text: $note, axis: .vertical)
                }
                Section("当前订单") {
                    LabeledContent("订单总价", value: order.totalPriceCents.yuanText)
                    LabeledContent("仍待收", value: remainingCents.yuanText)
                    LabeledContent("现金净实收", value: summary.netCashCents.yuanText)
                }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("记录订单流水")
            .compactNavigationTitleOnPhone()
            .onAppear { fillSuggestedAmount() }
            .onChange(of: kind) {
                method = kind == .balanceOffset ? .balance : .wechat
                fillSuggestedAmount()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存流水") { save() } }
            }
        }
        .adaptiveEditorSheet(macWidth: 430, macHeight: 500)
    }

    private var availableMethods: [PaymentMethod] {
        kind == .balanceOffset ? [.balance] : [.wechat, .bankTransfer, .cash, .other]
    }

    private var summary: OrderPaymentSummary {
        OrderPaymentLedgerService.summary(transactions: transactions, orderPriceCents: order.totalPriceCents)
    }

    private var remainingCents: Int {
        OrderPaymentLedgerService.remainingCents(transactions: transactions, orderPriceCents: order.totalPriceCents)
    }

    private func fillSuggestedAmount() {
        let cents = kind == .refund ? max(0, summary.netCashCents) : remainingCents
        amountText = cents > 0 ? NSDecimalNumber(value: cents).dividing(by: 100).stringValue : ""
        errorMessage = ""
    }

    private func save() {
        guard let amount = PaymentLedgerService.yuanTextToCents(amountText) else {
            errorMessage = PaymentLedgerError.invalidAmount.localizedDescription; return
        }
        do {
            try OrderPaymentLedgerService.validate(
                kind: kind,
                amountCents: amount,
                transactions: transactions,
                orderPriceCents: order.totalPriceCents
            )
            let transaction = OrderPaymentTransaction(
                orderID: order.id,
                clientID: order.clientID,
                clientCode: order.clientCode,
                serviceNameSnapshot: order.serviceNameSnapshot,
                kind: kind,
                method: kind == .balanceOffset ? .balance : method,
                amountCents: amount,
                occurredAt: occurredAt,
                note: note
            )
            context.insert(transaction)
            OrderPaymentLedgerService.refreshOrderStatus(order, transactions: transactions + [transaction])
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
