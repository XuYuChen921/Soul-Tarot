import Foundation

enum BrandAssetWorkflowError: LocalizedError, Equatable {
    case assetRequired
    case assetNotFound
    case unsupportedCategory
    case permissionUnavailable(String)
    case consentRequired
    case consentInactive
    case consentMismatch
    case channelNotAllowed(String)
    case formatNotAllowed
    case deidentificationIncomplete
    case emptyAnonymousSummary
    case identityRisk([String])

    var errorDescription: String? {
        switch self {
        case .assetRequired: return "客户共性主题必须选择已授权并完成去身份化的素材。"
        case .assetNotFound: return "关联素材不存在，已阻止继续使用。"
        case .unsupportedCategory: return "内部参考或禁止使用素材不能进入内容工作台。"
        case .permissionUnavailable(let reason): return "素材当前不可用：\(reason)"
        case .consentRequired: return "缺少独立的“匿名化内容使用”同意。"
        case .consentInactive: return "匿名化内容使用同意未接受、已到期或已撤回。"
        case .consentMismatch: return "素材所有者与授权记录不一致。"
        case .channelNotAllowed(let channel): return "授权或素材范围不允许用于\(channel)。"
        case .formatNotAllowed: return "素材使用形式超出客户同意允许的形式。"
        case .deidentificationIncomplete: return "必须完成直接身份信息清理、组合识别风险复核和第二次人工核对。"
        case .emptyAnonymousSummary: return "客户素材必须保存可用于内容生成的去身份化摘要。"
        case .identityRisk(let risks): return "去身份化摘要仍可能包含身份线索：\(risks.joined(separator: "；"))"
        }
    }
}

struct BrandWithdrawalResult {
    let events: [BrandAssetAuditEvent]
    let tasks: [BrandAssetActionTask]
}

enum BrandAssetWorkflowService {
    static func validateDraft(
        _ draft: BrandDraft,
        assets: [BrandAsset],
        consents: [ConsentRecord],
        now: Date = .now
    ) throws {
        for assetID in draft.linkedAssetIDs {
            guard let asset = assets.first(where: { $0.id == assetID }) else {
                throw BrandAssetWorkflowError.assetNotFound
            }
            let consent = asset.consentID.flatMap { id in consents.first(where: { $0.id == id }) }
            try validate(asset: asset, consent: consent, channel: draft.channel, now: now)
        }
    }

    static func validateTopic(
        source: BrandTopicSource,
        linkedAssetIDs: [UUID],
        assets: [BrandAsset],
        consents: [ConsentRecord],
        channels: [BrandDistributionChannel] = BrandDistributionChannel.allCases,
        now: Date = .now
    ) throws {
        if source == .historicalReuse {
            throw BrandGrowthWorkflowError.unsupportedSource
        }
        if source == .customerTheme, linkedAssetIDs.isEmpty {
            throw BrandAssetWorkflowError.assetRequired
        }

        for assetID in linkedAssetIDs {
            guard let asset = assets.first(where: { $0.id == assetID }) else {
                throw BrandAssetWorkflowError.assetNotFound
            }
            let consent = asset.consentID.flatMap { consentID in consents.first(where: { $0.id == consentID }) }
            for channel in channels {
                try validate(asset: asset, consent: consent, channel: channel, now: now)
            }
        }
    }

    static func validate(
        asset: BrandAsset,
        consent: ConsentRecord?,
        channel: BrandDistributionChannel,
        now: Date = .now
    ) throws {
        guard ![BrandAssetCategory.referenceOnly, .prohibited].contains(asset.category) else {
            throw BrandAssetWorkflowError.unsupportedCategory
        }
        guard asset.permission == .usable, asset.revokedAt == nil else {
            throw BrandAssetWorkflowError.permissionUnavailable(asset.permission.rawValue)
        }
        if let expiryAt = asset.expiryAt, expiryAt < now {
            throw BrandAssetWorkflowError.permissionUnavailable("已到期")
        }
        if !asset.allowedChannels.isEmpty, !asset.allowedChannels.contains(channel) {
            throw BrandAssetWorkflowError.channelNotAllowed(channel.rawValue)
        }

        guard asset.isCustomerRelated else { return }
        guard let consent, consent.type == .anonymousContentUse else {
            throw BrandAssetWorkflowError.consentRequired
        }
        guard consent.accepted, consent.withdrawnAt == nil,
              consent.expiresAt == nil || consent.expiresAt! >= now else {
            throw BrandAssetWorkflowError.consentInactive
        }
        guard asset.clientID != nil, asset.clientID == consent.clientID, asset.consentID == consent.id else {
            throw BrandAssetWorkflowError.consentMismatch
        }
        if !consent.allowedBrandChannels.isEmpty, !consent.allowedBrandChannels.contains(channel) {
            throw BrandAssetWorkflowError.channelNotAllowed(channel.rawValue)
        }
        let assetFormats = tokens(asset.allowedFormatsText ?? "")
        let consentFormats = tokens(consent.allowedFormatsText ?? "")
        if !assetFormats.isEmpty, !consentFormats.isEmpty,
           assetFormats.contains(where: { assetFormat in
               !consentFormats.contains(where: { $0.localizedCaseInsensitiveContains(assetFormat) || assetFormat.localizedCaseInsensitiveContains($0) })
           }) {
            throw BrandAssetWorkflowError.formatNotAllowed
        }
        guard asset.hasCompletedDeidentification else {
            throw BrandAssetWorkflowError.deidentificationIncomplete
        }
        let summary = (asset.deidentifiedSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw BrandAssetWorkflowError.emptyAnonymousSummary }
        let risks = identityRisks(in: summary)
        guard risks.isEmpty else { throw BrandAssetWorkflowError.identityRisk(risks) }
    }

