import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BrandDataCenterPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrandPublishRecord.createdAt, order: .reverse) private var publishRecords: [BrandPublishRecord]
    @Query(sort: \BrandMetricSnapshot.collectedAt, order: .reverse) private var snapshots: [BrandMetricSnapshot]

    @State private var metricTarget: BrandPublishRecord?
    @State private var showingImporter = false
    @State private var showingImportPreview = false
    @State private var importPreview: BrandMetricImportPreview?
    @State private var importFileName = ""
    @State private var message = ""
    @State private var showingMessage = false

    private var publishedRecords: [BrandPublishRecord] {
        publishRecords.filter(\.isPublished)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            card("数据采集原则", icon: "checkmark.shield.fill") {
                Text("数据快照只新增、不覆盖。缺失指标保持“未提供”，不会自动写成 0；只有人工确认快照进入复盘。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                #if os(macOS)
                HStack {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入 CSV / 制表符表格", systemImage: "tablecells")
                    }
                    .buttonStyle(.borderedProminent)
                    Text("当前直接读取 CSV/制表符文本；Excel 可先另存为 CSV。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }

            if publishedRecords.isEmpty {
                card("暂无可采集内容", icon: "chart.bar.doc.horizontal") {
                    Text("先在发布日历登记实际发布，数据中心才会接受该内容的指标快照。")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(publishedRecords) { record in
                    let recordSnapshots = snapshots.filter { $0.publishRecordID == record.id }
                    let latest = recordSnapshots.first
                    card(record.snapshotTitle.isEmpty ? "未命名发布记录" : record.snapshotTitle, icon: record.channel.icon) {
                        HStack {
                            StatusBadge(text: record.channel.rawValue, color: BrandTheme.teal)
                            Text(record.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "发布时间未提供")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("新增快照") { metricTarget = record }
                                .buttonStyle(.borderedProminent)
                        }
                        if let latest {
                            Divider()
                            Text("最新快照 · \(latest.collectedAt.formatted(date: .abbreviated, time: .shortened)) · \(latest.method.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                metric("曝光", latest.exposure)
                                metric("阅读/播放", latest.views)
                                metric("点赞", latest.likes)
                                metric("评论", latest.comments)
                                metric("收藏", latest.favorites)
                                metric("分享", latest.shares)
                                metric("主页访问", latest.profileVisits)
                                metric("新增关注", latest.followers)
                                metric("私信/询盘", latest.privateMessages)
                            }
                            if !latest.missingReasons.isEmpty {
                                Label(latest.missingReasons, systemImage: "info.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("共 \(recordSnapshots.count) 条历史快照；旧快照保留。")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("尚未录入数据，品牌首页会计入“待补数据”。")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .sheet(item: $metricTarget) { record in
            BrandMetricEntrySheet(record: record)
        }
        .sheet(isPresented: $showingImportPreview) {
            if let importPreview {
                BrandMetricImportPreviewSheet(
                    preview: importPreview,
                    fileName: importFileName,
                    publishRecords: publishedRecords
                ) { importedCount in
                    message = "已新增并确认 \(importedCount) 条数据快照。"
                    showingMessage = true
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("数据中心", isPresented: $showingMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private func metric(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map(String.init) ?? "未提供")
                .font(.headline.monospacedDigit())
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandTheme.mist.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let text = try String(contentsOf: url, encoding: .utf8)
            importPreview = try BrandMetricImportService.preview(text: text)
            importFileName = url.lastPathComponent
            showingImportPreview = true
        } catch {
            message = error.localizedDescription
            showingMessage = true
        }
    }
}

private struct BrandMetricEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let record: BrandPublishRecord

    @State private var collectedAt = Date.now
    @State private var periodStart: Date
    @State private var periodEnd = Date.now
    @State private var exposure = ""
    @State private var views = ""
    @State private var likes = ""
    @State private var comments = ""
    @State private var favorites = ""
    @State private var shares = ""
    @State private var profileVisits = ""
    @State private var followers = ""
    @State private var privateMessages = ""
    @State private var missingReasons = ""
    @State private var confirmed = false
    @State private var errorMessage = ""

    init(record: BrandPublishRecord) {
        self.record = record
        _periodStart = State(initialValue: record.publishedAt ?? Date.now.addingTimeInterval(-86_400))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("发布内容") {
                    LabeledContent("标题", value: record.snapshotTitle)
                    LabeledContent("平台", value: record.channel.rawValue)
                }
                Section("数据范围") {
                    DatePicker("采集时间", selection: $collectedAt)
                    DatePicker("覆盖开始", selection: $periodStart)
                    DatePicker("覆盖结束", selection: $periodEnd)
                }
                Section("平台实际提供的指标") {
                    integerField("曝光", text: $exposure)
                    integerField("阅读/播放", text: $views)
                    integerField("点赞", text: $likes)
                    integerField("评论", text: $comments)
                    integerField("收藏", text: $favorites)
                    integerField("分享", text: $shares)
                    integerField("主页访问", text: $profileVisits)
                    integerField("新增关注", text: $followers)
                    integerField("私信/询盘", text: $privateMessages)
                    TextField("缺失字段与原因", text: $missingReasons, axis: .vertical)
                }
                Section("人工确认") {
                    Toggle("我已对照平台后台核对以上数据", isOn: $confirmed)
                    Text("保存后指标内容不可覆盖；后续更新请新增快照。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("新增数据快照")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存快照") { save() }.disabled(!confirmed) }
            }
        }
        .frame(minWidth: 520, minHeight: 680)
    }

    @ViewBuilder
    private func integerField(_ title: String, text: Binding<String>) -> some View {
        TextField("\(title)（未提供可留空）", text: text)
            .textFieldStyle(.roundedBorder)
        #if os(iOS)
            .keyboardType(.numberPad)
        #endif
    }

    private func save() {
        do {
            guard periodEnd > periodStart else { throw BrandMetricEntryError.invalidPeriod }
            let values = try [exposure, views, likes, comments, favorites, shares, profileVisits, followers, privateMessages]
                .map(parseOptionalInt)
            var reason = missingReasons.trimmingCharacters(in: .whitespacesAndNewlines)
            let labels = ["曝光", "阅读/播放", "点赞", "评论", "收藏", "分享", "主页访问", "新增关注", "私信/询盘"]
            let missing = zip(labels, values).compactMap { $0.1 == nil ? $0.0 : nil }
            if !missing.isEmpty && reason.isEmpty { reason = "未提供：\(missing.joined(separator: "、"))" }
            guard values.contains(where: { $0 != nil }) || !reason.isEmpty else {
                throw BrandMetricEntryError.noData
            }
            modelContext.insert(BrandMetricSnapshot(
                publishRecordID: record.id,
                collectedAt: collectedAt,
                periodStart: periodStart,
                periodEnd: periodEnd,
                method: .manual,
                exposure: values[0], views: values[1], likes: values[2], comments: values[3],
                favorites: values[4], shares: values[5], profileVisits: values[6], followers: values[7],
                privateMessages: values[8], missingReasons: reason, sourceFile: "人工录入", isConfirmed: true
            ))
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseOptionalInt(_ raw: String) throws -> Int? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        guard let value = Int(clean), value >= 0 else { throw BrandMetricEntryError.invalidInteger }
        return value
    }
}

private enum BrandMetricEntryError: LocalizedError {
    case invalidPeriod
    case invalidInteger
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidPeriod: return "覆盖结束必须晚于覆盖开始。"
        case .invalidInteger: return "指标只能填写大于等于 0 的整数。"
        case .noData: return "至少填写一个指标或缺失说明。"
        }
    }
}

private struct BrandMetricImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let preview: BrandMetricImportPreview
    let fileName: String
    let publishRecords: [BrandPublishRecord]
    let onImported: (Int) -> Void
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("导入文件") {
                    LabeledContent("文件", value: fileName)
                    LabeledContent("数据行", value: "\(preview.rows.count)")
                }
                Section("自动字段映射") {
                    Text(preview.mappedDescription).font(.callout.monospaced())
                    Text("确认导入后，每行会新增一条不可覆盖的已确认快照。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("确认表格导入")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("确认并新增快照") { importRows() } }
            }
        }
        .frame(minWidth: 560, minHeight: 430)
    }

    private func importRows() {
        do {
            let values = try BrandMetricImportService.makeSnapshots(
                from: preview,
                publishRecords: publishRecords,
                sourceFile: fileName
            )
            values.forEach(modelContext.insert)
            try modelContext.save()
            dismiss()
            onImported(values.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BrandAttributionPage: View {
    @Query(sort: \BrandMarketingTouchpoint.firstContactAt, order: .reverse) private var touchpoints: [BrandMarketingTouchpoint]
    @Query private var appointments: [Appointment]
    @Query private var orders: [ServiceOrder]
    @Query private var appointmentPayments: [PaymentTransaction]
    @Query private var orderPayments: [OrderPaymentTransaction]
    @Query private var publishRecords: [BrandPublishRecord]
    @State private var showingEditor = false

    private var week: DateInterval { BrandGrowthAnalyticsService.naturalWeek(containing: .now) }
    private var summary: BrandAttributionSummary {
        BrandGrowthAnalyticsService.attributionSummary(
            touchpoints: touchpoints,
            appointments: appointments,
            orders: orders,
            appointmentPayments: appointmentPayments,
            orderPayments: orderPayments,
            interval: week
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("询盘与成交归因").font(.title2.bold()).foregroundStyle(BrandTheme.deepGreen)
                    Text("只把有明确证据的客户关联到具体内容；不会覆盖客户原有来源字段。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingEditor = true } label: { Label("登记来源证据", systemImage: "link.badge.plus") }
                    .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                summaryCard("本周询盘", "\(summary.inquiryCount)", "bubble.left.and.bubble.right.fill")
                summaryCard("具体内容归因", "\(summary.contentAttributedClientCount)", "link.circle.fill")
                summaryCard("归因预约", "\(summary.appointmentCount)", "calendar.badge.checkmark")
                summaryCard("归因订单", "\(summary.orderCount)", "shippingbox.fill")
                summaryCard("现金净实收", summary.netCashCents.yuanText, "banknote.fill")
            }

            if touchpoints.isEmpty {
                card("暂无来源证据", icon: "person.crop.circle.badge.questionmark") {
                    Text("客户主动说明来源后，再登记具体平台、内容或“无法确认”。没有证据时系统不会猜测。")
                        .foregroundStyle(.secondary)
                }
            } else {
                card("来源证据记录", icon: "list.bullet.clipboard.fill") {
                    ForEach(touchpoints) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.clientCodeSnapshot) · \(item.clientNameSnapshot)").font(.headline)
                                Text(touchpointDescription(item)).font(.caption).foregroundStyle(.secondary)
                                if !item.confirmationMethod.isEmpty {
                                    Text("确认方式：\(item.confirmationMethod)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            StatusBadge(text: item.isActive ? item.evidence.rawValue : "历史记录", color: item.isActive ? evidenceColor(item.evidence) : .secondary)
                        }
                        Divider()
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("brand-attribution-evidence-list")
            }
        }
        .sheet(isPresented: $showingEditor) {
            BrandTouchpointEditorSheet()
        }
    }

    private func touchpointDescription(_ value: BrandMarketingTouchpoint) -> String {
        let channel = value.channel?.rawValue ?? "平台未确认"
        let title = value.publishRecordID.flatMap { id in publishRecords.first(where: { $0.id == id })?.snapshotTitle }
        return [channel, title, value.firstContactAt.formatted(date: .abbreviated, time: .shortened)]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func evidenceColor(_ value: BrandAttributionEvidence) -> Color {
        switch value {
        case .confirmedContent: return .green
        case .platformOnly: return .orange
        case .unattributed: return .secondary
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(BrandTheme.teal)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct BrandTouchpointEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.clientCode) private var clients: [Client]
    @Query(sort: \BrandPublishRecord.createdAt, order: .reverse) private var publishRecords: [BrandPublishRecord]
    @Query private var touchpoints: [BrandMarketingTouchpoint]

    @State private var clientID: UUID?
    @State private var evidence: BrandAttributionEvidence = .confirmedContent
    @State private var channelRaw = BrandDistributionChannel.wechatMoments.rawValue
    @State private var publishRecordID: UUID?
    @State private var keyword = ""
    @State private var firstContactAt = Date.now
    @State private var confirmationMethod = "客户主动说明"
    @State private var note = ""
    @State private var errorMessage = ""

    private var channel: BrandDistributionChannel? {
        BrandDistributionChannel(rawValue: channelRaw)
    }

    private var availableRecords: [BrandPublishRecord] {
        publishRecords.filter { $0.isPublished && $0.channel == channel }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("客户") {
                    Picker("客户", selection: $clientID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(clients.filter { !$0.isArchived }) { client in
                            Text("\(client.clientCode) · \(client.displayName)").tag(Optional(client.id))
                        }
                    }
                    DatePicker("首次联系时间", selection: $firstContactAt)
                }
                Section("证据强度") {
                    Picker("证据状态", selection: $evidence) {
                        ForEach(BrandAttributionEvidence.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("平台", selection: $channelRaw) {
                        Text("未确认平台").tag("")
                        ForEach(BrandDistributionChannel.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    if evidence == .confirmedContent {
                        Picker("具体发布内容", selection: $publishRecordID) {
                            Text("请选择").tag(UUID?.none)
                            ForEach(availableRecords) { record in
                                Text(record.snapshotTitle).tag(Optional(record.id))
                            }
                        }
                    }
                    TextField("客户主动提到的关键词", text: $keyword)
                    TextField("确认方式", text: $confirmationMethod)
                    TextField("备注", text: $note, axis: .vertical)
                }
                Text("保存会把该客户之前的来源证据标为历史记录，但不会删除；客户资料中的原来源字段保持不变。")
                    .font(.footnote).foregroundStyle(.secondary)
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("登记来源证据")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存证据") { save() } }
            }
        }
        .frame(minWidth: 540, minHeight: 560)
        .onChange(of: channelRaw) { _, _ in publishRecordID = nil }
        .onChange(of: evidence) { _, newValue in
            if newValue != .confirmedContent { publishRecordID = nil }
        }
    }

    private func save() {
        guard let clientID, let client = clients.first(where: { $0.id == clientID }) else {
            errorMessage = "请选择客户。"
            return
        }
        if evidence == .confirmedContent {
            guard let channel, let publishRecordID,
                  availableRecords.contains(where: { $0.id == publishRecordID }) else {
                errorMessage = "确认到具体内容时，必须选择平台和已发布内容。"
                return
            }
            _ = channel
        }
        touchpoints.filter { $0.clientID == clientID && $0.isActive }.forEach {
            $0.isActive = false
            $0.updatedAt = .now
        }
        modelContext.insert(BrandMarketingTouchpoint(
            clientID: client.id,
            clientCodeSnapshot: client.clientCode,
            clientNameSnapshot: client.displayName,
            channel: channel,
            publishRecordID: evidence == .confirmedContent ? publishRecordID : nil,
            keyword: keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            firstContactAt: firstContactAt,
            evidence: evidence,
            confirmationMethod: confirmationMethod.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BrandWeeklyReviewPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrandWeeklyReview.periodStart, order: .reverse) private var reviews: [BrandWeeklyReview]
    @Query private var publishRecords: [BrandPublishRecord]
    @Query private var snapshots: [BrandMetricSnapshot]
    @Query private var touchpoints: [BrandMarketingTouchpoint]
    @Query private var appointments: [Appointment]
    @Query private var orders: [ServiceOrder]
    @Query private var appointmentPayments: [PaymentTransaction]
    @Query private var orderPayments: [OrderPaymentTransaction]
    @State private var editingReview: BrandWeeklyReview?
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("每周复盘").font(.title2.bold()).foregroundStyle(BrandTheme.deepGreen)
                    Text("默认自然周（周一至周日），每周一 09:00 生成待人工确认复盘。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("下一次计划：\(BrandGrowthAnalyticsService.nextPlannedReview().formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Button("生成上周复盘") { generate(interval: BrandGrowthAnalyticsService.previousNaturalWeek()) }
                    Button("生成本周预览") { generate(interval: BrandGrowthAnalyticsService.naturalWeek(containing: .now)) }
                        .buttonStyle(.borderedProminent)
                }
            }

            if reviews.isEmpty {
                reviewCard(title: "暂无复盘", icon: "doc.text.magnifyingglass") {
                    Text("生成后会明确区分事实、解释、建议和数据缺口；系统不会用 AI 猜测缺失数据。")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(reviews) { review in
                    Button { editingReview = review } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(review.periodStart.formatted(date: .abbreviated, time: .omitted)) — \(review.periodEnd.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                                    .font(.headline).foregroundStyle(.primary)
                                Spacer()
                                StatusBadge(text: review.status.rawValue, color: review.status == .completed ? .green : .orange)
                            }
                            Text(review.summaryText).font(.caption).foregroundStyle(.secondary).lineLimit(4)
                            Text("使用快照：\(snapshotCount(review)) 条")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("brand-weekly-review-row")
                }
            }
        }
        .sheet(item: $editingReview) { review in
            BrandWeeklyReviewEditorSheet(review: review)
        }
        .alert("每周复盘", isPresented: $showingError) {
            Button("知道了", role: .cancel) {}
        } message: { Text(errorMessage) }
    }

    private func generate(interval: DateInterval) {
        let draft = BrandGrowthAnalyticsService.makeWeeklyReview(
            interval: interval,
            publishRecords: publishRecords,
            snapshots: snapshots,
            touchpoints: touchpoints,
            appointments: appointments,
            orders: orders,
            appointmentPayments: appointmentPayments,
            orderPayments: orderPayments
        )
        let existing = reviews.first { abs($0.periodStart.timeIntervalSince(interval.start)) < 1 }
        let review: BrandWeeklyReview
        if let existing, existing.status == .drafting {
            review = existing
            apply(draft, to: review)
        } else if existing != nil {
            errorMessage = "该周期复盘已人工确认，不会被重新生成覆盖。"
            showingError = true
            return
        } else {
            review = BrandWeeklyReview(periodStart: draft.periodStart, periodEnd: draft.periodEnd)
            apply(draft, to: review)
            modelContext.insert(review)
        }
        do {
            try modelContext.save()
            editingReview = review
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func apply(_ draft: BrandWeeklyReviewDraft, to review: BrandWeeklyReview) {
        review.periodStart = draft.periodStart
        review.periodEnd = draft.periodEnd
        review.plannedGenerateAt = draft.plannedGenerateAt
        review.generatedAt = draft.generatedAt
        review.summaryText = draft.facts
        review.conclusionText = draft.interpretation
        review.bestText = draft.best
        review.worstText = draft.worst
        review.conversionText = draft.conversion
        review.channelWechatRole = draft.wechatRole
        review.channelXhsRole = draft.xiaohongshuRole
        review.dataGapText = draft.dataGaps
        review.continueText = draft.continueDoing
        review.stopText = draft.stopDoing
        review.experimentText = draft.experiments
        review.usedSnapshotIDsText = draft.usedSnapshotIDs.map(\.uuidString).joined(separator: "\n")
        review.status = .drafting
        review.approvedAt = nil
        review.approvedBy = ""
        review.updatedAt = .now
    }

    private func snapshotCount(_ review: BrandWeeklyReview) -> Int {
        review.usedSnapshotIDsText?.split(separator: "\n").count ?? 0
    }

    private func reviewCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct BrandWeeklyReviewEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let review: BrandWeeklyReview
    @State private var facts: String
    @State private var interpretation: String
    @State private var dataGaps: String
    @State private var continueDoing: String
    @State private var stopDoing: String
    @State private var experiments: String
    @State private var errorMessage = ""

    init(review: BrandWeeklyReview) {
        self.review = review
        _facts = State(initialValue: review.summaryText)
        _interpretation = State(initialValue: review.conclusionText)
        _dataGaps = State(initialValue: review.dataGapText)
        _continueDoing = State(initialValue: review.continueText)
        _stopDoing = State(initialValue: review.stopText)
        _experiments = State(initialValue: review.experimentText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("事实") { TextEditor(text: $facts).frame(minHeight: 110) }
                Section("解释") { TextEditor(text: $interpretation).frame(minHeight: 90) }
                Section("数据缺口") { TextEditor(text: $dataGaps).frame(minHeight: 90) }
                Section("建议") {
                    TextField("继续事项", text: $continueDoing, axis: .vertical)
                    TextField("停止事项", text: $stopDoing, axis: .vertical)
                    TextEditor(text: $experiments).frame(minHeight: 110)
                }
                Section("平台与转化事实") {
                    LabeledContent("朋友圈", value: review.channelWechatRole)
                    LabeledContent("小红书", value: review.channelXhsRole)
                    Text(review.conversionText)
                }
                Text("人工确认后，该周期复盘不会再被自动生成覆盖。")
                    .font(.footnote).foregroundStyle(.secondary)
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("周复盘确认")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                if review.status == .drafting {
                    ToolbarItem(placement: .confirmationAction) { Button("保存并确认") { approve() } }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 760)
    }

    private func approve() {
        review.summaryText = facts
        review.conclusionText = interpretation
        review.dataGapText = dataGaps
        review.continueText = continueDoing
        review.stopText = stopDoing
        review.experimentText = experiments
        review.status = .completed
        review.approvedAt = .now
        review.approvedBy = "本机使用者"
        review.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
