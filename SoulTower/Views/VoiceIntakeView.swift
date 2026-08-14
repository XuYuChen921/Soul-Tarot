#if os(macOS)
import SwiftData
import SwiftUI

struct VoiceIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Client.createdAt) private var clients: [Client]
    @Query(filter: #Predicate<ServiceItem> { $0.isActive }, sort: \ServiceItem.sortOrder) private var services: [ServiceItem]
    @Query private var appointments: [Appointment]

    @StateObject private var recorder = VoiceIntakeRecorder()
    @State private var draft = VoiceIntakeDraft()
    @State private var selectedExistingClientID: UUID?
    @State private var selectedServiceID: UUID?
    @State private var hasBirthDate = false
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var hasAppointmentStart = false
    @State private var appointmentStart = Date.now
    @State private var isStructuring = false
    @State private var isSaving = false
    @State private var archiveSaved = false
    @State private var showingSaveFeedback = false
    @State private var saveFeedbackTitle = ""
    @State private var saveFeedbackMessage = ""
    @State private var statusMessage = "语音和转写只在当前窗口保留；只有人工确认后的字段会写入档案。"

    private var appointmentServices: [ServiceItem] {
        services.filter { $0.deliveryType != .project }
    }

    private var selectedExistingClient: Client? {
        clients.first { $0.id == selectedExistingClientID }
    }

    private var selectedService: ServiceItem? {
        appointmentServices.first { $0.id == selectedServiceID }
    }

    private var missingFields: [String] {
        var fields: [String] = []
        let clientName = selectedExistingClient?.displayName ?? draft.displayName
        let clientBirthDate = selectedExistingClient?.birthDate ?? (hasBirthDate ? birthDate : nil)
        if clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("客户称呼") }
        if clientBirthDate == nil { fields.append("阳历出生日期") }
        if selectedExistingClientID == nil && draft.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("客户来源") }
        if selectedService == nil { fields.append("服务项目") }
        if !hasAppointmentStart { fields.append("预约日期和时间") }
        if draft.videoDevice == nil { fields.append("使用设备") }
        if draft.paymentStatus == nil { fields.append("付款状态") }
        if draft.policyConsent != .accepted { fields.append("明确同意当前服务规则") }
        if draft.recordingConsent == .unknown { fields.append("是否同意录音") }
        if draft.photoConsent == .unknown { fields.append("是否同意牌阵照片") }
        if draft.localAIConsent == .unknown { fields.append("是否同意本地 AI 处理") }
        if draft.retentionConsent == .unknown { fields.append("是否同意长期保存") }
        if draft.archiveSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("档案摘要") }
        return fields
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                intakePanel
                    .frame(width: 380)
                Divider()
                reviewForm
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("语音建档")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        recorder.stopRecording(cancelRecognition: true)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { saveArchive() } label: {
                        if isSaving {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在建立档案…")
                            }
                        } else if archiveSaved {
                            Label("档案已建立", systemImage: "checkmark.circle.fill")
                        } else {
                            Text("人工确认并建立档案")
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(isStructuring || isSaving || archiveSaved)
                }
            }
        }
        .frame(width: 920, height: 660)
        .onDisappear { recorder.stopRecording(cancelRecognition: true) }
        .alert(saveFeedbackTitle, isPresented: $showingSaveFeedback) {
            Button(archiveSaved ? "完成" : "知道了") {
                if archiveSaved { dismiss() }
            }
        } message: {
            Text(saveFeedbackMessage)
        }
    }

    private var intakePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(VoiceIntakeTemplate.requiredItems.enumerated()), id: \.offset) { index, item in
                            Text("\(index + 1). \(item)")
                                .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("必须说出的信息", systemImage: "checklist")
                        .font(.headline)
                }

                GroupBox("可直接照着说") {
                    Text(VoiceIntakeTemplate.example)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Button {
                        Task { await recorder.toggleRecording() }
                    } label: {
                        Label(recorder.isRecording ? "停止录音" : "开始录音", systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(recorder.isRecording ? .red : BrandTheme.teal)

                    Button("清空") {
                        recorder.reset()
                        draft = VoiceIntakeDraft()
                        resetReviewDates()
                    }
                }

                Text(recorder.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("本机转写文字")
                    .font(.headline)
                TextEditor(text: $recorder.transcript)
                    .font(.body)
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    .disabled(recorder.isRecording)

                if recorder.isRecording {
                    Text("录音期间文字只读，停止后可以人工修改，避免实时识别覆盖手动编辑。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    structureWithLocalAI()
                } label: {
                    Label(isStructuring ? "本地 AI 正在整理…" : "交给本地 AI 生成可编辑档案", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStructuring || recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recorder.isRecording)

                Text("语音识别强制使用 Mac 本机模式；本地 AI 仅连接 127.0.0.1。AI 不会直接保存，右侧必须人工核对。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .background(.thinMaterial)
    }

    private var reviewForm: some View {
        Form {
            Section("客户") {
                Picker("档案处理", selection: $selectedExistingClientID) {
                    Text("创建新客户").tag(UUID?.none)
                    ForEach(clients.filter { !$0.isArchived }) { client in
                        Text("关联 \(client.clientCode) · \(client.displayName)").tag(Optional(client.id))
                    }
                }
                if selectedExistingClientID == nil {
                    TextField("客户称呼（必填）", text: $draft.displayName)
                    TextField("微信昵称", text: $draft.wechatNickname)
                    TextField("手机号", text: $draft.phone)
                    TextField("来源", text: $draft.source)
                    Toggle("已明确阳历出生日期", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("阳历出生日期", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    }
                } else if let client = selectedExistingClient {
                    LabeledContent("使用客户", value: "\(client.clientCode) · \(client.displayName)")
                    LabeledContent("出生日期", value: client.birthDate?.formatted(date: .numeric, time: .omitted) ?? "未填写")
                }
            }

            Section("预约") {
                Picker("服务项目", selection: $selectedServiceID) {
                    Text("请选择").tag(UUID?.none)
                    ForEach(appointmentServices) { service in
                        Text("\(service.name) · \(service.priceCents.yuanText)").tag(Optional(service.id))
                    }
                }
                Toggle("已明确预约日期和时间", isOn: $hasAppointmentStart)
                if hasAppointmentStart {
                    DatePicker("开始时间", selection: $appointmentStart, displayedComponents: [.date, .hourAndMinute])
                }
                Picker("视频设备", selection: $draft.videoDevice) {
                    Text("未说明").tag(VideoDevice?.none)
                    ForEach(VideoDevice.allCases) { device in
                        Text(device.rawValue).tag(Optional(device))
                    }
                }
                Picker("付款状态", selection: $draft.paymentStatus) {
                    Text("未说明").tag(PaymentStatus?.none)
                    ForEach([PaymentStatus.unpaid, .paid, .partial, .balance]) { status in
                        Text(status.rawValue).tag(Optional(status))
                    }
                }
            }

            Section("客户明确选择") {
                consentPicker("当前服务规则", selection: $draft.policyConsent)
                consentPicker("咨询录音", selection: $draft.recordingConsent)
                consentPicker("牌阵照片", selection: $draft.photoConsent)
                consentPicker("本地 AI 处理", selection: $draft.localAIConsent)
                consentPicker("长期保存", selection: $draft.retentionConsent)
            }

            Section("档案摘要（可编辑）") {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $draft.archiveSummary)
                        .font(.body)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 180, idealHeight: 210)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                        }
                        .accessibilityIdentifier("voiceArchiveSummaryEditor")

                    Text("可上下滚动查看完整内容；保存前请人工核对。共 \(draft.archiveSummary.count) 字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !missingFields.isEmpty {
                Section("保存前仍需补充") {
                    Text(missingFields.joined(separator: "、"))
                        .foregroundStyle(.orange)
                }
            }

            if !statusMessage.isEmpty {
                Section("状态") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: missingFields.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(missingFields.isEmpty ? .green : .orange)
                Text(missingFields.isEmpty ? "必填信息已完整，可以人工确认并建立档案。" : "保存前还需补充 \(missingFields.count) 项；点击建立档案可查看明细。")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func consentPicker(_ title: String, selection: Binding<ExplicitConsentChoice>) -> some View {
        Picker(title, selection: selection) {
            ForEach(ExplicitConsentChoice.allCases) { choice in
                Text(choice.rawValue).tag(choice)
            }
        }
        .pickerStyle(.segmented)
    }

    private func structureWithLocalAI() {
        isStructuring = true
        statusMessage = "本地 AI 正在提取字段和生成摘要，不会自动写入数据库…"
        let transcript = recorder.transcript
        let serviceNames = appointmentServices.map(\.name)
        Task {
            do {
                let result = try await LocalAIService().structureVoiceIntake(
                    transcript: transcript,
                    serviceNames: serviceNames,
                    baseURL: appState.aiBaseURL,
                    model: appState.aiModelName
                )
                apply(result)
                statusMessage = missingFields.isEmpty
                    ? "本地 AI 已生成草稿。请逐项核对，确认无误后再建立档案。"
                    : "本地 AI 已生成草稿；橙色区域列出了仍需人工补充的内容。"
            } catch {
                statusMessage = error.localizedDescription
            }
            isStructuring = false
        }
    }

    private func apply(_ result: VoiceIntakeDraft) {
        draft = result
        if let date = VoiceIntakeDateParser.birthDate(result.birthDateText) {
            birthDate = date
            hasBirthDate = true
        } else {
            hasBirthDate = false
        }
        if let date = VoiceIntakeDateParser.appointmentStart(result.appointmentStartText) {
            appointmentStart = date
            hasAppointmentStart = true
        } else {
            hasAppointmentStart = false
        }
        selectedServiceID = appointmentServices.first {
            $0.name.caseInsensitiveCompare(result.serviceName) == .orderedSame
        }?.id
        selectedExistingClientID = clients.first {
            (!result.wechatNickname.isEmpty && !$0.wechatNickname.isEmpty && $0.wechatNickname.caseInsensitiveCompare(result.wechatNickname) == .orderedSame) ||
            $0.displayName.caseInsensitiveCompare(result.displayName) == .orderedSame
        }?.id
    }

    private func resetReviewDates() {
        hasBirthDate = false
        hasAppointmentStart = false
        selectedExistingClientID = nil
        selectedServiceID = nil
        birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
        appointmentStart = .now
        statusMessage = "已清空本轮内容。"
    }

    private func saveArchive() {
        guard !isSaving, !archiveSaved else { return }
        isSaving = true
        defer { isSaving = false }

        guard missingFields.isEmpty else {
            rejectSave("还不能建立档案。", detail: "请先补充：\(missingFields.joined(separator: "、"))。")
            return
        }
        guard let service = selectedService,
              let device = draft.videoDevice,
              let paymentStatus = draft.paymentStatus,
              let recordingAccepted = draft.recordingConsent.boolValue,
              let photoAccepted = draft.photoConsent.boolValue,
              let aiAccepted = draft.localAIConsent.boolValue,
              let retentionAccepted = draft.retentionConsent.boolValue else {
            rejectSave("还不能建立档案。", detail: "仍有未明确的预约或同意信息，请逐项检查。")
            return
        }
        guard paymentStatus != .entitlement && paymentStatus != .refunded else {
            rejectSave("付款状态需要人工处理。", detail: "套餐权益和退款不能通过语音建档直接创建，请改用预约或订单页面。")
            return
        }

        let resolvedBirthDate = selectedExistingClient?.birthDate ?? (hasBirthDate ? birthDate : nil)
        guard let resolvedBirthDate else {
            rejectSave("缺少出生日期。", detail: "必须填写并确认客户的阳历出生日期。")
            return
        }
        guard DefaultBusinessRules.isAdult(birthDate: resolvedBirthDate) else {
            rejectSave("不符合年龄规则。", detail: "未满 18 周岁的客户不能建立咨询预约。")
            return
        }
        let endAt = appointmentStart.addingTimeInterval(TimeInterval(max(service.durationMinutes, 30) * 60))
        guard DefaultBusinessRules.isWithinConsultationHours(start: appointmentStart, end: endAt) else {
            rejectSave("预约时间不符合规则。", detail: "预约及完整服务时长须位于 10:00-12:00 或 16:00-20:00。")
            return
        }
        guard !DefaultBusinessRules.hasConflict(start: appointmentStart, end: endAt, appointments: appointments) else {
            rejectSave("预约时间冲突。", detail: "该时段与已有预约冲突，或前后不足 15 分钟缓冲。")
            return
        }

        let client: Client
        if let existing = selectedExistingClient {
            client = existing
            if existing.birthDate == nil { existing.birthDate = resolvedBirthDate }
            if existing.wechatNickname.isEmpty && !draft.wechatNickname.isEmpty { existing.wechatNickname = draft.wechatNickname }
            if existing.phone.isEmpty && !draft.phone.isEmpty { existing.phone = draft.phone }
            if existing.source.isEmpty && !draft.source.isEmpty { existing.source = draft.source }
            if !existing.notes.contains(draft.archiveSummary) {
                existing.notes += existing.notes.isEmpty ? draft.archiveSummary : "\n\(draft.archiveSummary)"
            }
            existing.updatedAt = .now
        } else {
            client = Client(
                clientCode: nextClientCode,
                displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                wechatNickname: draft.wechatNickname,
                phone: draft.phone,
                source: draft.source.isEmpty ? "熟人介绍" : draft.source,
                birthDate: resolvedBirthDate,
                notes: draft.archiveSummary
            )
            context.insert(client)
        }

        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            startAt: appointmentStart,
            endAt: endAt,
            status: paymentStatus == .paid || paymentStatus == .balance ? .confirmed : .pendingPayment,
            paymentStatus: paymentStatus,
            videoDevice: device,
            priceCents: service.priceCents,
            policyVersion: appState.policyVersion,
            notes: "由 Mac 语音建档，经人工确认。\n\(draft.archiveSummary)"
        )
        context.insert(appointment)
        if paymentStatus == .paid {
            context.insert(PaymentTransaction(
                appointmentID: appointment.id,
                clientID: client.id,
                clientCode: client.clientCode,
                serviceNameSnapshot: service.name,
                kind: .servicePayment,
                method: .wechat,
                amountCents: service.priceCents,
                occurredAt: .now,
                note: "由 Mac 语音建档记录，默认微信收款"
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
                note: "由 Mac 语音建档记录"
            ))
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
                       let identifiers = try? await NotificationScheduler.schedule(for: appointment) {
                        appointment.reminder24Identifier = identifiers.0
                        appointment.reminder1Identifier = identifiers.1
                        try? context.save()
                    }
                }
            }
            recorder.stopRecording(cancelRecognition: true)
            archiveSaved = true
            saveFeedbackTitle = "档案已建立"
            saveFeedbackMessage = "已建立客户 \(client.clientCode) · \(client.displayName)，并创建 \(appointmentStart.formatted(date: .abbreviated, time: .shortened)) 的预约。"
            statusMessage = saveFeedbackMessage
            showingSaveFeedback = true
        } catch {
            context.rollback()
            rejectSave("建立档案失败。", detail: error.localizedDescription)
        }
    }

    private func rejectSave(_ title: String, detail: String) {
        archiveSaved = false
        saveFeedbackTitle = title
        saveFeedbackMessage = detail
        statusMessage = "\(title) \(detail)"
        showingSaveFeedback = true
    }

    private var nextClientCode: String {
        let number = clients.compactMap { Int($0.clientCode.replacingOccurrences(of: "C-", with: "")) }.max() ?? 0
        return String(format: "C-%04d", number + 1)
    }
}
#endif
