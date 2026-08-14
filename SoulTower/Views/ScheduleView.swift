import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Appointment.startAt) private var appointments: [Appointment]
    @Query private var clients: [Client]
    @Query(sort: \ServiceItem.sortOrder) private var services: [ServiceItem]
    @State private var selectedDate = Date.now
    @State private var showingEditor = false
    @State private var exportDocument: ScheduleSyncDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var syncMessage = ""

    private var selectedAppointments: [Appointment] {
        appointments.filter { Calendar.current.isDate($0.startAt, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            if selectedAppointments.isEmpty {
                EmptyStateView(icon: "calendar.badge.plus", title: "这一天没有安排", message: "可预约时间默认为 10:00-12:00、16:00-20:00。")
            } else {
                List(selectedAppointments) { appointment in
                    NavigationLink {
                        AppointmentDetailView(appointment: appointment)
                    } label: {
                        AppointmentRow(appointment: appointment)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("咨询排期")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("导出未来 90 天排期") { prepareExport() }
                    Button("导入排期并重建提醒") { showingImporter = true }
                } label: {
                    Label("本地同步", systemImage: "arrow.left.arrow.right")
                }
                Button { showingEditor = true } label: { Label("新建预约", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showingEditor) { AppointmentEditorView(initialDate: selectedDate) }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "心塔排期-\(Date.now.formatted(.dateTime.year().month().day()))"
        ) { result in
            syncMessage = result.isSuccess ? "排期文件已导出，可隔空投送到 iPhone" : "导出失败"
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            importSchedule(result)
        }
        .safeAreaInset(edge: .bottom) {
            if !syncMessage.isEmpty {
                Text(syncMessage)
                    .font(.footnote)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

    private func prepareExport() {
        let end = Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .distantFuture
        let future = appointments.filter { $0.startAt >= Date.now.dayStart && $0.startAt <= end }
        exportDocument = ScheduleSyncDocument(package: ScheduleSyncPackage(appointments: future))
        showingExporter = true
    }

    private func importSchedule(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let package = try ScheduleSyncDocument.decode(data: Data(contentsOf: url))
            guard package.schemaVersion == 1 else {
                syncMessage = "排期文件版本不兼容"; return
            }
            var imported = 0
            var clientCache = Dictionary(uniqueKeysWithValues: clients.map { ($0.clientCode, $0) })
            for entry in package.appointments {
                let status = AppointmentStatus(rawValue: entry.statusRaw) ?? .confirmed
                if let existing = appointments.first(where: { $0.id == entry.id }) {
                    NotificationScheduler.cancel(for: existing)
                    existing.startAt = entry.startAt
                    existing.endAt = entry.endAt
                    existing.statusRaw = entry.statusRaw
                    existing.paymentStatusRaw = entry.paymentStatusRaw
                    existing.videoDeviceRaw = entry.videoDeviceRaw
                    existing.policyVersion = entry.policyVersion
                    existing.changeCount = entry.changeCount
                    existing.updatedAt = .now
                    if status != .confirmed {
                        existing.reminder24Identifier = ""
                        existing.reminder1Identifier = ""
                    }
                    scheduleImportedReminderIfNeeded(existing)
                } else {
                    let client = placeholderClient(for: entry.clientCode, cache: &clientCache)
                    let serviceID = services.first(where: { $0.deliveryType == .video })?.id ?? UUID()
                    let item = Appointment(
                        id: entry.id,
                        clientID: client.id,
                        clientCode: entry.clientCode,
                        clientNameSnapshot: "已同步客户",
                        serviceID: serviceID,
                        serviceNameSnapshot: "心理成长咨询",
                        startAt: entry.startAt,
                        endAt: entry.endAt,
                        status: status,
                        paymentStatus: PaymentStatus(rawValue: entry.paymentStatusRaw) ?? .paid,
                        videoDevice: VideoDevice(rawValue: entry.videoDeviceRaw) ?? .undecided,
                        priceCents: 0,
                        policyVersion: entry.policyVersion,
                        notes: "由最小化排期文件导入，不含客户真实姓名和咨询主题。",
                        changeCount: entry.changeCount
                    )
                    context.insert(item)
                    scheduleImportedReminderIfNeeded(item)
                }
                imported += 1
            }
            try context.save()
            syncMessage = "已导入 \(imported) 条排期，并按状态重建本机提醒"
        } catch {
            syncMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func placeholderClient(for code: String, cache: inout [String: Client]) -> Client {
        if let existing = cache[code] { return existing }
        let client = Client(clientCode: code, displayName: "已同步客户", source: "Mac 本地排期同步", notes: "仅含客户编号，不含真实姓名。")
        context.insert(client)
        cache[code] = client
        return client
    }

    private func scheduleImportedReminderIfNeeded(_ appointment: Appointment) {
        guard appointment.status == .confirmed, appointment.startAt > .now else { return }
        Task { @MainActor in
            if (try? await NotificationScheduler.requestAuthorization()) == true,
               let ids = try? await NotificationScheduler.schedule(for: appointment) {
                appointment.reminder24Identifier = ids.0
                appointment.reminder1Identifier = ids.1
                try? context.save()
            }
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

struct AppointmentDetailView: View {
    @Environment(\.modelContext) private var context
    let appointment: Appointment
    @Query private var consents: [ConsentRecord]
    @Query private var records: [ConsultationRecord]
    @Query private var payments: [PaymentTransaction]
    @Query private var entitlementRedemptions: [EntitlementRedemption]
    @State private var message = ""
    @State private var showingReschedule = false
    @State private var showingPaymentEditor = false
    @State private var showingPackageCancellation = false

    init(appointment: Appointment) {
        self.appointment = appointment
        let id = appointment.id
        _consents = Query(filter: #Predicate<ConsentRecord> { $0.appointmentID == id }, sort: \ConsentRecord.confirmedAt)
        _records = Query(filter: #Predicate<ConsultationRecord> { $0.appointmentID == id })
        _payments = Query(
            filter: #Predicate<PaymentTransaction> { $0.appointmentID == id },
            sort: \PaymentTransaction.occurredAt,
            order: .reverse
        )
        _entitlementRedemptions = Query(
            filter: #Predicate<EntitlementRedemption> { $0.appointmentID == id }
        )
    }

    var body: some View {
        Form {
            Section("预约") {
                LabeledContent("客户", value: "\(appointment.clientCode) · \(appointment.clientNameSnapshot)")
                LabeledContent("服务", value: appointment.serviceNameSnapshot)
                LabeledContent("时间", value: appointment.startAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("设备", value: appointment.videoDevice.rawValue)
                LabeledContent("金额", value: appointment.priceCents.yuanText)
                LabeledContent("付款", value: appointment.paymentStatus.rawValue)
                LabeledContent("状态", value: appointment.status.rawValue)
                Picker("使用设备", selection: Binding(
                    get: { appointment.videoDevice },
                    set: {
                        appointment.videoDevice = $0
                        appointment.updatedAt = .now
                        try? context.save()
                    }
                )) {
                    ForEach(VideoDevice.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            Section("收付款流水") {
                if appointment.serviceOrderID != nil {
                    Label("本次咨询已核销套餐权益，不重复计入咨询费收入。", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(BrandTheme.deepGreen)
                    if entitlementRedemptions.contains(where: \.isReversed) {
                        Label("本次套餐次数已返还，原核销记录仍保留。", systemImage: "arrow.uturn.backward.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    LabeledContent("已覆盖咨询费", value: paymentSummary.coveredServiceCents.yuanText)
                    LabeledContent("待收咨询费", value: remainingServiceCents.yuanText)
                }
                LabeledContent("现金净实收", value: paymentSummary.netCashCents.yuanText)
                if paymentSummary.feeIncomeCents > 0 {
                    LabeledContent("额外费用实收", value: paymentSummary.feeIncomeCents.yuanText)
                }
                if paymentSummary.balanceOffsetCents > 0 {
                    LabeledContent("余额抵扣", value: paymentSummary.balanceOffsetCents.yuanText)
                }
                if payments.isEmpty {
                    Text("尚无流水。旧版付款状态会在升级时自动转换为一条待核对流水。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payments) { payment in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(payment.kind.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(payment.method.rawValue) · \(payment.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(payment.displayAmountCents.yuanText)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(payment.kind == .refund ? .red : .primary)
                        }
                    }
                }
                Button("记录收款、退款或费用") { showingPaymentEditor = true }
            }
            Section("业务操作") {
                if appointment.status == .confirmed {
                    Button("改期") { showingReschedule = true }
                    Button("取消预约", role: .destructive) {
                        if activePackageRedemption != nil {
                            showingPackageCancellation = true
                        } else {
                            cancelAppointment(returnEntitlement: false)
                        }
                    }
                }
                if appointment.status == .confirmed || appointment.status == .inProgress || appointment.status == .completed {
                    Button(records.isEmpty ? "建立咨询记录" : "已建立咨询记录") { createRecord() }
                        .disabled(!records.isEmpty)
                }
            }
            Section("提醒") {
                Text(appointment.reminder24Identifier.isEmpty ? "尚未安排本地提醒" : "已安排提前 24 小时和 1 小时提醒")
                Button("重新安排提醒") {
                    Task { await rescheduleNotifications() }
                }
                .disabled(appointment.startAt <= .now || appointment.status != .confirmed)
            }
            Section("服务规则") {
                LabeledContent("适用版本", value: appointment.policyVersion)
                Text(DefaultBusinessRules.servicePolicySummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("客户确认记录") {
                if consents.isEmpty {
                    Text("未找到确认记录").foregroundStyle(.orange)
                } else {
                    ForEach(consents) { consent in
                        DisclosureGroup {
                            Text(consent.textSnapshot)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            LabeledContent("文本版本", value: consent.textVersion)
                            LabeledContent("确认时间", value: consent.confirmedAt.formatted(date: .abbreviated, time: .shortened))
                            LabeledContent("确认方式", value: consent.confirmationMethod)
                        } label: {
                            HStack {
                                Text(consent.type.rawValue)
                                Spacer()
                                StatusBadge(text: consent.accepted ? "已同意" : "未同意", color: consent.accepted ? .green : .secondary)
                            }
                        }
                    }
                }
            }
            if !message.isEmpty {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(appointment.clientCode)
        .sheet(isPresented: $showingReschedule) {
            RescheduleAppointmentView(appointment: appointment)
        }
        .sheet(isPresented: $showingPaymentEditor) {
            PaymentTransactionEditorView(appointment: appointment)
        }
        .confirmationDialog(
            "本次预约已核销套餐次数",
            isPresented: $showingPackageCancellation,
            titleVisibility: .visible
        ) {
            Button("取消预约并返还 1 次") { cancelAppointment(returnEntitlement: true) }
            Button("取消预约但不返还次数", role: .destructive) { cancelAppointment(returnEntitlement: false) }
            Button("暂不取消", role: .cancel) { }
        } message: {
            Text("请选择双方已经确认的处理方式。两种结果都会写入订单变更记录。")
        }
    }

    private var paymentSummary: AppointmentPaymentSummary {
        PaymentLedgerService.summary(transactions: payments, appointmentPriceCents: appointment.priceCents)
    }

    private var remainingServiceCents: Int {
        PaymentLedgerService.remainingServiceCents(transactions: payments, appointmentPriceCents: appointment.priceCents)
    }

    @MainActor
    private func rescheduleNotifications() async {
        do {
            let allowed = try await NotificationScheduler.requestAuthorization()
            guard allowed else { message = "系统通知权限未开启"; return }
            let ids = try await NotificationScheduler.schedule(for: appointment)
            appointment.reminder24Identifier = ids.0
            appointment.reminder1Identifier = ids.1
            appointment.updatedAt = .now
            try context.save()
            message = "提醒已重新安排"
        } catch {
            message = error.localizedDescription
        }
    }

    private var activePackageRedemption: EntitlementRedemption? {
        EntitlementService.activeRedemption(
            appointmentID: appointment.id,
            redemptions: entitlementRedemptions
        )
    }

    private func cancelAppointment(returnEntitlement: Bool) {
        do {
            NotificationScheduler.cancel(for: appointment)
            appointment.status = .cancelled
            appointment.reminder24Identifier = ""
            appointment.reminder1Identifier = ""
            appointment.updatedAt = .now

            if let orderID = appointment.serviceOrderID {
                let orderDescriptor = FetchDescriptor<ServiceOrder>(
                    predicate: #Predicate { $0.id == orderID }
                )
                if let order = try context.fetch(orderDescriptor).first {
                    let redemptionDescriptor = FetchDescriptor<EntitlementRedemption>(
                        predicate: #Predicate { $0.orderID == orderID }
                    )
                    let allRedemptions = try context.fetch(redemptionDescriptor)
                    if returnEntitlement, let redemption = activePackageRedemption {
                        let before = EntitlementService.remainingSessions(order: order, redemptions: allRedemptions)
                        let reason = "预约 \(appointment.startAt.formatted(date: .abbreviated, time: .shortened)) 取消，双方确认返还套餐次数"
                        EntitlementService.returnSession(
                            redemption: redemption,
                            order: order,
                            allRedemptions: allRedemptions,
                            reason: reason
                        )
                        let after = EntitlementService.remainingSessions(order: order, redemptions: allRedemptions)
                        context.insert(ServiceOrderChangeService.audit(
                            order: order, kind: .entitlementReturned, title: "预约取消返还 1 次",
                            beforeValue: "剩余 \(before) 次", afterValue: "剩余 \(after) 次",
                            reason: reason
                        ))
                    } else if activePackageRedemption != nil {
                        if let redemption = activePackageRedemption {
                            EntitlementService.consume(
                                redemption: redemption,
                                order: order,
                                allRedemptions: allRedemptions
                            )
                        }
                        context.insert(ServiceOrderChangeService.audit(
                            order: order, kind: .entitlementKept, title: "预约取消未返还次数",
                            beforeValue: "已占用 1 次", afterValue: "按双方确认核销 1 次",
                            reason: "预约 \(appointment.startAt.formatted(date: .abbreviated, time: .shortened)) 取消，双方确认不返还套餐次数"
                        ))
                    }
                }
            }
            try context.save()
            message = returnEntitlement ? "预约已取消，套餐次数已返还；原核销记录仍保留" : "预约已取消，套餐次数未返还；处理结果已留痕"
        } catch {
            context.rollback()
            message = "取消失败：\(error.localizedDescription)"
        }
    }

    private func createRecord() {
        guard records.isEmpty else { return }
        do {
            let record = ConsultationRecord(
                appointmentID: appointment.id,
                clientID: appointment.clientID,
                clientCode: appointment.clientCode,
                clientNameSnapshot: appointment.clientNameSnapshot,
                serviceName: appointment.serviceNameSnapshot,
                occurredAt: appointment.startAt
            )
            context.insert(record)
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .recordCreated,
                title: "从预约详情建立咨询资料",
                detail: appointment.startAt.formatted(date: .abbreviated, time: .shortened)
            ))
            appointment.status = .completed
            appointment.updatedAt = .now

            if let orderID = appointment.serviceOrderID,
               let redemption = activePackageRedemption {
                let orderDescriptor = FetchDescriptor<ServiceOrder>(
                    predicate: #Predicate { $0.id == orderID }
                )
                let redemptionDescriptor = FetchDescriptor<EntitlementRedemption>(
                    predicate: #Predicate { $0.orderID == orderID }
                )
                if let order = try context.fetch(orderDescriptor).first {
                    let allRedemptions = try context.fetch(redemptionDescriptor)
                    EntitlementService.consume(
                        redemption: redemption,
                        order: order,
                        allRedemptions: allRedemptions
                    )
                }
            }

            try context.save()
            message = "咨询记录已建立；套餐预约已在完成咨询后正式核销"
        } catch {
            context.rollback()
            message = "建立咨询记录失败：\(error.localizedDescription)"
        }
    }
}

struct RescheduleAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let appointment: Appointment
    @Query private var appointments: [Appointment]
    @State private var newStartAt: Date
    @State private var reason = "客户申请改期"
    @State private var feeRecorded: Bool
    @State private var feeMethod: PaymentMethod = .wechat
    @State private var errorMessage = ""

    init(appointment: Appointment) {
        self.appointment = appointment
        let suggested = Calendar.current.date(byAdding: .day, value: 1, to: appointment.startAt) ?? appointment.startAt
        _newStartAt = State(initialValue: suggested)
        _feeRecorded = State(initialValue: appointment.startAt.timeIntervalSince(.now) < 24 * 60 * 60)
    }

    private var duration: TimeInterval { appointment.endAt.timeIntervalSince(appointment.startAt) }
    private var newEndAt: Date { newStartAt.addingTimeInterval(duration) }

    var body: some View {
        NavigationStack {
            Form {
                Section("原预约") {
                    LabeledContent("原时间", value: appointment.startAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("客户", value: appointment.clientCode)
                }
                Section("新时间") {
                    DatePicker("开始时间", selection: $newStartAt, in: Date.now...)
                    LabeledContent("预计结束", value: newEndAt.formatted(date: .abbreviated, time: .shortened))
                    TextField("改期原因", text: $reason)
                }
                Section("费用记录") {
                    Toggle("已实际收取 200 元晚改期费", isOn: $feeRecorded)
                    if feeRecorded {
                        Picker("收款方式", selection: $feeMethod) {
                            ForEach([PaymentMethod.wechat, .bankTransfer, .cash, .other]) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                    }
                    Text("距离原预约不足 24 小时时默认开启；只有已经收到费用时才保留勾选。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("预约改期")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认改期") { save() } }
            }
        }
        .compactNavigationTitleOnPhone()
        .adaptiveEditorSheet(macWidth: 440, macHeight: 470)
    }

    private func save() {
        guard DefaultBusinessRules.isWithinConsultationHours(start: newStartAt, end: newEndAt) else {
            errorMessage = "新时间须位于 10:00-12:00 或 16:00-20:00。"; return
        }
        guard !DefaultBusinessRules.hasConflict(start: newStartAt, end: newEndAt, appointments: appointments, excluding: appointment.id) else {
            errorMessage = "新时段与已有预约冲突，或不足 15 分钟缓冲。"; return
        }

        let oldTime = appointment.startAt
        let history = Appointment(
            clientID: appointment.clientID,
            clientCode: appointment.clientCode,
            clientNameSnapshot: appointment.clientNameSnapshot,
            serviceID: appointment.serviceID,
            serviceOrderID: appointment.serviceOrderID,
            serviceNameSnapshot: appointment.serviceNameSnapshot,
            startAt: appointment.startAt,
            endAt: appointment.endAt,
            status: .rescheduled,
            paymentStatus: appointment.paymentStatus,
            videoDevice: appointment.videoDevice,
            priceCents: appointment.priceCents,
            policyVersion: appointment.policyVersion,
            guardianName: appointment.guardianName,
            notes: "\(reason)；改至 \(newStartAt.formatted(date: .abbreviated, time: .shortened))；\(feeRecorded ? "已实收 200 元调整费" : "未收调整费")",
            changeCount: appointment.changeCount,
            createdAt: appointment.createdAt
        )
        context.insert(history)
        NotificationScheduler.cancel(for: appointment)
        appointment.startAt = newStartAt
        appointment.endAt = newEndAt
        appointment.changeCount += 1
        appointment.reminder24Identifier = ""
        appointment.reminder1Identifier = ""
        appointment.notes += "\n由 \(oldTime.formatted(date: .abbreviated, time: .shortened)) 改期：\(reason)"
        appointment.updatedAt = .now

        if feeRecorded {
            context.insert(PaymentTransaction(
                appointmentID: appointment.id,
                clientID: appointment.clientID,
                clientCode: appointment.clientCode,
                serviceNameSnapshot: appointment.serviceNameSnapshot,
                kind: .rescheduleFee,
                method: feeMethod,
                amountCents: DefaultBusinessRules.lateRescheduleFeeCents,
                occurredAt: .now,
                note: "晚改期实收费用"
            ))
        }

        do {
            try context.save()
            Task { @MainActor in
                if (try? await NotificationScheduler.requestAuthorization()) == true,
                   let ids = try? await NotificationScheduler.schedule(for: appointment) {
                    appointment.reminder24Identifier = ids.0
                    appointment.reminder1Identifier = ids.1
                    try? context.save()
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AppointmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Client.createdAt) private var clients: [Client]
    @Query(filter: #Predicate<ServiceItem> { $0.isActive }, sort: \ServiceItem.sortOrder) private var services: [ServiceItem]
    @Query private var appointments: [Appointment]
    @Query(sort: \ServiceOrder.placedAt, order: .reverse) private var serviceOrders: [ServiceOrder]
    @Query private var entitlementRedemptions: [EntitlementRedemption]

    @State private var selectedClientID: UUID?
    @State private var selectedServiceID: UUID?
    @State private var startAt: Date
    @State private var device: VideoDevice = .undecided
    @State private var paymentStatus: PaymentStatus = .unpaid
    @State private var selectedOrderID: UUID?
    @State private var paymentMethod: PaymentMethod = .wechat
    @State private var partialPaymentText = ""
    @State private var policyAccepted = false
    @State private var recordingAccepted = false
    @State private var photoAccepted = false
    @State private var aiAccepted = false
    @State private var retentionAccepted = false
    @State private var guardianName = ""
    @State private var notes = ""
    @State private var errorMessage = ""

    init(initialDate: Date = .now) {
        let calendar = Calendar.current
        let proposed = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: initialDate) ?? initialDate
        _startAt = State(initialValue: proposed > .now ? proposed : (calendar.date(byAdding: .day, value: 1, to: proposed) ?? proposed))
    }

    private var selectedClient: Client? { clients.first { $0.id == selectedClientID } }
    private var appointmentServices: [ServiceItem] {
        services.filter { $0.productKind != .project }
    }
    private var selectedService: ServiceItem? { appointmentServices.first { $0.id == selectedServiceID } }
    private var selectedOrder: ServiceOrder? { serviceOrders.first { $0.id == selectedOrderID } }
    private var eligibleOrders: [ServiceOrder] {
        guard let selectedClientID, let selectedServiceID else { return [] }
        return serviceOrders.filter { order in
            order.clientID == selectedClientID &&
            order.serviceID == selectedServiceID &&
            EntitlementService.canRedeem(order: order, redemptions: entitlementRedemptions, at: startAt)
        }
    }
    private var duration: Int { max(selectedService?.durationMinutes ?? 60, 30) }
    private var endAt: Date { startAt.addingTimeInterval(TimeInterval(duration * 60)) }

    var body: some View {
        NavigationStack {
            Form {
                if clients.isEmpty {
                    Section { Text("请先创建至少一位客户。") }
                } else {
                    Section("客户与服务") {
                        Picker("客户", selection: $selectedClientID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(clients.filter { !$0.isArchived }) { Text("\($0.clientCode) · \($0.displayName)").tag(Optional($0.id)) }
                        }
                        Picker("服务", selection: $selectedServiceID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(appointmentServices) { Text("\($0.name) · \($0.priceCents.yuanText)").tag(Optional($0.id)) }
                        }
                        if selectedService?.productKind == .package {
                            Picker("套餐权益", selection: $selectedOrderID) {
                                Text("不使用套餐").tag(UUID?.none)
                                ForEach(eligibleOrders) { order in
                                    Text("剩余 \(EntitlementService.remainingSessions(order: order, redemptions: entitlementRedemptions)) 次 · \(order.placedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .tag(Optional(order.id))
                                }
                            }
                            if eligibleOrders.isEmpty {
                                Text("当前客户没有可用的该套餐，请先建立并收款激活套餐订单。")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    Section("时间与设备") {
                        DatePicker("开始时间", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                        LabeledContent("预计结束", value: endAt.formatted(date: .omitted, time: .shortened))
                        Picker("视频设备", selection: $device) {
                            ForEach(VideoDevice.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("付款状态", selection: $paymentStatus) {
                            ForEach([PaymentStatus.unpaid, .paid, .partial, .balance, .entitlement]) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                        if paymentStatus == .entitlement && selectedOrder == nil {
                            Text("使用套餐权益时必须选择一张仍有次数且未过期的套餐订单。")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if paymentStatus == .paid || paymentStatus == .partial {
                            Picker("收款方式", selection: $paymentMethod) {
                                ForEach([PaymentMethod.wechat, .bankTransfer, .cash, .other]) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                        }
                        if paymentStatus == .partial {
                            TextField("本次实收金额（元）", text: $partialPaymentText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        }
                    }
                    Section("付款前规则") {
                        Text(DefaultBusinessRules.servicePolicySummary)
                            .font(.footnote)
                        Toggle("客户已明确同意当前服务规则", isOn: $policyAccepted)
                    }
                    Section("分别记录客户选择") {
                        Toggle("同意咨询录音", isOn: $recordingAccepted)
                        Toggle("同意拍摄牌阵照片", isOn: $photoAccepted)
                        Toggle("同意本地 AI 处理", isOn: $aiAccepted)
                        Toggle("同意资料长期保存", isOn: $retentionAccepted)
                        Text("长期保存被拒绝时，系统采用限期保留方案，不将其误记为已同意。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if selectedService?.requiresGuardian == true {
                        Section("监护人") {
                            TextField("监护人姓名", text: $guardianName)
                            Text("该服务建立项目订单，不创建未成年人咨询预约。当前编辑器仅保留资料结构，项目模块后续完善。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("内部备注") { TextField("备注", text: $notes, axis: .vertical) }
                    if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新建预约")
            .compactNavigationTitleOnPhone()
            .onChange(of: selectedClientID) { selectedOrderID = nil }
            .onChange(of: selectedServiceID) { selectedOrderID = nil }
            .onChange(of: selectedOrderID) {
                if selectedOrderID != nil { paymentStatus = .entitlement }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存预约") { save() }.disabled(clients.isEmpty) }
            }
        }
        .compactNavigationTitleOnPhone()
        .adaptiveEditorSheet(macWidth: 460, macHeight: 590)
    }

    private func save() {
        guard let client = selectedClient, let service = selectedService else {
            errorMessage = "请选择客户和服务。"; return
        }
        guard service.deliveryType != .project else {
            errorMessage = "项目型服务应进入项目订单，不能直接创建咨询预约。"; return
        }
        guard client.birthDate != nil else {
            errorMessage = "请先在客户资料中填写阳历出生日期。"; return
        }
        guard DefaultBusinessRules.isAdult(birthDate: client.birthDate) else {
            errorMessage = "未满 18 周岁的客户不能创建咨询预约。"; return
        }
        guard policyAccepted else {
            errorMessage = "客户未确认服务规则，不能进入收款和预约流程。"; return
        }
        guard DefaultBusinessRules.isWithinConsultationHours(start: startAt, end: endAt) else {
            errorMessage = "时间须位于 10:00-12:00 或 16:00-20:00。"; return
        }
        guard !DefaultBusinessRules.hasConflict(start: startAt, end: endAt, appointments: appointments) else {
            errorMessage = "该时段与已有预约冲突，或不足 15 分钟缓冲。"; return
        }
        if paymentStatus == .entitlement {
            guard let order = selectedOrder,
                  EntitlementService.canRedeem(order: order, redemptions: entitlementRedemptions, at: startAt) else {
                errorMessage = "请选择一张仍有次数且在有效期内的套餐订单。"; return
            }
        }

        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceOrderID: paymentStatus == .entitlement ? selectedOrderID : nil,
            serviceNameSnapshot: service.name,
            startAt: startAt,
            endAt: endAt,
            status: paymentStatus == .paid || paymentStatus == .balance || paymentStatus == .entitlement ? .confirmed : .pendingPayment,
            paymentStatus: paymentStatus,
            videoDevice: device,
            priceCents: service.priceCents,
            policyVersion: appState.policyVersion,
            guardianName: guardianName,
            notes: notes
        )
        context.insert(appointment)
        if paymentStatus == .paid {
            context.insert(PaymentTransaction(
                appointmentID: appointment.id,
                clientID: client.id,
                clientCode: client.clientCode,
                serviceNameSnapshot: service.name,
                kind: .servicePayment,
                method: paymentMethod,
                amountCents: service.priceCents,
                occurredAt: .now,
                note: "新建预约时记录"
            ))
        } else if paymentStatus == .balance {
            context.insert(PaymentTransaction(
                appointmentID: appointment.id,
                clientID: client.id,
                clientCode: client.clientCode,
                serviceNameSnapshot: service.name,
                kind: .balanceOffset,
                method: .balance,
                amountCents: service.priceCents,
                occurredAt: .now,
                note: "新建预约时记录"
            ))
        } else if paymentStatus == .partial {
            guard let partialCents = PaymentLedgerService.yuanTextToCents(partialPaymentText),
                  partialCents < service.priceCents else {
                context.delete(appointment)
                errorMessage = "部分付款金额须大于 0 元并小于服务标价。"
                return
            }
            context.insert(PaymentTransaction(
                appointmentID: appointment.id,
                clientID: client.id,
                clientCode: client.clientCode,
                serviceNameSnapshot: service.name,
                kind: .servicePayment,
                method: paymentMethod,
                amountCents: partialCents,
                occurredAt: .now,
                note: "新建预约时记录部分付款"
            ))
        } else if paymentStatus == .entitlement, let order = selectedOrder {
            context.insert(EntitlementRedemption(
                orderID: order.id,
                appointmentID: appointment.id,
                clientID: client.id,
                clientCode: client.clientCode,
                serviceNameSnapshot: service.name,
                state: .reserved,
                redeemedAt: startAt,
                note: "预约建立时占用 1 次；咨询完成后正式核销"
            ))
            order.updatedAt = .now
        }
        [
            ConsentRecord(clientID: client.id, appointmentID: appointment.id, type: .servicePolicy, textVersion: appState.policyVersion, textSnapshot: DefaultBusinessRules.servicePolicySummary, accepted: true),
            ConsentRecord(clientID: client.id, appointmentID: appointment.id, type: .recording, textVersion: appState.recordingConsentVersion, textSnapshot: DefaultBusinessRules.recordingConsentNotice, accepted: recordingAccepted),
            ConsentRecord(clientID: client.id, appointmentID: appointment.id, type: .photo, textVersion: appState.photoConsentVersion, textSnapshot: DefaultBusinessRules.photoConsentNotice, accepted: photoAccepted),
            ConsentRecord(clientID: client.id, appointmentID: appointment.id, type: .localAI, textVersion: appState.aiConsentVersion, textSnapshot: DefaultBusinessRules.localAIConsentNotice, accepted: aiAccepted),
            ConsentRecord(clientID: client.id, appointmentID: appointment.id, type: .longTermRetention, textVersion: appState.retentionConsentVersion, textSnapshot: DefaultBusinessRules.retentionNotice, accepted: retentionAccepted)
        ].forEach(context.insert)

        do {
            try context.save()
            if appointment.status == .confirmed {
                Task { @MainActor in
                    if (try? await NotificationScheduler.requestAuthorization()) == true,
                       let ids = try? await NotificationScheduler.schedule(for: appointment) {
                        appointment.reminder24Identifier = ids.0
                        appointment.reminder1Identifier = ids.1
                        try? context.save()
                    }
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
