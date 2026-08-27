import Foundation

enum BrandGrowthWorkflowError: LocalizedError {
    case unsupportedSource
    case emptyDraft
    case blockingRisk([String])
    case approvalRequired

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "M1 只允许个人观点、公开资料和品牌素材来源。"
        case .emptyDraft:
            return "标题和正文不能为空。"
        case .blockingRisk(let risks):
            return "存在阻止批准的风险：\(risks.joined(separator: "；"))"
        case .approvalRequired:
            return "草稿必须先由人工单独批准，才能进入发布日历。"
        }
    }
}

enum BrandGrowthRiskService {
    private static let regulatedTerms = [
        "包治", "治愈", "治疗承诺", "保证有效", "一定会", "必然", "绝对",
        "稳赚", "稳赢", "必中", "投资结论", "命中注定", "生死", "改命"
    ]

    static func evaluate(title: String, content: String, profile: BrandProfile) -> [String] {
        let allText = title + "\n" + content
        var risks: [String] = []

        for term in regulatedTerms where allText.localizedCaseInsensitiveContains(term) {
            risks.append("禁止批准：含确定性承诺或高风险表达“\(term)”")
        }
        for term in profile.forbiddenWordsList where allText.localizedCaseInsensitiveContains(term) {
            risks.append("禁止批准：含品牌禁用表达“\(term)”")
        }
        if contains(pattern: #"(?<!\d)1[3-9]\d{9}(?!\d)"#, in: allText) {
            risks.append("禁止批准：疑似包含完整手机号")
        }
        if contains(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, in: allText) {
            risks.append("禁止批准：疑似包含电子邮箱")
        }
        if contains(pattern: #"(?:订单号|微信号|身份证)\s*[:：]?\s*[A-Za-z0-9_-]{5,}"#, in: allText) {
            risks.append("禁止批准：疑似包含客户识别信息")
        }
        if contains(pattern: #"\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?"#, in: allText) {
            risks.append("禁止批准：疑似包含客户精确日期")
        }
        return Array(Set(risks)).sorted()
    }

    private static func contains(pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum BrandGrowthWorkflowService {
    static func validateM1Source(_ source: BrandTopicSource) throws {
        guard source.availableInM1 else { throw BrandGrowthWorkflowError.unsupportedSource }
    }

    static func approvalRisks(for draft: BrandDraft, profile: BrandProfile) -> [String] {
        let deterministic = BrandGrowthRiskService.evaluate(
            title: draft.title,
            content: [draft.subtitle, draft.opening, draft.content, draft.actionPrompt].joined(separator: "\n"),
            profile: profile
        )
        let aiBlocking = draft.riskWarnings.filter { warning in
            let normalized = warning.lowercased()
            return normalized.contains("高风险")
                || normalized.contains("禁止批准")
                || normalized.contains("不能发布")
                || normalized.contains("不允许")
        }
        return Array(Set(deterministic + aiBlocking)).sorted()
    }

    static func approve(
        _ draft: BrandDraft,
        profile: BrandProfile,
        assets: [BrandAsset] = [],
        consents: [ConsentRecord] = [],
        by reviewer: String,
        now: Date = .now
    ) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !content.isEmpty else { throw BrandGrowthWorkflowError.emptyDraft }
        try BrandAssetWorkflowService.validateDraft(draft, assets: assets, consents: consents, now: now)
        let risks = approvalRisks(for: draft, profile: profile)
        guard risks.isEmpty else { throw BrandGrowthWorkflowError.blockingRisk(risks) }
        draft.status = .approved
        draft.approvedAt = now
        draft.approvedBy = reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "本机使用者" : reviewer
        draft.riskWarningsText = draft.riskWarnings
            .filter { $0 != "已修改草稿，需重新审批" }
            .joined(separator: "\n")
        draft.updatedAt = now
    }

    static func makePublishRecord(
        from draft: BrandDraft,
        assets: [BrandAsset] = [],
        consents: [ConsentRecord] = [],
        plannedAt: Date?,
        publishedAt: Date? = nil,
        platformPostID: String = "",
        platformLink: String = "",
        note: String = "",
        now: Date = .now
    ) throws -> BrandPublishRecord {
        guard draft.isApproved else { throw BrandGrowthWorkflowError.approvalRequired }
        try BrandAssetWorkflowService.validateDraft(draft, assets: assets, consents: consents, now: now)
        return BrandPublishRecord(
            topicID: draft.topicID,
            draftID: draft.id,
            channel: draft.channel,
            plannedAt: plannedAt,
            publishedAt: publishedAt,
            platformPostID: platformPostID,
            platformLink: platformLink,
            note: note,
            snapshotTitle: draft.title,
            snapshotContent: snapshotContent(for: draft),
            publishedAsApproved: true,
            collectedBy: "本机使用者",
            createdAt: now,
            updatedAt: now
        )
    }

    static func snapshotContent(for draft: BrandDraft) -> String {
        [draft.opening, draft.content, draft.actionPrompt]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
