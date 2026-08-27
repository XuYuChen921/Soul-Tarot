import Foundation
import SwiftData

enum BrandAssetCategory: String, CaseIterable, Codable, Identifiable {
    case brandOwned = "品牌自有"
    case publicProof = "可公开证明"
    case customerRelated = "客户相关"
    case referenceOnly = "仅供内部参考"
    case prohibited = "禁止使用"

    var id: String { rawValue }
}

enum BrandAssetAuditAction: String, CaseIterable, Codable, Identifiable {
    case created = "建立素材"
    case reviewed = "完成去身份化复核"
    case linked = "关联内容"
    case approved = "批准使用"
    case published = "登记发布"
    case withdrawn = "撤回授权"
    case blocked = "阻止再次使用"
    case deleted = "删除素材文件"

    var id: String { rawValue }
}

enum BrandAssetTaskType: String, CaseIterable, Codable, Identifiable {
    case discardDraft = "处理未发布草稿"
    case reviewPublishedContent = "人工下架或修改已发布内容"
    case removeLocalFile = "删除本地素材文件"

    var id: String { rawValue }
}

enum BrandAssetTaskStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "待处理"
    case completed = "已完成"

    var id: String { rawValue }
}

@Model
final class BrandAssetAuditEvent {
    @Attribute(.unique) var id: UUID
    var assetID: UUID
    var consentID: UUID?
    var actionRaw: String
    var detail: String
    var actor: String
    var occurredAt: Date

    var action: BrandAssetAuditAction {
        get { BrandAssetAuditAction(rawValue: actionRaw) ?? .created }
        set { actionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        assetID: UUID,
        consentID: UUID? = nil,
        action: BrandAssetAuditAction,
        detail: String,
        actor: String = "本机使用者",
        occurredAt: Date = .now
    ) {
        self.id = id
        self.assetID = assetID
        self.consentID = consentID
        self.actionRaw = action.rawValue
        self.detail = detail
        self.actor = actor
        self.occurredAt = occurredAt
    }
}

@Model
final class BrandAssetUsage {
    @Attribute(.unique) var id: UUID
    var assetID: UUID
    var topicID: UUID?
    var draftID: UUID?
    var publishRecordID: UUID?
    var channelRaw: String?
    var action: String
    var occurredAt: Date

    var channel: BrandDistributionChannel? {
        get { channelRaw.flatMap(BrandDistributionChannel.init(rawValue:)) }
        set { channelRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        assetID: UUID,
        topicID: UUID? = nil,
        draftID: UUID? = nil,
        publishRecordID: UUID? = nil,
        channel: BrandDistributionChannel? = nil,
        action: String,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.assetID = assetID
        self.topicID = topicID
        self.draftID = draftID
        self.publishRecordID = publishRecordID
        self.channelRaw = channel?.rawValue
        self.action = action
        self.occurredAt = occurredAt
    }
}

@Model
final class BrandAssetActionTask {
    @Attribute(.unique) var id: UUID
    var assetID: UUID
    var draftID: UUID?
    var publishRecordID: UUID?
    var typeRaw: String
    var statusRaw: String
    var detail: String
    var createdAt: Date
    var resolvedAt: Date?

    var type: BrandAssetTaskType {
        get { BrandAssetTaskType(rawValue: typeRaw) ?? .discardDraft }
        set { typeRaw = newValue.rawValue }
    }

    var status: BrandAssetTaskStatus {
        get { BrandAssetTaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        assetID: UUID,
        draftID: UUID? = nil,
        publishRecordID: UUID? = nil,
        type: BrandAssetTaskType,
        status: BrandAssetTaskStatus = .pending,
        detail: String,
        createdAt: Date = .now,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.assetID = assetID
        self.draftID = draftID
        self.publishRecordID = publishRecordID
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.detail = detail
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}
