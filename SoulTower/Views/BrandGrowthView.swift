import SwiftUI
import SwiftData

private enum BrandGrowthPage: String, CaseIterable, Identifiable {
    case overview = "品牌首页"
    case content = "内容工作台"
    case calendar = "发布日历"
    case data = "数据中心"
    case attribution = "询盘归因"
    case weeklyReview = "每周复盘"
    case settings = "品牌设置"

    var id: String { rawValue }
}

struct BrandGrowthView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \BrandProfile.updatedAt, order: .reverse) private var profiles: [BrandProfile]
    @Query(sort: \BrandContentTopic.updatedAt, order: .reverse) private var topics: [BrandContentTopic]
    @Query(sort: \BrandDraft.updatedAt, order: .reverse) private var drafts: [BrandDraft]
    @Query(sort: \BrandDraftRevision.savedAt, order: .reverse) private var revisions: [BrandDraftRevision]
    @Query(sort: \BrandPublishRecord.createdAt, order: .reverse) private var publishRecords: [BrandPublishRecord]
    @Query(sort: \BrandMetricSnapshot.collectedAt, order: .reverse) private var metricSnapshots: [BrandMetricSnapshot]
    @Query private var touchpoints: [BrandMarketingTouchpoint]
    @Query private var appointments: [Appointment]
    @Query private var serviceOrders: [ServiceOrder]
    @Query private var appointmentPayments: [PaymentTransaction]
    @Query private var orderPayments: [OrderPaymentTransaction]

    @State private var page: BrandGrowthPage = .overview
    @State private var selectedTopicID: UUID?
    @State private var showingNewTopic = false
    @State private var editingDraft: BrandDraft?
    @State private var schedulingDraft: BrandDraft?
    @State private var editingPublishRecord: BrandPublishRecord?
    @State private var showingProfileEditor = false
    @State private var isGenerating = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private var activeProfile: BrandProfile? {
        profiles.first(where: \.isActive) ?? profiles.first
    }

    private var selectedTopic: BrandContentTopic? {
        if let selectedTopicID, let topic = topics.first(where: { $0.id == selectedTopicID }) {
            return topic
        }
        return topics.first(where: { !$0.isArchived })
    }

    var body: some View {
        ZStack {
            BrandBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    #if os(macOS)
                    Picker("品牌增长页面", selection: $page) {
                        ForEach(BrandGrowthPage.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    #else
                    Picker("当前页面", selection: $page) {
                        ForEach(BrandGrowthPage.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("brand-page-picker")
                    #endif

                    switch page {
                    case .overview:
                        overviewPage
                    case .content:
                        contentPage
                    case .calendar:
                        calendarPage
                    case .data:
                        BrandDataCenterPage()
                    case .attribution:
                        BrandAttributionPage()
                    case .weeklyReview:
                        BrandWeeklyReviewPage()
                    case .settings:
                        settingsPage
                    }
                }
                .padding(20)
                .frame(maxWidth: 1_100, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("品牌增长")
        .sheet(isPresented: $showingNewTopic) {
            if let activeProfile {
                NewBrandTopicSheet(profile: activeProfile) { topicID in
                    selectedTopicID = topicID
                    page = .content
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            if let activeProfile {
                BrandDraftEditorSheet(draft: draft, profile: activeProfile)
            }
        }
        .sheet(item: $schedulingDraft) { draft in
            ScheduleBrandDraftSheet(draft: draft)
        }
        .sheet(item: $editingPublishRecord) { record in
            BrandPublishRecordEditorSheet(record: record)
        }
        .sheet(isPresented: $showingProfileEditor) {
            BrandProfileEditorSheet(current: activeProfile, existingProfiles: profiles)
        }
        .alert("品牌增长", isPresented: $showingAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("品牌增长工作台")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrandTheme.deepGreen)
                Text("品牌定位 → 选题 → 两平台独立草稿 → 人工批准 → 发布留痕")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingNewTopic = true
            } label: {
                Label("新建选题", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(activeProfile == nil)
        }
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            if activeProfile == nil {
                emptyProfileNotice
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                metricCard("进行中选题", value: topics.filter { !$0.isArchived && $0.status != .completed }.count, icon: "lightbulb.fill", tint: BrandTheme.gold)
                metricCard("待人工审批", value: drafts.filter { $0.status == .waitingApproval }.count, icon: "person.crop.circle.badge.checkmark", tint: .orange)
                metricCard("已批准待安排", value: approvedUnscheduledCount, icon: "calendar.badge.plus", tint: BrandTheme.teal)
                metricCard("待补平台数据", value: publishedWithoutConfirmedSnapshotCount, icon: "chart.bar.doc.horizontal", tint: .orange)
                metricCard("本周询盘", value: currentWeekAttribution.inquiryCount, icon: "bubble.left.and.bubble.right.fill", tint: BrandTheme.teal)
                metricCard("本周归因预约", value: currentWeekAttribution.appointmentCount, icon: "calendar.badge.checkmark", tint: .green)
                metricCard("本周归因成交", value: currentWeekAttribution.orderCount, icon: "shippingbox.fill", tint: .green)
            }

            sectionCard(title: "本周品牌现金结果", icon: "banknote.fill") {
                Text(currentWeekAttribution.netCashCents.yuanText)
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(BrandTheme.teal)
                Text("仅计算已确认到具体内容的客户，并读取现有预约/订单真实流水；未确认来源不计入。")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            sectionCard(title: "本周工作重点", icon: "checklist") {
                if topics.isEmpty {
                    Text("还没有选题。先建立一个真实观点，系统会同时准备朋友圈和小红书两个独立版本。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(topics.filter { !$0.isArchived }.prefix(5))) { topic in
                        Button {
                            selectedTopicID = topic.id
                            page = .content
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(topic.title).foregroundStyle(.primary)
                                    Text("\(topic.pillar) · \(topic.goal.rawValue) · \(topic.sourceType.rawValue)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }

            sectionCard(title: "首阶段边界", icon: "shield.lefthalf.filled") {
                Label("只使用个人观点、公开资料和品牌自有素材", systemImage: "checkmark.circle.fill")
                Label("AI 草稿必须逐平台人工批准，系统不自动发布", systemImage: "checkmark.circle.fill")
                Label("数据快照只新增不覆盖，缺失值不补 0；归因必须有人工证据", systemImage: "checkmark.circle.fill")
                Label("客户案例、私聊监控、非官方爬取和无人审核发布均未启用", systemImage: "nosign")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contentPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let activeProfile {
                topicSelector
                if let selectedTopic {
                    topicSummary(selectedTopic)
                    draftWorkspace(topic: selectedTopic, profile: activeProfile)
                } else {
                    sectionCard(title: "内容工作台", icon: "square.and.pencil") {
                        Text("新建选题后，这里会出现朋友圈和小红书两个独立草稿。")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                emptyProfileNotice
            }
        }
    }

    private var topicSelector: some View {
        sectionCard(title: "选题库", icon: "lightbulb.max.fill") {
            if topics.isEmpty {
                Text("暂无选题").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(topics.filter { !$0.isArchived }) { topic in
                            Button(topic.title) { selectedTopicID = topic.id }
                                .buttonStyle(.bordered)
                                .tint(selectedTopic?.id == topic.id ? BrandTheme.teal : .secondary)
                        }
                    }
                }
            }
        }
    }

    private func topicSummary(_ topic: BrandContentTopic) -> some View {
        sectionCard(title: topic.title, icon: "quote.bubble.fill") {
            Text(topic.rawIdea).textSelection(.enabled)
            HStack {
                StatusBadge(text: topic.goal.rawValue, color: BrandTheme.teal)
                StatusBadge(text: topic.sourceType.rawValue, color: BrandTheme.gold)
                StatusBadge(text: topic.status.rawValue, color: .secondary)
            }
            Text("目标人群：\(topic.targetAudience)")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func draftWorkspace(topic: BrandContentTopic, profile: BrandProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("平台草稿").font(.title2.bold())
                Spacer()
                #if os(macOS)
                Button {
                    generateDrafts(topic: topic, profile: profile)
                } label: {
                    Label(isGenerating ? "本地 AI 生成中…" : "生成两个平台草稿", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
                #endif
            }

            #if os(iOS)
            Text("iPhone 可人工编辑、逐平台批准和登记发布；本地 AI 生成请在 Mac 完成。")
                .font(.footnote).foregroundStyle(.secondary)
            #endif

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(BrandDistributionChannel.allCases) { channel in
                    if let draft = drafts.first(where: { $0.topicID == topic.id && $0.channel == channel }) {
                        draftCard(draft, profile: profile)
                    }
                }
            }
        }
    }

    private func draftCard(_ draft: BrandDraft, profile: BrandProfile) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(draft.channel.rawValue, systemImage: draft.channel.icon)
                    .font(.headline)
                Spacer()
                StatusBadge(text: draft.status.rawValue, color: draftStatusColor(draft.status))
            }
            Text(draft.title.isEmpty ? "尚未填写标题" : draft.title)
                .font(.title3.bold())
            Text(draft.content.isEmpty ? "可先人工编辑；Mac 也可以调用已配置的本地 AI。" : draft.content)
                .font(.subheadline)
                .foregroundStyle(draft.content.isEmpty ? .secondary : .primary)
                .lineLimit(6)

            if !draft.riskWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(draft.riskWarnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            let historyCount = revisions.filter { $0.draftID == draft.id }.count
            Text("当前 V\(draft.version) · 历史 \(historyCount) 个版本")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("编辑") { editingDraft = draft }
                if draft.isApproved {
                    Button("安排发布") { schedulingDraft = draft }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("单独批准") { approve(draft, profile: profile) }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var calendarPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "发布日历与实际发布记录", icon: "calendar") {
                Text("只有已人工批准的平台版本才能排期。实际发布仍在外部平台完成，回来登记时间、链接或内容编号。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if publishRecords.isEmpty {
                sectionCard(title: "暂无排期", icon: "calendar.badge.plus") {
                    Text("回到内容工作台，单独批准某个平台草稿后点击“安排发布”。")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(publishRecords.sorted { $0.effectiveDate < $1.effectiveDate }) { record in
                    Button {
                        editingPublishRecord = record
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: record.channel.icon)
                                .frame(width: 28).foregroundStyle(BrandTheme.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.snapshotTitle.isEmpty ? "未命名发布记录" : record.snapshotTitle)
                                    .font(.headline).foregroundStyle(.primary)
                                Text("\(record.channel.rawValue) · \(record.effectiveDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: record.isPublished ? "已发布" : "待发布", color: record.isPublished ? .green : .orange)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(15)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let profile = activeProfile {
                sectionCard(title: "当前品牌档案 · \(profile.profileVersion)", icon: "person.text.rectangle.fill") {
                    LabeledContent("品牌名称", value: profile.brandName)
                    LabeledContent("一句话定位", value: profile.oneLinePositioning)
                    LabeledContent("目标人群", value: profile.targetAudience)
                    LabeledContent("品牌语气", value: profile.tone)
                    LabeledContent("禁用表达", value: profile.forbiddenWords)
                    Button("建立新版本") { showingProfileEditor = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                emptyProfileNotice
            }

            sectionCard(title: "品牌档案历史", icon: "clock.arrow.circlepath") {
                ForEach(profiles) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(profile.profileVersion) · \(profile.brandName)")
                            Text(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile.isActive {
                            StatusBadge(text: "当前生效", color: .green)
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private var emptyProfileNotice: some View {
        sectionCard(title: "需要品牌档案", icon: "exclamationmark.triangle.fill") {
            Text("先建立品牌定位、目标人群、语气和禁用表达，才能创建选题。")
            Button("建立品牌档案") { showingProfileEditor = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var approvedUnscheduledCount: Int {
        drafts.filter { draft in
            draft.isApproved && !publishRecords.contains(where: { $0.draftID == draft.id })
        }.count
    }

    private var publishedWithoutConfirmedSnapshotCount: Int {
        publishRecords.filter(\.isPublished).filter { record in
            !metricSnapshots.contains { $0.publishRecordID == record.id && $0.isConfirmed }
        }.count
    }

    private var currentWeekAttribution: BrandAttributionSummary {
        BrandGrowthAnalyticsService.attributionSummary(
            touchpoints: touchpoints,
            appointments: appointments,
            orders: serviceOrders,
            appointmentPayments: appointmentPayments,
            orderPayments: orderPayments,
            interval: BrandGrowthAnalyticsService.naturalWeek(containing: .now)
        )
    }

    private func metricCard(_ title: String, value: Int, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text("\(value)").font(.largeTitle.bold().monospacedDigit()).foregroundStyle(tint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(BrandTheme.deepGreen)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func approve(_ draft: BrandDraft, profile: BrandProfile) {
        do {
            try BrandGrowthWorkflowService.approve(draft, profile: profile, by: "本机使用者")
            let topicDrafts = drafts.filter { $0.topicID == draft.topicID }
            if topicDrafts.count == BrandDistributionChannel.allCases.count,
               topicDrafts.allSatisfy(\.isApproved),
               let topic = topics.first(where: { $0.id == draft.topicID }) {
                topic.status = .waitingForPublish
                topic.updatedAt = .now
            }
            try modelContext.save()
        } catch {
            present(error.localizedDescription)
        }
    }

    private func generateDrafts(topic: BrandContentTopic, profile: BrandProfile) {
        #if os(macOS)
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let bundle = try await BrandGrowthAIService.generateDraftBundle(
                    for: topic,
                    profile: profile,
                    baseURL: appState.aiBaseURL,
                    modelName: appState.aiModelName
                )
                applyGenerated(bundle.wechat, channel: .wechatMoments, topic: topic, profile: profile)
                applyGenerated(bundle.xiaohongshu, channel: .xiaohongshu, topic: topic, profile: profile)
                try modelContext.save()
            } catch {
                present(error.localizedDescription)
            }
        }
        #endif
    }

    private func applyGenerated(_ payload: BrandDraftPayload, channel: BrandDistributionChannel, topic: BrandContentTopic, profile: BrandProfile) {
        guard let draft = drafts.first(where: { $0.topicID == topic.id && $0.channel == channel }) else { return }
        if !draft.title.isEmpty || !draft.content.isEmpty {
            modelContext.insert(BrandDraftRevision(draft: draft))
        }
        let deterministic = BrandGrowthRiskService.evaluate(
            title: payload.title,
            content: [payload.subtitle, payload.opening, payload.body, payload.actionPrompt].joined(separator: "\n"),
            profile: profile
        )
        let checked = BrandDraftPayload(
            title: payload.title,
            subtitle: payload.subtitle,
            opening: payload.opening,
            body: payload.body,
            actionPrompt: payload.actionPrompt,
            imageSuggestion: payload.imageSuggestion,
            searchTitles: payload.searchTitles,
            resonanceTitles: payload.resonanceTitles,
            keywords: payload.keywords,
            hashtags: payload.hashtags,
            riskWarnings: Array(Set(payload.riskWarnings + deterministic)).sorted()
        )
        draft.apply(checked, source: .ai, modelName: appState.aiModelName, profileVersion: profile.profileVersion)
    }

    private func present(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    private func draftStatusColor(_ status: BrandDraftStatus) -> Color {
        switch status {
        case .drafting: return .secondary
        case .waitingApproval: return .orange
        case .approved: return .green
        case .deprecated: return .red
        }
    }
}

private struct NewBrandTopicSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let profile: BrandProfile
    let onCreated: (UUID) -> Void

    @State private var title = ""
    @State private var rawIdea = ""
    @State private var targetAudience = ""
    @State private var pillar = "情绪与关系洞察"
    @State private var goal: BrandTopicGoal = .trust
    @State private var source: BrandTopicSource = .personalOpinion
    @State private var actionHint = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("选题") {
                    TextField("选题标题", text: $title)
                    TextField("原始观点", text: $rawIdea, axis: .vertical).lineLimit(4...10)
                    TextField("目标人群", text: $targetAudience)
                    TextField("内容支柱", text: $pillar)
                    Picker("目标", selection: $goal) {
                        ForEach(BrandTopicGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("来源", selection: $source) {
                        ForEach(BrandTopicSource.allCases.filter(\.availableInM1)) { Text($0.rawValue).tag($0) }
                    }
                    TextField("行动提示", text: $actionHint)
                }
                Section("M1 来源边界") {
                    Text("客户共性主题和历史内容复用暂未启用；不能放入客户姓名、私聊、录音或其他身份信息。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("新建选题")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("建立") { create() } }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }

    private func create() {
        do {
            try BrandGrowthWorkflowService.validateM1Source(source)
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanIdea = rawIdea.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty, !cleanIdea.isEmpty else {
                errorMessage = "选题标题和原始观点不能为空。"
                return
            }
            let topic = BrandContentTopic(
                profileID: profile.id,
                title: cleanTitle,
                rawIdea: cleanIdea,
                targetAudience: targetAudience.isEmpty ? profile.targetAudience : targetAudience,
                pillar: pillar,
                goal: goal,
                sourceType: source,
                sensitivity: "公开/品牌内容",
                customerReference: "",
                actionHint: actionHint,
                priority: 2
            )
            modelContext.insert(topic)
            for channel in BrandDistributionChannel.allCases {
                modelContext.insert(BrandDraft(topicID: topic.id, channel: channel, profileVersion: profile.profileVersion))
            }
            try modelContext.save()
            onCreated(topic.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BrandDraftEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let draft: BrandDraft
    let profile: BrandProfile

    @State private var title: String
    @State private var subtitle: String
    @State private var opening: String
    @State private var content: String
    @State private var actionPrompt: String
    @State private var imageSuggestion: String
    @State private var keywordsText: String
    @State private var hashtagText: String
    @State private var searchTitleText: String
    @State private var resonanceTitleText: String
    @State private var errorMessage = ""

    init(draft: BrandDraft, profile: BrandProfile) {
        self.draft = draft
        self.profile = profile
        _title = State(initialValue: draft.title)
        _subtitle = State(initialValue: draft.subtitle)
        _opening = State(initialValue: draft.opening)
        _content = State(initialValue: draft.content)
        _actionPrompt = State(initialValue: draft.actionPrompt)
        _imageSuggestion = State(initialValue: draft.imageSuggestion)
        _keywordsText = State(initialValue: draft.keywordsText)
        _hashtagText = State(initialValue: draft.hashtagText)
        _searchTitleText = State(initialValue: draft.searchTitleText)
        _resonanceTitleText = State(initialValue: draft.resonanceTitleText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(draft.channel.rawValue) · 当前 V\(draft.version)") {
                    TextField("标题", text: $title)
                    TextField("副标题/封面短句", text: $subtitle)
                    TextField("开头", text: $opening, axis: .vertical).lineLimit(2...5)
                    TextField("正文", text: $content, axis: .vertical).lineLimit(8...20)
                    TextField("结尾行动提示", text: $actionPrompt, axis: .vertical).lineLimit(2...5)
                    TextField("配图建议", text: $imageSuggestion, axis: .vertical).lineLimit(2...5)
                }
                if draft.channel == .xiaohongshu {
                    Section("小红书独立结构") {
                        TextField("搜索型标题（每行一个）", text: $searchTitleText, axis: .vertical).lineLimit(2...6)
                        TextField("共鸣型标题（每行一个）", text: $resonanceTitleText, axis: .vertical).lineLimit(2...6)
                        TextField("关键词", text: $keywordsText)
                        TextField("话题", text: $hashtagText)
                    }
                }
                Section("保存规则") {
                    Text("保存前会保留旧版本。修改已批准草稿会立即撤销批准，必须重新单独审批。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("编辑平台草稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存新版本") { save() } }
            }
        }
        .frame(minWidth: 520, minHeight: 680)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanContent.isEmpty else {
            errorMessage = "标题和正文不能为空。"
            return
        }
        let changed = cleanTitle != draft.title || subtitle != draft.subtitle || opening != draft.opening
            || cleanContent != draft.content || actionPrompt != draft.actionPrompt || imageSuggestion != draft.imageSuggestion
            || keywordsText != draft.keywordsText || hashtagText != draft.hashtagText
            || searchTitleText != draft.searchTitleText || resonanceTitleText != draft.resonanceTitleText
        guard changed else { dismiss(); return }

        if !draft.title.isEmpty || !draft.content.isEmpty {
            modelContext.insert(BrandDraftRevision(draft: draft))
        }
        let retainedAIWarnings = draft.riskWarnings.filter {
            !$0.hasPrefix("禁止批准：") && $0 != "已修改草稿，需重新审批"
        }
        let deterministic = BrandGrowthRiskService.evaluate(
            title: cleanTitle,
            content: [subtitle, opening, cleanContent, actionPrompt].joined(separator: "\n"),
            profile: profile
        )
        draft.title = cleanTitle
        draft.subtitle = subtitle
        draft.opening = opening
        draft.content = cleanContent
        draft.actionPrompt = actionPrompt
        draft.imageSuggestion = imageSuggestion
        draft.keywordsText = keywordsText
        draft.hashtagText = hashtagText
        draft.searchTitleText = searchTitleText
        draft.resonanceTitleText = resonanceTitleText
        draft.riskWarningsText = Array(Set(retainedAIWarnings + deterministic + ["已修改草稿，需重新审批"])).sorted().joined(separator: "\n")
        draft.source = .manual
        draft.status = .waitingApproval
        draft.approvedAt = nil
        draft.approvedBy = ""
        draft.profileVersion = profile.profileVersion
        draft.version += 1
        draft.updatedAt = .now
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ScheduleBrandDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let draft: BrandDraft
    @State private var plannedAt = Date().addingTimeInterval(86_400)
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("平台", value: draft.channel.rawValue)
                LabeledContent("批准版本", value: "V\(draft.version)")
                DatePicker("计划发布时间", selection: $plannedAt)
                Text("排期会保存当前批准文本快照，不会操作外部平台。")
                    .font(.footnote).foregroundStyle(.secondary)
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("安排发布")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("加入日历") { schedule() } }
            }
        }
        .frame(minWidth: 420, minHeight: 300)
    }

    private func schedule() {
        do {
            let record = try BrandGrowthWorkflowService.makePublishRecord(from: draft, plannedAt: plannedAt)
            modelContext.insert(record)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BrandPublishRecordEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var topics: [BrandContentTopic]
    @Query private var allPublishRecords: [BrandPublishRecord]
    let record: BrandPublishRecord
    @State private var isPublished: Bool
    @State private var publishedAt: Date
    @State private var platformPostID: String
    @State private var platformLink: String
    @State private var note: String
    @State private var publishedAsApproved: Bool
    @State private var errorMessage = ""

    init(record: BrandPublishRecord) {
        self.record = record
        _isPublished = State(initialValue: record.isPublished)
        _publishedAt = State(initialValue: record.publishedAt ?? .now)
        _platformPostID = State(initialValue: record.platformPostID)
        _platformLink = State(initialValue: record.platformLink)
        _note = State(initialValue: record.note)
        _publishedAsApproved = State(initialValue: record.publishedAsApproved)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("批准文本快照") {
                    Text(record.snapshotTitle).font(.headline)
                    Text(record.snapshotContent).textSelection(.enabled)
                }
                Section("外部平台登记") {
                    Toggle("已经在平台发布", isOn: $isPublished)
                    if isPublished {
                        DatePicker("实际发布时间", selection: $publishedAt)
                        TextField("平台内容编号", text: $platformPostID)
                        TextField("链接", text: $platformLink)
                        TextField("备注", text: $note, axis: .vertical).lineLimit(2...6)
                        Toggle("实际发布内容与批准版一致", isOn: $publishedAsApproved)
                    }
                }
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("发布记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func save() {
        if isPublished && platformPostID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && platformLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "发布后至少填写链接、内容编号或备注之一。"
            return
        }
        record.publishedAt = isPublished ? publishedAt : nil
        record.platformPostID = platformPostID
        record.platformLink = platformLink
        record.note = note
        record.publishedAsApproved = publishedAsApproved
        record.updatedAt = .now
        if isPublished,
           let topic = topics.first(where: { $0.id == record.topicID }) {
            let publishedChannels = Set(allPublishRecords
                .filter { $0.topicID == record.topicID && $0.isPublished }
                .map(\.channelRaw))
            if publishedChannels.count == BrandDistributionChannel.allCases.count {
                topic.status = .completed
                topic.updatedAt = .now
            }
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BrandProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let current: BrandProfile?
    let existingProfiles: [BrandProfile]

    @State private var brandName: String
    @State private var positioning: String
    @State private var targetAudience: String
    @State private var valuePromise: String
    @State private var tone: String
    @State private var commonWords: String
    @State private var forbiddenWords: String
    @State private var serviceScope: String
    @State private var notSuitableFor: String
    @State private var pillars: String
    @State private var wechatIntro: String
    @State private var xiaohongshuIntro: String
    @State private var signature: String
    @State private var version: String
    @State private var errorMessage = ""

    init(current: BrandProfile?, existingProfiles: [BrandProfile]) {
        let base = current ?? BrandProfile.defaultProfile()
        self.current = current
        self.existingProfiles = existingProfiles
        _brandName = State(initialValue: base.brandName)
        _positioning = State(initialValue: base.oneLinePositioning)
        _targetAudience = State(initialValue: base.targetAudience)
        _valuePromise = State(initialValue: base.valuePromise)
        _tone = State(initialValue: base.tone)
        _commonWords = State(initialValue: base.commonWords)
        _forbiddenWords = State(initialValue: base.forbiddenWords)
        _serviceScope = State(initialValue: base.serviceScope)
        _notSuitableFor = State(initialValue: base.notSuitableFor)
        _pillars = State(initialValue: base.pillars)
        _wechatIntro = State(initialValue: base.wechatIntro)
        _xiaohongshuIntro = State(initialValue: base.xiaohongshuIntro)
        _signature = State(initialValue: base.signature)
        _version = State(initialValue: "V1.0.\(existingProfiles.count + 1)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("版本") { TextField("版本号", text: $version) }
                Section("品牌定位") {
                    TextField("品牌名称", text: $brandName)
                    TextField("一句话定位", text: $positioning)
                    TextField("目标人群", text: $targetAudience, axis: .vertical)
                    TextField("核心承诺", text: $valuePromise, axis: .vertical)
                    TextField("品牌语气", text: $tone)
                    TextField("常用表达", text: $commonWords)
                    TextField("禁用表达", text: $forbiddenWords)
                }
                Section("边界与栏目") {
                    TextField("服务范围", text: $serviceScope, axis: .vertical)
                    TextField("不适用范围", text: $notSuitableFor, axis: .vertical)
                    TextField("内容支柱与目标", text: $pillars, axis: .vertical).lineLimit(3...8)
                }
                Section("平台简介") {
                    TextField("微信简介", text: $wechatIntro, axis: .vertical)
                    TextField("小红书简介", text: $xiaohongshuIntro, axis: .vertical)
                    TextField("统一落款", text: $signature)
                }
                Text("保存会建立新档案版本，旧版本保留但停止生效。已有草稿继续记录其生成时使用的档案版本。")
                    .font(.footnote).foregroundStyle(.secondary)
                if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("品牌档案新版本")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存并生效") { save() } }
            }
        }
        .frame(minWidth: 540, minHeight: 720)
    }

    private func save() {
        let cleanVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !positioning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !cleanVersion.isEmpty else {
            errorMessage = "品牌名称、定位和版本号不能为空。"
            return
        }
        guard !existingProfiles.contains(where: { $0.profileVersion == cleanVersion }) else {
            errorMessage = "版本号已存在，请使用新的版本号。"
            return
        }
        existingProfiles.forEach { $0.isActive = false; $0.updatedAt = .now }
        let base = current ?? BrandProfile.defaultProfile()
        let profile = BrandProfile(
            profileName: "品牌档案 \(cleanVersion)",
            brandName: brandName,
            oneLinePositioning: positioning,
            targetAudience: targetAudience,
            valuePromise: valuePromise,
            tone: tone,
            commonWords: commonWords,
            forbiddenWords: forbiddenWords,
            serviceScope: serviceScope,
            notSuitableFor: notSuitableFor,
            pillars: pillars,
            wechatIntro: wechatIntro,
            xiaohongshuIntro: xiaohongshuIntro,
            visualStyle: base.visualStyle,
            avatarHint: base.avatarHint,
            logoHint: base.logoHint,
            photoStyle: base.photoStyle,
            signature: signature,
            profileVersion: cleanVersion,
            isActive: true
        )
        modelContext.insert(profile)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
