import SwiftData
import SwiftUI

struct ServiceOrdersView: View {
    @Query(sort: \ServiceOrder.placedAt, order: .reverse) private var orders: [ServiceOrder]
    @Query private var redemptions: [EntitlementRedemption]
    @State private var showingEditor = false

    var body: some View {
        List {
            if orders.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "还没有客户订单",
                    message: "产品先在“产品与服务”中建立；客户实际购买后，才在这里创建订单。"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(orders) { order in
                    NavigationLink {
                        ServiceOrderDetailView(order: order)
                    } label: {
                        orderRow(order)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("客户订单")
        .toolbar {
            Button { showingEditor = true } label: {
                Label("新建客户订单", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingEditor) { ServiceOrderEditorView() }
    }

    private func orderRow(_ order: ServiceOrder) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon(for: order.productKind))
                .font(.title2)
                .foregroundStyle(order.productKind == .project ? BrandTheme.gold : BrandTheme.teal)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(order.clientCode) · \(order.serviceNameSnapshot)")
                    .font(.headline)
                if order.productKind == .package {
                    Text("可预约 \(EntitlementService.remainingSessions(order: order, redemptions: redemptions)) / \(order.includedSessions) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(order.productKind.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(order.totalPriceCents.yuanText).font(.headline.monospacedDigit())
                StatusBadge(text: order.status.rawValue, color: statusColor(order.status))
            }
        }
        .padding(.vertical, 5)
    }

    private func icon(for kind: ProductKind) -> String {
        switch kind {
        case .singleConsultation: return "person.wave.2"
        case .package: return "repeat.circle.fill"
        case .project: return "doc.text.fill"
        }
    }

    private func statusColor(_ status: ServiceOrderStatus) -> Color {
        switch status {
        case .active: return .green
        case .completed: return BrandTheme.teal
        case .pendingPayment: return .orange
        case .expired, .cancelled: return .red
        }
    }
}

private enum InitialOrderPayment: String, CaseIterable, Identifiable {
    case none = "暂不记录收款"
    case full = "全额到账"
    case partial = "部分到账"
    case balance = "余额抵扣"

    var id: String { rawValue }
}

struct ServiceOrderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Client.createdAt) private var clients: [Client]
    @Query(filter: #Predicate<ServiceItem> { $0.isActive }, sort: \ServiceItem.sortOrder) private var services: [ServiceItem]

    @State private var clientID: UUID?
    @State private var serviceID: UUID?
    @State private var agreedPriceText = ""
    @State private var quantityText = "1"
    @State private var initialPayment: InitialOrderPayment = .none
    @State private var paymentMethod: PaymentMethod = .wechat
    @State private var paidAmountText = ""
    @State private var policyAccepted = false
    @State private var guardianName = ""
    @State private var subjectName = ""
    @State private var notes = ""
    @State private var errorMessage = ""

    init(client: Client? = nil) {
        _clientID = State(initialValue: client?.id)
    }

    private var orderProducts: [ServiceItem] {
        services.filter { $0.productKind != .singleConsultation }
    }
    private var client: Client? { clients.first { $0.id == clientID } }
    private var service: ServiceItem? { orderProducts.first { $0.id == serviceID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("客户与产品") {
                    Picker("客户", selection: $clientID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(clients.filter { !$0.isArchived }) { item in
                            Text("\(item.clientCode) · \(item.displayName)").tag(Optional(item.id))
                        }
                    }
                    Picker("产品", selection: $serviceID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(orderProducts) { item in
                            Text("\(item.name) · \(item.productKind.rawValue)").tag(Optional(item.id))
                        }
                    }
                    if let service {
                        LabeledContent("产品类型", value: service.productKind.rawValue)
                        LabeledContent("目录价格", value: catalogPriceText(service))
                        if service.pricingMode == .perSquareMeter {
                            LabeledContent("数量（\(service.unitLabel)）") {
                                TextField(service.unitLabel, text: $quantityText)
                                    .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            }
                        }
                        LabeledContent("约定总价（元）") {
                            TextField("元", text: $agreedPriceText)
                                .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        }
                        if service.productKind == .package {
                            let validity = service.validDays > 0 ? "激活后 \(service.validDays) 天" : "不限期"
                            LabeledContent("套餐权益", value: "\(service.includedSessions) 次 · \(validity)")
                        }
                        Text("目录价格只用于带入默认值，订单保存的是双方实际约定价格。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if service?.requiresGuardian == true {
                    Section("监护人提起") {
                        TextField("监护人姓名", text: $guardianName)
                        TextField("服务对象姓名", text: $subjectName)
                        Text("这里只建立起名或改名项目订单，不创建未成年人心理成长咨询预约。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("建立订单时的收款（可选）") {
                    Picker("处理方式", selection: $initialPayment) {
                        ForEach(InitialOrderPayment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if initialPayment == .full || initialPayment == .partial {
                        Picker("收款方式", selection: $paymentMethod) {
                            ForEach([PaymentMethod.wechat, .bankTransfer, .cash, .other]) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                    }
                    if initialPayment == .partial {
                        TextField("本次实收金额（元）", text: $paidAmountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    }
                    Text("默认不记录收款。付款状态由实际收付款流水自动计算，不能手动指定。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("客户规则确认") {
                    Text(orderPolicyText)
                        .font(.footnote)
                    Toggle("客户已明确同意当前服务规则", isOn: $policyAccepted)
                }
                Section("内部备注") { TextField("备注", text: $notes, axis: .vertical) }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("新建客户订单")
            .compactNavigationTitleOnPhone()
            .onChange(of: serviceID) {
                fillPrice()
                initialPayment = .none
                paidAmountText = ""
            }
            .onChange(of: quantityText) {
                if service?.pricingMode == .perSquareMeter { fillPrice() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存订单") { save() } }
            }
        }
        .adaptiveEditorSheet(macWidth: 470, macHeight: 670)
    }

    private func catalogPriceText(_ service: ServiceItem) -> String {
        switch service.pricingMode {
        case .fixed: return service.priceCents.yuanText
        case .startingAt: return "\(service.priceCents.yuanText) 起"
        case .perSquareMeter: return "\(service.priceCents.yuanText)/\(service.unitLabel)"
        }
    }

    private func fillPrice() {
        guard let service else {
            agreedPriceText = ""
            return
        }
        let price: Int
        if service.pricingMode == .perSquareMeter,
           let quantity = Decimal(string: quantityText), quantity > 0 {
            price = NSDecimalNumber(decimal: quantity * Decimal(service.priceCents)).intValue
        } else {
            price = service.priceCents
        }
        agreedPriceText = NSDecimalNumber(value: price).dividing(by: 100).stringValue
    }

    private func save() {
        guard let client, let service else { errorMessage = "请选择客户和产品。"; return }
        guard policyAccepted else { errorMessage = "客户明确同意服务规则后才能建立订单。"; return }
        guard let totalPrice = PaymentLedgerService.yuanTextToCents(agreedPriceText) else {
            errorMessage = "请输入有效的订单总价。"; return
        }
        guard !service.requiresGuardian || (!guardianName.trimmingCharacters(in: .whitespaces).isEmpty && !subjectName.trimmingCharacters(in: .whitespaces).isEmpty) else {
            errorMessage = "该项目必须填写提起服务的监护人和服务对象。"; return
        }

        let quantityHundredths: Int
        if service.pricingMode == .perSquareMeter {
            guard let quantity = Decimal(string: quantityText), quantity > 0 else {
                errorMessage = "请输入有效数量。"; return
            }
            quantityHundredths = NSDecimalNumber(decimal: quantity * 100).intValue
        } else {
            quantityHundredths = 100
        }

        let order = ServiceOrder(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            categorySnapshot: service.category,
            productKind: service.productKind,
            projectStage: service.productKind == .project ? .awaitingMaterials : nil,
            deliveryType: service.deliveryType,
            pricingMode: service.pricingMode,
            unitLabel: service.unitLabel,
            unitQuantityHundredths: quantityHundredths,
            totalPriceCents: totalPrice,
            includedSessions: service.productKind == .package ? max(service.includedSessions, 1) : 1,
            validDaysSnapshot: service.productKind == .package ? service.validDays : 0,
            status: .pendingPayment,
            paymentStatus: .unpaid,
            policyVersion: service.ruleVersion.isEmpty ? appState.policyVersion : service.ruleVersion,
            validFrom: .now,
            expiresAt: nil,
            activatedAt: nil,
            guardianName: guardianName,
            subjectName: subjectName,
            notes: notes
        )
        context.insert(order)

        var createdTransactions: [OrderPaymentTransaction] = []
        switch initialPayment {
        case .none:
            break
        case .full:
            createdTransactions.append(orderPayment(order: order, kind: .servicePayment, method: paymentMethod, amount: totalPrice))
        case .balance:
            createdTransactions.append(orderPayment(order: order, kind: .balanceOffset, method: .balance, amount: totalPrice))
        case .partial:
            guard let amount = PaymentLedgerService.yuanTextToCents(paidAmountText), amount < totalPrice else {
                context.delete(order)
                errorMessage = "部分付款必须大于 0 元并小于订单总价。"; return
            }
            createdTransactions.append(orderPayment(order: order, kind: .servicePayment, method: paymentMethod, amount: amount))
        }
        createdTransactions.forEach(context.insert)
        OrderPaymentLedgerService.refreshOrderStatus(order, transactions: createdTransactions)

        context.insert(ConsentRecord(
            clientID: client.id,
            serviceOrderID: order.id,
            type: .servicePolicy,
            textVersion: order.policyVersion,
            textSnapshot: orderPolicyText,
            accepted: true
        ))

        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func orderPayment(
        order: ServiceOrder,
        kind: PaymentTransactionKind,
        method: PaymentMethod,
        amount: Int
    ) -> OrderPaymentTransaction {
        OrderPaymentTransaction(
            orderID: order.id,
            clientID: order.clientID,
            clientCode: order.clientCode,
            serviceNameSnapshot: order.serviceNameSnapshot,
            kind: kind,
            method: method,
            amountCents: amount,
            note: "建立客户订单时记录"
        )
    }

    private var orderPolicyText: String {
        service?.productKind == .project
            ? DefaultBusinessRules.projectOrderPolicySummary
            : DefaultBusinessRules.servicePolicySummary
    }
}
