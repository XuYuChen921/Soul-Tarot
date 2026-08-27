import Foundation
import SwiftData

enum BrandDistributionChannel: String, CaseIterable, Identifiable, Codable, Hashable {
    case wechatMoments = "微信朋友圈"
    case xiaohongshu = "小红书"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wechatMoments: return "message.fill"
        case .xiaohongshu: return "sparkles"
        }
    }

    var sortOrder: Int {
        switch self {
        case .wechatMoments: return 0
        case .xiaohongshu: return 1
        }
    }
}

enum BrandTopicSource: String, CaseIterable, Codable, Identifiable {
    case personalOpinion = "个人观点"
    case publicMaterial = "公开资料"
    case brandMaterial = "品牌素材"
    case customerTheme = "客户共性主题"
    case historicalReuse = "历史内容复用"

    var id: String { rawValue }

    var availableInM1: Bool {
        switch self {
        case .customerTheme, .historicalReuse:
            return false
        case .personalOpinion, .publicMaterial, .brandMaterial:
            return true
        }
    }
}

enum BrandTopicGoal: String, CaseIterable, Codable, Identifiable {
    case reach = "触达"
    case trust = "信任"
    case interaction = "互动"
    case inquiry = "询盘"
    case conversion = "成交"
    case revisit = "复访"

    var id: String { rawValue }
}

enum BrandTopicStatus: String, CaseIterable, Codable, Identifiable {
    case drafting = "草稿"
    case active = "进行中"
    case waitingForPublish = "待发布"
    case completed = "已结束"
    case archived = "已归档"

    var id: String { rawValue }
}

enum BrandDraftStatus: String, CaseIterable, Codable, Identifiable {
    case drafting = "编辑中"
    case waitingApproval = "待人工审批"
    case approved = "已批准"
    case deprecated = "已失效"

    var id: String { rawValue }
}

enum BrandDraftSource: String, CaseIterable, Codable, Identifiable {
    case ai = "本地 AI"
    case manual = "人工编辑"

    var id: String { rawValue }
}

enum BrandMetricCollectionMode: String, CaseIterable, Codable, Identifiable {
    case manual = "人工录入"
    case csv = "CSV 导入"
    case screenshot = "截图识别"
    case api = "接口同步"

    var id: String { rawValue }
}

enum BrandAssetType: String, CaseIterable, Codable, Identifiable {
    case avatar = "头像"
    case logo = "Logo"
    case photo = "照片"
    case document = "文本/说明"

    var id: String { rawValue }
}

enum BrandAssetPermission: String, CaseIterable, Codable, Identifiable {
    case usable = "可用"
    case expired = "已到期"
    case withdrawn = "已撤回"

    var id: String { rawValue }
}

enum BrandReviewStatus: String, CaseIterable, Codable, Identifiable {
    case drafting = "待人工确认"
    case completed = "已确认"

    var id: String { rawValue }
}

@Model
final class BrandProfile {
    @Attribute(.unique) var id: UUID
    var profileName: String
    var brandName: String
    var oneLinePositioning: String
    var targetAudience: String
    var valuePromise: String
    var tone: String
    var commonWords: String
    var forbiddenWords: String
    var serviceScope: String
    var notSuitableFor: String
    var pillars: String
    var wechatIntro: String
    var xiaohongshuIntro: String
    var visualStyle: String
    var avatarHint: String
    var logoHint: String
    var photoStyle: String
    var signature: String
    var profileVersion: String
    var effectiveAt: Date
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        profileName: String,
        brandName: String,
        oneLinePositioning: String,
        targetAudience: String,
        valuePromise: String,
        tone: String,
        commonWords: String,
        forbiddenWords: String,
        serviceScope: String,
        notSuitableFor: String,
        pillars: String,
        wechatIntro: String,
        xiaohongshuIntro: String,
        visualStyle: String,
        avatarHint: String,
        logoHint: String,
        photoStyle: String,
        signature: String,
        profileVersion: String,
        effectiveAt: Date = .now,
        isActive: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.profileName = profileName
        self.brandName = brandName
        self.oneLinePositioning = oneLinePositioning
        self.targetAudience = targetAudience
        self.valuePromise = valuePromise
        self.tone = tone
        self.commonWords = commonWords
        self.forbiddenWords = forbiddenWords
        self.serviceScope = serviceScope
        self.notSuitableFor = notSuitableFor
        self.pillars = pillars
        self.wechatIntro = wechatIntro
        self.xiaohongshuIntro = xiaohongshuIntro
        self.visualStyle = visualStyle
        self.avatarHint = avatarHint
        self.logoHint = logoHint
        self.photoStyle = photoStyle
        self.signature = signature
        self.profileVersion = profileVersion
        self.effectiveAt = effectiveAt
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var commonWordsList: [String] { parseTokenList(commonWords) }
    var forbiddenWordsList: [String] { parseTokenList(forbiddenWords) }