    static func usableAssets(
        from assets: [BrandAsset],
        consents: [ConsentRecord],
        category: BrandAssetCategory? = nil,
        channels: [BrandDistributionChannel] = BrandDistributionChannel.allCases,
        now: Date = .now
    ) -> [BrandAsset] {
        assets.filter { asset in
            if let category, asset.category != category { return false }
            let consent = asset.consentID.flatMap { id in consents.first(where: { $0.id == id }) }
            return channels.allSatisfy { channel in
                (try? validate(asset: asset, consent: consent, channel: channel, now: now)) != nil
            }
        }
    }

    static func withdraw(
        consent: ConsentRecord,
        assets: [BrandAsset],
        topics: [BrandContentTopic],
        drafts: [BrandDraft],
        publishRecords: [BrandPublishRecord],
        actor: String = "本机使用者",
        method: String,
        now: Date = .now
    ) -> BrandWithdrawalResult {
        consent.withdrawnAt = now
        consent.withdrawalMethod = method
        let affectedAssets = assets.filter { $0.consentID == consent.id }
        let affectedIDs = Set(affectedAssets.map(\.id))
        var events: [BrandAssetAuditEvent] = []
        var tasks: [BrandAssetActionTask] = []

        for asset in affectedAssets {
            asset.permission = .withdrawn
            asset.revokedAt = now
            asset.updatedAt = now
            events.append(BrandAssetAuditEvent(
                assetID: asset.id,
                consentID: consent.id,
                action: .withdrawn,
                detail: "客户已通过\(method)撤回匿名化内容使用同意。",
                actor: actor,
                occurredAt: now
            ))
            if asset.relativePath?.isEmpty == false {
                tasks.append(BrandAssetActionTask(
                    assetID: asset.id,
                    type: .removeLocalFile,
                    detail: "按备份轮换与留存要求确认后，删除本机素材文件；审计记录继续保留。",
                    createdAt: now
                ))
            }
        }

        let affectedTopics = topics.filter { !affectedIDs.isDisjoint(with: Set($0.linkedAssetIDs)) }
        let affectedTopicIDs = Set(affectedTopics.map(\.id))
        for topic in affectedTopics {
            topic.status = .archived
            topic.isArchived = true
            topic.sensitivity = "授权已撤回，禁止再次使用"
            topic.updatedAt = now
        }

        for draft in drafts where affectedTopicIDs.contains(draft.topicID) || !affectedIDs.isDisjoint(with: Set(draft.linkedAssetIDs)) {
            draft.status = .deprecated
            draft.approvedAt = nil
            draft.approvedBy = ""
            draft.riskWarningsText = appendUnique("禁止批准：关联客户授权已撤回", to: draft.riskWarningsText)
            draft.updatedAt = now

            let records = publishRecords.filter { $0.draftID == draft.id }
            let published = records.filter(\.isPublished)
            if published.isEmpty {
                if let assetID = draft.linkedAssetIDs.first(where: affectedIDs.contains) ?? affectedAssets.first?.id {
                    tasks.append(BrandAssetActionTask(
                        assetID: assetID,
                        draftID: draft.id,
                        type: .discardDraft,
                        detail: "未发布草稿已停用，请确认删除草稿内容或改写为不含该素材的版本。",
                        createdAt: now
                    ))
                }
            } else {
                for record in published {
                    if let assetID = draft.linkedAssetIDs.first(where: affectedIDs.contains) ?? affectedAssets.first?.id {
                        tasks.append(BrandAssetActionTask(
                            assetID: assetID,
                            draftID: draft.id,
                            publishRecordID: record.id,
                            type: .reviewPublishedContent,
                            detail: "外部平台内容需要人工下架或修改；系统不会擅自操作平台。",
                            createdAt: now
                        ))
                    }
                }
            }
        }
        return BrandWithdrawalResult(events: events, tasks: tasks)
    }

    static func identityRisks(in text: String) -> [String] {
        let checks: [(String, String)] = [
            (#"(?<!\d)1[3-9]\d{9}(?!\d)"#, "手机号"),
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "电子邮箱"),
            (#"(?:微信号|订单号|身份证|住址|单位)\s*[:：]?\s*[^，。；\n]{3,}"#, "直接识别字段"),
            (#"\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}日?"#, "精确日期")
        ]
        return checks.compactMap { pattern, label in
            text.range(of: pattern, options: .regularExpression) == nil ? nil : label
        }
    }

    private static func appendUnique(_ value: String, to text: String) -> String {
        Array(Set((text + "\n" + value).components(separatedBy: "\n")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "\n")
    }

    private static func tokens(_ value: String) -> [String] {
        value.components(separatedBy: CharacterSet(charactersIn: ",，;；/、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
