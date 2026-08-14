import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct RecordsView: View {
    @Query(sort: \ConsultationRecord.occurredAt, order: .reverse) private var records: [ConsultationRecord]
    @State private var showingNewRecord = false

    var body: some View {
        Group {
            if records.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "还没有咨询资料",
                    message: "先建立预约和客户确认记录；咨询后再建立资料档案。"
                )
            } else {
                List(records) { record in
                    NavigationLink {
                        RecordDetailView(record: record)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: record.archivedAt == nil ? "waveform.and.mic" : "archivebox.fill")
                                .font(.title2)
                                .foregroundStyle(record.archivedAt == nil ? BrandTheme.teal : .green)
                                .frame(width: 42)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(record.clientCode) · \(record.serviceName)")
                                    .font(.headline)
                                Text(record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if record.archivedAt != nil {
                                StatusBadge(text: "已归档", color: .green)
                            } else {
                                StatusBadge(text: record.aiStatus.rawValue, color: record.aiStatus.color)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("咨询资料")
        .toolbar {
            Button { showingNewRecord = true } label: {
                Label("从预约建立资料", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingNewRecord) { RecordEditorView() }
    }
}

struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Appointment.startAt, order: .reverse) private var appointments: [Appointment]
    @Query private var existingRecords: [ConsultationRecord]
    @State private var appointmentID: UUID?

    private var availableAppointments: [Appointment] {
        let linkedIDs = Set(existingRecords.compactMap(\.appointmentID))
        return appointments.filter {
            !linkedIDs.contains($0.id)
                && $0.status != .cancelled
                && $0.status != .rescheduled
                && $0.status != .noShow
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("关联预约") {
                    Picker("预约", selection: $appointmentID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(availableAppointments) { appointment in
                            Text("\(appointment.clientCode) · \(appointment.startAt.formatted(date: .abbreviated, time: .shortened)) · \(appointment.serviceNameSnapshot)")
                                .tag(Optional(appointment.id))
                        }
                    }
                    if let appointment {
                        LabeledContent("客户", value: "\(appointment.clientCode) · \(appointment.clientNameSnapshot)")
                        LabeledContent("服务", value: appointment.serviceNameSnapshot)
                        LabeledContent("视频设备", value: appointment.videoDevice.rawValue)
                    }
                }
                Section {
                    Text("咨询资料必须关联预约，应用才能核对录音、牌阵照片、本地 AI 和长期保存同意。没有对应预约时，请先到“排期”建立记录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if availableAppointments.isEmpty {
                    Section {
                        ContentUnavailableView("没有可建立资料的预约", systemImage: "calendar.badge.exclamationmark", description: Text("现有预约可能已经建立过咨询资料。"))
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("建立咨询资料")
            .onAppear { appointmentID = appointmentID ?? availableAppointments.first?.id }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") { save() }
                        .disabled(appointment == nil)
                }
            }
        }
        .compactNavigationTitleOnPhone()
        .adaptiveEditorSheet(macWidth: 520, macHeight: 460)
    }

    private var appointment: Appointment? {
        availableAppointments.first { $0.id == appointmentID }
    }

    private func save() {
        guard let appointment else { return }
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
            title: "从预约建立咨询资料",
            detail: appointment.startAt.formatted(date: .abbreviated, time: .shortened)
        ))
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
        }
    }
}

struct RecordDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    let record: ConsultationRecord
    @Query private var assets: [MediaAsset]
    @Query private var consents: [ConsentRecord]
    @Query private var activities: [ConsultationActivity]
    @Query private var revisions: [ConsultationSummaryRevision]
    @State private var showingImporter = false
    @State private var message = ""
    @State private var isGenerating = false
    @State private var transcribingAssetID: UUID?
    @State private var transcriptDraft: String
    @State private var summaryDraftText: String
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(record: ConsultationRecord) {
        self.record = record
        let recordID = record.id
        let clientID = record.clientID
        _assets = Query(
            filter: #Predicate<MediaAsset> { $0.sessionID == recordID },
            sort: \MediaAsset.importedAt,
            order: .reverse
        )
        _consents = Query(
            filter: #Predicate<ConsentRecord> { $0.clientID == clientID },
            sort: \ConsentRecord.confirmedAt,
            order: .reverse
        )
        _activities = Query(
            filter: #Predicate<ConsultationActivity> { $0.recordID == recordID },
            sort: \ConsultationActivity.occurredAt,
            order: .reverse
        )
        _revisions = Query(
            filter: #Predicate<ConsultationSummaryRevision> { $0.recordID == recordID },
            sort: \ConsultationSummaryRevision.version,
            order: .reverse
        )
        _transcriptDraft = State(initialValue: record.transcriptText)
        _summaryDraftText = State(initialValue: record.summaryDraft)
    }

    var body: some View {
        Form {
            overviewSection
            consentSection
            mediaSection
            transcriptSection
            summarySection
            archiveSection
            historySection
            if !message.isEmpty {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(record.clientCode)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio, .image, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
        }
    }

    private var overviewSection: some View {
        Section("本次咨询") {
            LabeledContent("客户", value: "\(record.clientCode) · \(record.clientNameSnapshot)")
            LabeledContent("服务", value: record.serviceName)
            LabeledContent("时间", value: record.occurredAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("归档状态") {
                StatusBadge(text: assessment.status.rawValue, color: assessment.status.color)
            }
            LabeledContent("AI 状态") {
                StatusBadge(text: record.aiStatus.rawValue, color: record.aiStatus.color)
            }
        }
    }

    private var consentSection: some View {
        Section("客户确认核对") {
            consentRow("录音", type: .recording)
            consentRow("牌阵照片", type: .photo)
            consentRow("本地 AI", type: .localAI)
            consentRow("长期保存", type: .longTermRetention)
            if record.appointmentID == nil {
                Label("未关联预约，无法核对本次确认记录", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var mediaSection: some View {
        Section("永久资料文件") {
            Button { showingImporter = true } label: {
                Label("导入录音、牌阵照片或转写文件", systemImage: "square.and.arrow.down")
            }
            .disabled(isLocked)
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 20,
                matching: .images
            ) {
                Label("从照片中选择牌阵照片", systemImage: "photo.on.rectangle.angled")
            }
            .disabled(isLocked)
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                Task { await importPhotos(items) }
            }

            if assets.isEmpty {
                Text("尚未导入资料").foregroundStyle(.secondary)
            } else {
                ForEach(assets) { asset in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Label(asset.kind.rawValue, systemImage: mediaIcon(asset.kind))
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: asset.fileSize, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(asset.originalFilename)
                            .font(.subheadline)
                            .lineLimit(2)
                        if let sha256 = asset.sha256, !sha256.isEmpty {
                            Text("完整性：\(sha256.prefix(12))…")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("旧资料：下次重新导入时生成完整性指纹")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if asset.kind == .audio {
                            Button {
                                Task { await transcribe(asset) }
                            } label: {
                                Label(
                                    transcribingAssetID == asset.id ? "正在本机转写…" : "使用本机离线识别转写",
                                    systemImage: "waveform.badge.mic"
                                )
                            }
                            .disabled(isLocked || transcribingAssetID != nil)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var transcriptSection: some View {
        Section("文字转写") {
            LabeledContent("来源", value: record.transcriptSource.rawValue)
            TextEditor(text: $transcriptDraft)
                .frame(minHeight: 180)
                .disabled(isLocked)
            Button("保存转写") { saveTranscriptManually() }
                .disabled(isLocked || transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("修改已经批准摘要所依据的转写时，当前正式摘要会失效，但旧版本仍永久保留在下方。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summarySection: some View {
        Section("摘要整理与人工批准") {
            Button {
                Task { await generateSummary() }
            } label: {
                Label(isGenerating ? "正在本机整理…" : "使用本地 AI 生成摘要草稿", systemImage: "wand.and.stars")
            }
            .disabled(isLocked || isGenerating || transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            #if os(iOS)
            Text("本地 AI 服务运行在 Mac；iPhone 可查看、编辑和批准已经生成的草稿，也可以使用本机离线语音识别转写录音。")
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif

            TextEditor(text: $summaryDraftText)
                .frame(minHeight: 220)
                .disabled(isLocked)
            Button("保存摘要草稿") { saveSummaryDraft() }
                .disabled(isLocked || summaryDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("批准为正式摘要") { approveSummary() }
                .buttonStyle(.borderedProminent)
                .disabled(isLocked || summaryDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !record.formalSummary.isEmpty {
                LabeledContent("当前正式版本", value: "V\(record.formalSummaryVersion)")
                Text(record.formalSummary).textSelection(.enabled)
            }

            if !revisions.isEmpty {
                DisclosureGroup("历史正式摘要（\(revisions.count) 个版本）") {
                    ForEach(revisions) { revision in
                        DisclosureGroup("V\(revision.version) · \(revision.approvedAt.formatted(date: .abbreviated, time: .shortened))") {
                            Text(revision.content).textSelection(.enabled)
                            if !revision.aiModelName.isEmpty {
                                Text("AI 模型：\(revision.aiModelName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var archiveSection: some View {
        Section("交付与归档") {
            if hasAudio {
                LabeledContent("录音交付", value: record.recordingDeliveredAt?.formatted(date: .abbreviated, time: .shortened) ?? "尚未标记")
                Button("标记录音已发给客户") { markRecordingDelivered() }
                    .disabled(isLocked || record.recordingDeliveredAt != nil)
            }

            if assessment.missingItems.isEmpty && !isLocked {
                Label("归档条件已满足", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if !isLocked {
                VStack(alignment: .leading, spacing: 5) {
                    Text("归档前还需完成：")
                    ForEach(assessment.missingItems, id: \.self) { item in
                        Label(item, systemImage: "circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isLocked {
                Button("重新打开归档") { reopenArchive() }
            } else {
                Button("确认完成并锁定归档") { archive() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!assessment.canArchive)
            }
            Text("归档后默认禁止改写和继续导入。重新打开也会写入历史记录。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var historySection: some View {
        Section("操作历史") {
            if activities.isEmpty {
                Text("暂无操作记录").foregroundStyle(.secondary)
            } else {
                ForEach(activities) { activity in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.title)
                        Text("\(activity.kind.rawValue) · \(activity.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !activity.detail.isEmpty {
                            Text(activity.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var assessment: ConsultationArchiveAssessment {
        ConsultationWorkflowService.assessment(record: record, assets: assets, consents: consents)
    }

    private var isLocked: Bool { record.archivedAt != nil }
    private var hasAudio: Bool { assets.contains { $0.kind == .audio } }

    private func consentRow(_ label: String, type: ConsentType) -> some View {
        let accepted = ConsultationWorkflowService.hasAcceptedConsent(
            type,
            appointmentID: record.appointmentID,
            consents: consents
        )
        return LabeledContent(label) {
            StatusBadge(text: accepted ? "已同意" : "未同意或未找到", color: accepted ? .green : .orange)
        }
    }

    private func mediaIcon(_ kind: MediaKind) -> String {
        switch kind {
        case .audio: return "waveform"
        case .image: return "photo"
        case .transcript: return "doc.plaintext"
        case .document: return "doc"
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        var importedPaths: [String] = []
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }
            for url in urls {
                let kind = MediaStorageService.mediaKind(for: url.pathExtension.lowercased())
                try ConsultationWorkflowService.validateImport(kind: kind, record: record, consents: consents)
            }
            for url in urls {
                let imported = try MediaStorageService.importFile(
                    from: url,
                    clientID: record.clientID,
                    sessionID: record.id
                )
                importedPaths.append(imported.relativePath)
                let asset = MediaAsset(
                    sessionID: record.id,
                    clientID: record.clientID,
                    kind: imported.kind,
                    originalFilename: url.lastPathComponent,
                    relativePath: imported.relativePath,
                    fileSize: imported.size,
                    sha256: imported.sha256,
                    retentionMode: "长期保存（已同意）"
                )
                context.insert(asset)
                context.insert(ConsultationWorkflowService.activity(
                    record: record,
                    kind: .mediaImported,
                    title: "导入\(imported.kind.rawValue)",
                    detail: "\(url.lastPathComponent) · SHA-256 \(imported.sha256.prefix(12))…"
                ))

                if imported.kind == .transcript,
                   let text = try? MediaStorageService.text(for: imported.relativePath) {
                    applyTranscript(
                        ConsultationWorkflowService.mergedTranscript(existing: record.transcriptText, generated: text),
                        source: .importedFile,
                        activityKind: .transcriptSaved,
                        title: "从文件导入转写"
                    )
                }
            }
            record.updatedAt = .now
            try context.save()
            message = "已导入 \(urls.count) 个文件并生成完整性指纹"
        } catch {
            context.rollback()
            importedPaths.forEach { try? MediaStorageService.removeFile(relativePath: $0) }
            message = error.localizedDescription
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { selectedPhotos = [] }
        var importedPaths: [String] = []
        do {
            try ConsultationWorkflowService.validateImport(kind: .image, record: record, consents: consents)
            var importedCount = 0
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let contentType = item.supportedContentTypes.first ?? .jpeg
                let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
                let imported = try MediaStorageService.importData(
                    data,
                    fileExtension: fileExtension,
                    clientID: record.clientID,
                    sessionID: record.id
                )
                importedPaths.append(imported.relativePath)
                let filename = "牌阵照片-\(record.clientCode)-\(importedCount + 1).\(fileExtension)"
                context.insert(MediaAsset(
                    sessionID: record.id,
                    clientID: record.clientID,
                    kind: .image,
                    originalFilename: filename,
                    relativePath: imported.relativePath,
                    fileSize: imported.size,
                    sha256: imported.sha256,
                    retentionMode: "长期保存（已同意）"
                ))
                context.insert(ConsultationWorkflowService.activity(
                    record: record,
                    kind: .mediaImported,
                    title: "从照片中导入牌阵照片",
                    detail: "\(filename) · SHA-256 \(imported.sha256.prefix(12))…"
                ))
                importedCount += 1
            }
            record.updatedAt = .now
            try context.save()
            message = importedCount == 0 ? "没有读取到可导入的照片" : "已导入 \(importedCount) 张牌阵照片"
        } catch {
            context.rollback()
            importedPaths.forEach { try? MediaStorageService.removeFile(relativePath: $0) }
            message = error.localizedDescription
        }
    }

    @MainActor
    private func transcribe(_ asset: MediaAsset) async {
        do {
            try ConsultationWorkflowService.validateImport(kind: .audio, record: record, consents: consents)
            transcribingAssetID = asset.id
            defer { transcribingAssetID = nil }
            let fileURL = try MediaStorageService.absoluteURL(for: asset.relativePath)
            let output = try await LocalAudioTranscriptionService().transcribe(fileURL: fileURL)
            let merged = ConsultationWorkflowService.mergedTranscript(
                existing: record.transcriptText,
                generated: output
            )
            applyTranscript(
                merged,
                source: .onDeviceAudio,
                activityKind: .localTranscription,
                title: "完成本机离线录音转写"
            )
            try context.save()
            message = "本机转写已保存；请逐字核对听错和遗漏"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func saveTranscriptManually() {
        do {
            applyTranscript(
                transcriptDraft,
                source: record.transcriptSource == .manual ? .manual : record.transcriptSource,
                activityKind: .transcriptSaved,
                title: "人工保存并核对转写"
            )
            try context.save()
            message = "转写已保存"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func applyTranscript(
        _ text: String,
        source: TranscriptSource,
        activityKind: ConsultationActivityKind,
        title: String
    ) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let changed = clean != record.transcriptText
        record.transcriptText = clean
        transcriptDraft = clean
        record.transcriptSource = source
        record.transcriptUpdatedAt = .now
        record.aiStatus = clean.isEmpty ? .noTranscript : .ready
        record.updatedAt = .now
        if changed, record.approvedAt != nil {
            record.formalSummary = ""
            record.approvedAt = nil
        }
        context.insert(ConsultationWorkflowService.activity(
            record: record,
            kind: activityKind,
            title: title,
            detail: "来源：\(source.rawValue)；\(clean.count) 个字符"
        ))
    }

    @MainActor
    private func generateSummary() async {
        do {
            try ConsultationWorkflowService.validateLocalAI(record: record, consents: consents)
        } catch {
            message = error.localizedDescription
            return
        }
        if transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines) != record.transcriptText {
            applyTranscript(
                transcriptDraft,
                source: record.transcriptSource,
                activityKind: .transcriptSaved,
                title: "生成 AI 草稿前保存转写"
            )
        }
        isGenerating = true
        record.aiStatus = .generating
        defer { isGenerating = false }
        do {
            let output = try await LocalAIService().generateSummary(
                transcript: record.transcriptText,
                baseURL: appState.aiBaseURL,
                model: appState.aiModelName
            )
            record.summaryDraft = output
            summaryDraftText = output
            record.aiModelName = appState.aiModelName
            record.aiStatus = .draft
            record.updatedAt = .now
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .aiDraftGenerated,
                title: "生成本地 AI 摘要草稿",
                detail: "模型：\(appState.aiModelName)；草稿必须人工核对"
            ))
            try context.save()
            message = "AI 草稿已生成，请人工核对后再批准"
        } catch {
            record.aiStatus = .failed
            try? context.save()
            message = error.localizedDescription
        }
    }

    private func saveSummaryDraft() {
        do {
            guard ConsultationWorkflowService.hasAcceptedConsent(
                .longTermRetention,
                appointmentID: record.appointmentID,
                consents: consents
            ) else {
                throw ConsultationWorkflowError.missingRetentionConsent
            }
            let clean = summaryDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
            record.summaryDraft = clean
            record.aiStatus = .draft
            record.updatedAt = .now
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .summaryDraftSaved,
                title: "人工保存摘要草稿",
                detail: "\(clean.count) 个字符；尚未成为正式摘要"
            ))
            try context.save()
            message = "摘要草稿已保存，仍需人工批准"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func approveSummary() {
        let clean = summaryDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            guard ConsultationWorkflowService.hasAcceptedConsent(
                .longTermRetention,
                appointmentID: record.appointmentID,
                consents: consents
            ) else {
                throw ConsultationWorkflowError.missingRetentionConsent
            }
            if transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines) != record.transcriptText {
                applyTranscript(
                    transcriptDraft,
                    source: record.transcriptSource,
                    activityKind: .transcriptSaved,
                    title: "批准摘要前保存转写"
                )
            }
            let version = max(record.formalSummaryVersion, revisions.map(\.version).max() ?? 0) + 1
            let now = Date.now
            record.summaryDraft = clean
            record.formalSummary = clean
            record.formalSummaryVersion = version
            record.aiStatus = .approved
            record.approvedAt = now
            record.updatedAt = now
            context.insert(ConsultationSummaryRevision(
                recordID: record.id,
                clientID: record.clientID,
                version: version,
                content: clean,
                aiModelName: record.aiModelName,
                approvedAt: now
            ))
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .formalSummaryApproved,
                title: "人工批准正式摘要 V\(version)",
                detail: record.aiModelName.isEmpty ? "人工整理" : "由 \(record.aiModelName) 草稿人工校对"
            ))
            try context.save()
            message = "正式摘要 V\(version) 已保存"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func markRecordingDelivered() {
        guard hasAudio else { return }
        do {
            guard ConsultationWorkflowService.hasAcceptedConsent(
                .recording,
                appointmentID: record.appointmentID,
                consents: consents
            ) else {
                throw ConsultationWorkflowError.missingRecordingConsent
            }
            let now = Date.now
            record.recordingDeliveredAt = now
            record.updatedAt = now
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .recordingDelivered,
                title: "录音已人工发送给客户",
                detail: "仅记录完成状态，不自动操作微信"
            ))
            try context.save()
            message = "已记录录音交付时间"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func archive() {
        do {
            try ConsultationWorkflowService.validateArchive(record: record, assets: assets, consents: consents)
            let now = Date.now
            record.archivedAt = now
            record.updatedAt = now
            context.insert(ConsultationWorkflowService.activity(
                record: record,
                kind: .archived,
                title: "咨询资料完成归档并锁定",
                detail: "正式摘要 V\(record.formalSummaryVersion)"
            ))
            try context.save()
            message = "归档完成，资料已锁定"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }

    private func reopenArchive() {
        record.archivedAt = nil
        record.updatedAt = .now
        context.insert(ConsultationWorkflowService.activity(
            record: record,
            kind: .reopened,
            title: "咨询师重新打开归档",
            detail: "后续改动需要再次人工批准和归档"
        ))
        do {
            try context.save()
            message = "归档已重新打开，所有后续操作仍会留痕"
        } catch {
            context.rollback()
            message = error.localizedDescription
        }
    }
}