    static func defaultProfile() -> BrandProfile {
        BrandProfile(
            profileName: "默认品牌档案（首次）",
            brandName: "心塔",
            oneLinePositioning: "心理成长与决策陪伴",
            targetAudience: "面对自我探索、关系困扰、职业抉择与成长焦虑的人群",
            valuePromise: "帮助来访者整理问题、看见模式、理解选择",
            tone: "温柔、清醒、有边界、尊重选择",
            commonWords: "关系、边界、选择、反思、节奏、共鸣",
            forbiddenWords: "保命、必中、包治、必胜、保你一周",
            serviceScope: "陪伴咨询、方法建议、决策梳理",
            notSuitableFor: "不替代医疗、法律或投资咨询",
            pillars: "情绪与关系洞察=触达、决策与自我认识=信任、心理成长练习=复访、服务说明与FAQ=成交",
            wechatIntro: "心塔是“心理成长与决策陪伴”服务，重点在关系观察与成长节奏。",
            xiaohongshuIntro: "心塔心理成长陪伴实验室，分享成长方法与案例启发。",
            visualStyle: "轻薄雾、清爽、留白，统一落款",
            avatarHint: "本人公开形象照，避免隐私暴露",
            logoHint: "简洁字形版 Logo，透明底",
            photoStyle: "不夸张滤镜，适合日常办公与自然场景",
            signature: "— 心塔",
            profileVersion: "V1.0.0",
            isActive: true
        )
    }

    private func parseTokenList(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

@Model
final class BrandContentTopic {
    @Attribute(.unique) var id: UUID
    var profileID: UUID
    var title: String
    var rawIdea: String
    var targetAudience: String
    var pillar: String
    var goalRaw: String
    var sourceTypeRaw: String
    var sensitivity: String
    var customerReference: String
    var actionHint: String
    var priority: Int
    var plannedPublishAt: Date?
    var statusRaw: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var sourceType: BrandTopicSource {
        get { BrandTopicSource(rawValue: sourceTypeRaw) ?? .personalOpinion }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var goal: BrandTopicGoal {
        get { BrandTopicGoal(rawValue: goalRaw) ?? .trust }
        set { goalRaw = newValue.rawValue }
    }

    var status: BrandTopicStatus {
        get { BrandTopicStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        profileID: UUID,
        title: String,
        rawIdea: String,
        targetAudience: String,
        pillar: String,
        goal: BrandTopicGoal,
        sourceType: BrandTopicSource,
        sensitivity: String,
        customerReference: String,
        actionHint: String,
        priority: Int,
        plannedPublishAt: Date? = nil,
        status: BrandTopicStatus = .active,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.profileID = profileID
        self.title = title
        self.rawIdea = rawIdea
        self.targetAudience = targetAudience
        self.pillar = pillar
        self.goalRaw = goal.rawValue
        self.sourceTypeRaw = sourceType.rawValue
        self.sensitivity = sensitivity
        self.customerReference = customerReference
        self.actionHint = actionHint
        self.priority = priority
        self.plannedPublishAt = plannedPublishAt
        self.statusRaw = status.rawValue
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BrandDraft {
    @Attribute(.unique) var id: UUID
    var topicID: UUID
    var channelRaw: String
    var statusRaw: String
    var sourceRaw: String
    var version: Int
    var title: String
    var subtitle: String
    var opening: String
    var content: String
    var actionPrompt: String
    var imageSuggestion: String
    var keywordsText: String
    var hashtagText: String
    var searchTitleText: String
    var resonanceTitleText: String
    var riskWarningsText: String
    var generatedBy: String
    var aiModelName: String
    var profileVersion: String
    var generatedAt: Date
    var approvedAt: Date?
    var approvedBy: String
    var createdAt: Date
    var updatedAt: Date

    var channel: BrandDistributionChannel {
        get { BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments }
        set { channelRaw = newValue.rawValue }
    }

    var status: BrandDraftStatus {
        get { BrandDraftStatus(rawValue: statusRaw) ?? .drafting }
        set { statusRaw = newValue.rawValue }
    }

    var source: BrandDraftSource {
        get { BrandDraftSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var keywords: [String] { parseTokenList(keywordsText) }
    var hashtags: [String] { parseTokenList(hashtagText) }
    var searchTitles: [String] { parseTokenList(searchTitleText) }
    var resonanceTitles: [String] { parseTokenList(resonanceTitleText) }
    var riskWarnings: [String] { riskWarningsText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    var isApproved: Bool { status == .approved && approvedAt != nil }

    init(
        id: UUID = UUID(),
        topicID: UUID,
        channel: BrandDistributionChannel,
        title: String = "",
        subtitle: String = "",
        opening: String = "",
        content: String = "",
        actionPrompt: String = "",
        imageSuggestion: String = "",
        keywordsText: String = "",
        hashtagText: String = "",
        searchTitleText: String = "",
        resonanceTitleText: String = "",
        riskWarningsText: String = "",
        source: BrandDraftSource = .manual,
        aiModelName: String = "",
        profileVersion: String = "",
        generatedBy: String = "",
        status: BrandDraftStatus = .drafting,
        version: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.channelRaw = channel.rawValue
        self.statusRaw = status.rawValue
        self.sourceRaw = source.rawValue
        self.version = version
        self.title = title
        self.subtitle = subtitle
        self.opening = opening
        self.content = content
        self.actionPrompt = actionPrompt
        self.imageSuggestion = imageSuggestion
        self.keywordsText = keywordsText
        self.hashtagText = hashtagText
        self.searchTitleText = searchTitleText
        self.resonanceTitleText = resonanceTitleText
        self.riskWarningsText = riskWarningsText
        self.generatedBy = generatedBy
        self.aiModelName = aiModelName
        self.profileVersion = profileVersion
        self.generatedAt = createdAt
        self.approvedAt = nil
        self.approvedBy = ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func approve(by name: String) {
        status = .approved
        approvedAt = .now
        approvedBy = name
        updatedAt = .now
    }

    func apply(_ payload: BrandDraftPayload, source: BrandDraftSource, modelName: String, profileVersion: String, now: Date = .now) {
        title = payload.title
        subtitle = payload.subtitle
        opening = payload.opening
        content = payload.body
        actionPrompt = payload.actionPrompt
        imageSuggestion = payload.imageSuggestion
        keywordsText = payload.keywords.joined(separator: "，")
        hashtagText = payload.hashtags.joined(separator: "，")
        searchTitleText = payload.searchTitles.joined(separator: "\n")
        resonanceTitleText = payload.resonanceTitles.joined(separator: "\n")
        riskWarningsText = payload.riskWarnings.joined(separator: "\n")
        self.source = source
        aiModelName = modelName
        self.profileVersion = profileVersion
        generatedBy = source.rawValue
        generatedAt = now
        status = .waitingApproval
        approvedAt = nil
        approvedBy = ""
        version += 1
        updatedAt = now
    }

    func markEdited(_ now: Date = .now) {
        if status == .approved {
            status = .drafting
            approvedAt = nil
            approvedBy = ""
            riskWarningsText = appendCriticalRiskMark(riskWarningsText)
        }
        updatedAt = now
    }

    private func appendCriticalRiskMark(_ text: String) -> String {
        let source = Array(Set((text + "\n" + "已修改草稿，需重新审批").components(separatedBy: "\n")))
        return source
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var hasCriticalRisk: Bool {
        riskWarnings.contains { value in
            let lower = value.lowercased()
            return lower.contains("高风险") || lower.contains("禁止") || lower.contains("不能") || lower.contains("不允许")
        }
    }

    private func parseTokenList(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

@Model
final class BrandDraftRevision {
    @Attribute(.unique) var id: UUID
    var draftID: UUID
    var topicID: UUID
    var channelRaw: String
    var version: Int
    var title: String
    var subtitle: String
    var opening: String
    var content: String
    var actionPrompt: String
    var imageSuggestion: String
    var keywordsText: String
    var hashtagText: String
    var searchTitleText: String
    var resonanceTitleText: String
    var riskWarningsText: String
    var sourceRaw: String
    var aiModelName: String
    var profileVersion: String
    var statusRaw: String
    var approvedAt: Date?
    var savedAt: Date

    var channel: BrandDistributionChannel {
        BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments
    }

    init(draft: BrandDraft, savedAt: Date = .now) {
        id = UUID()
        draftID = draft.id
        topicID = draft.topicID
        channelRaw = draft.channelRaw
        version = draft.version
        title = draft.title
        subtitle = draft.subtitle
        opening = draft.opening
        content = draft.content
        actionPrompt = draft.actionPrompt
        imageSuggestion = draft.imageSuggestion
        keywordsText = draft.keywordsText
        hashtagText = draft.hashtagText
        searchTitleText = draft.searchTitleText
        resonanceTitleText = draft.resonanceTitleText
        riskWarningsText = draft.riskWarningsText
        sourceRaw = draft.sourceRaw
        aiModelName = draft.aiModelName
        profileVersion = draft.profileVersion
        statusRaw = draft.statusRaw
        approvedAt = draft.approvedAt
        self.savedAt = savedAt
    }
}

@Model
final class BrandPublishRecord {
    @Attribute(.unique) var id: UUID
    var topicID: UUID
    var draftID: UUID?
    var channelRaw: String
    var plannedAt: Date?
    var publishedAt: Date?
    var platformPostID: String
    var platformLink: String
    var note: String
    var snapshotTitle: String
    var snapshotContent: String
    var publishedAsApproved: Bool
    var collectedBy: String
    var createdAt: Date
    var updatedAt: Date

    var channel: BrandDistributionChannel {
        get { BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments }
        set { channelRaw = newValue.rawValue }
    }

    var isPublished: Bool { publishedAt != nil }

    var effectiveDate: Date {
        publishedAt ?? plannedAt ?? createdAt
    }

    init(
        id: UUID = UUID(),
        topicID: UUID,
        draftID: UUID? = nil,
        channel: BrandDistributionChannel,
        plannedAt: Date? = nil,
        publishedAt: Date? = nil,
        platformPostID: String = "",
        platformLink: String = "",
        note: String = "",
        snapshotTitle: String = "",
        snapshotContent: String = "",
        publishedAsApproved: Bool = false,
        collectedBy: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.topicID = topicID
        self.draftID = draftID
        self.channelRaw = channel.rawValue
        self.plannedAt = plannedAt
        self.publishedAt = publishedAt
        self.platformPostID = platformPostID
        self.platformLink = platformLink
        self.note = note
        self.snapshotTitle = snapshotTitle
        self.snapshotContent = snapshotContent
        self.publishedAsApproved = publishedAsApproved
        self.collectedBy = collectedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BrandAsset {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var source: String
    var owner: String
    var permissionRaw: String
    var allowedChannelsText: String
    var expiryAt: Date?
    var revokedAt: Date?
    var useScope: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: BrandAssetType {
        get { BrandAssetType(rawValue: kindRaw) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }

    var permission: BrandAssetPermission {
        get { BrandAssetPermission(rawValue: permissionRaw) ?? .usable }
        set { permissionRaw = newValue.rawValue }
    }

    var allowedChannels: [BrandDistributionChannel] {
        allowedChannelsText
            .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(BrandDistributionChannel.init(rawValue:))
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: BrandAssetType,
        source: String,
        owner: String,
        permission: BrandAssetPermission,
        allowedChannelsText: String = "",
        expiryAt: Date? = nil,
        revokedAt: Date? = nil,
        useScope: String = "",
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.source = source
        self.owner = owner
        self.permissionRaw = permission.rawValue
        self.allowedChannelsText = allowedChannelsText
        self.expiryAt = expiryAt
        self.revokedAt = revokedAt
        self.useScope = useScope
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BrandMetricSnapshot {
    @Attribute(.unique) var id: UUID
    var publishRecordID: UUID
    var collectedAt: Date
    var periodStart: Date
    var periodEnd: Date
    var methodRaw: String
    var exposure: Int?
    var views: Int?
    var likes: Int?
    var comments: Int?
    var favorites: Int?
    var shares: Int?
    var profileVisits: Int?
    var followers: Int?
    var privateMessages: Int?
    var missingReasons: String
    var sourceFile: String
    var isCumulative: Bool
    var isConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date

    var method: BrandMetricCollectionMode {
        get { BrandMetricCollectionMode(rawValue: methodRaw) ?? .manual }
        set { methodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        publishRecordID: UUID,
        collectedAt: Date = .now,
        periodStart: Date,
        periodEnd: Date,
        method: BrandMetricCollectionMode,
        exposure: Int? = nil,
        views: Int? = nil,
        likes: Int? = nil,
        comments: Int? = nil,
        favorites: Int? = nil,
        shares: Int? = nil,
        profileVisits: Int? = nil,
        followers: Int? = nil,
        privateMessages: Int? = nil,
        missingReasons: String = "",
        sourceFile: String = "",
        isCumulative: Bool = false,
        isConfirmed: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publishRecordID = publishRecordID
        self.collectedAt = collectedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.methodRaw = method.rawValue
        self.exposure = exposure
        self.views = views
        self.likes = likes
        self.comments = comments
        self.favorites = favorites
        self.shares = shares
        self.profileVisits = profileVisits
        self.followers = followers
        self.privateMessages = privateMessages
        self.missingReasons = missingReasons
        self.sourceFile = sourceFile
        self.isCumulative = isCumulative
        self.isConfirmed = isConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BrandWeeklyReview {
    @Attribute(.unique) var id: UUID
    var periodStart: Date
    var periodEnd: Date
    var plannedGenerateAt: Date
    var generatedAt: Date?
    var summaryText: String
    var conclusionText: String
    var bestText: String
    var worstText: String
    var conversionText: String
    var channelWechatRole: String
    var channelXhsRole: String
    var dataGapText: String
    var continueText: String
    var stopText: String
    var experimentText: String
    var statusRaw: String
    var approvedAt: Date?
    var approvedBy: String
    var createdAt: Date
    var updatedAt: Date

    var status: BrandReviewStatus {
        get { BrandReviewStatus(rawValue: statusRaw) ?? .drafting }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        periodStart: Date,
        periodEnd: Date,
        plannedGenerateAt: Date = .now,
        generatedAt: Date? = nil,
        summaryText: String = "",
        conclusionText: String = "",
        bestText: String = "",
        worstText: String = "",
        conversionText: String = "",
        channelWechatRole: String = "",
        channelXhsRole: String = "",
        dataGapText: String = "",
        continueText: String = "",
        stopText: String = "",
        experimentText: String = "",
        status: BrandReviewStatus = .drafting,
        approvedAt: Date? = nil,
        approvedBy: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.plannedGenerateAt = plannedGenerateAt
        self.generatedAt = generatedAt
        self.summaryText = summaryText
        self.conclusionText = conclusionText
        self.bestText = bestText
        self.worstText = worstText
        self.conversionText = conversionText
        self.channelWechatRole = channelWechatRole
        self.channelXhsRole = channelXhsRole
        self.dataGapText = dataGapText
        self.continueText = continueText
        self.stopText = stopText
        self.experimentText = experimentText
        self.statusRaw = status.rawValue
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
