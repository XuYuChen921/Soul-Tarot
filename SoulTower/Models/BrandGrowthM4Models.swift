import Foundation
import SwiftData

enum BrandPlatformKind: String, CaseIterable, Codable, Identifiable {
    case wechatPersonalMoments = "个人微信朋友圈"
    case xiaohongshuOpenAccount = "小红书开放账号"
    case wecomCustomerMoments = "企业微信客户朋友圈"

    var id: String { rawValue }

    var channel: BrandDistributionChannel? {
        switch self {
        case .wechatPersonalMoments, .wecomCustomerMoments: return .wechatMoments
        case .xiaohongshuOpenAccount: return .xiaohongshu
        }
    }
}

enum BrandPlatformConnectionStatus: String, CaseIterable, Codable, Identifiable {
    case manualOnly = "人工模式"
    case verificationRequired = "待真实账号验权"
    case connected = "已连接"
    case tokenExpired = "令牌已过期"
    case syncFailed = "同步失败"

    var id: String { rawValue }
}

enum BrandPlatformCapability: String, CaseIterable, Codable, Identifiable {
    case manualImportOnly = "人工录入与表格导入"
    case basicIdentityOnly = "仅基础身份授权"
    case metricSyncRequiresApproval = "指标同步需正式审批"
    case officialMetricSync = "官方指标同步"

    var id: String { rawValue }
}

enum BrandSyncRunStatus: String, CaseIterable, Codable, Identifiable {
    case running = "同步中"
    case succeeded = "同步成功"
    case skipped = "未执行"
    case failed = "同步失败"

    var id: String { rawValue }
}

enum BrandExperimentDimension: String, CaseIterable, Codable, Identifiable {
    case contentPillar = "内容栏目"
    case titleDirection = "标题方向"
    case publishTime = "发布时间"
    case callToAction = "行动提示"

    var id: String { rawValue }
}

enum BrandExperimentStatus: String, CaseIterable, Codable, Identifiable {
    case planned = "待开始"
    case running = "进行中"
    case completed = "已结束"

    var id: String { rawValue }
}

@Model
final class BrandPlatformConnection {
    @Attribute(.unique) var id: UUID
    var platformRaw: String
    var accountLabel: String
    var accountType: String
    var capabilityRaw: String
    var statusRaw: String
    var officialDocumentURL: String
    var verificationNote: String
    var isAPIApproved: Bool
    var credentialStoredAt: Date?
    var tokenExpiresAt: Date?
    var lastAttemptAt: Date?
    var lastSuccessfulSyncAt: Date?
    var lastErrorCategory: String
    var lastErrorMessage: String
    var createdAt: Date
    var updatedAt: Date

    var platform: BrandPlatformKind {
        get { BrandPlatformKind(rawValue: platformRaw) ?? .wechatPersonalMoments }
        set { platformRaw = newValue.rawValue }
    }

    var capability: BrandPlatformCapability {
        get { BrandPlatformCapability(rawValue: capabilityRaw) ?? .manualImportOnly }
        set { capabilityRaw = newValue.rawValue }
    }

    var status: BrandPlatformConnectionStatus {
        get { BrandPlatformConnectionStatus(rawValue: statusRaw) ?? .manualOnly }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        platform: BrandPlatformKind,
        accountLabel: String,
        accountType: String,
        capability: BrandPlatformCapability,
        status: BrandPlatformConnectionStatus,
        officialDocumentURL: String,
        verificationNote: String,
        isAPIApproved: Bool = false,
        credentialStoredAt: Date? = nil,
        tokenExpiresAt: Date? = nil,
        lastAttemptAt: Date? = nil,
        lastSuccessfulSyncAt: Date? = nil,
        lastErrorCategory: String = "",
        lastErrorMessage: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.platformRaw = platform.rawValue
        self.accountLabel = accountLabel
        self.accountType = accountType
        self.capabilityRaw = capability.rawValue
        self.statusRaw = status.rawValue
        self.officialDocumentURL = officialDocumentURL
        self.verificationNote = verificationNote
        self.isAPIApproved = isAPIApproved
        self.credentialStoredAt = credentialStoredAt
        self.tokenExpiresAt = tokenExpiresAt
        self.lastAttemptAt = lastAttemptAt
        self.lastSuccessfulSyncAt = lastSuccessfulSyncAt
        self.lastErrorCategory = lastErrorCategory
        self.lastErrorMessage = lastErrorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BrandSyncRun {
    @Attribute(.unique) var id: UUID
    var connectionID: UUID
    var statusRaw: String
    var requestedAt: Date
    var completedAt: Date?
    var importedCount: Int
    var skippedDuplicateCount: Int
    var errorCategory: String
    var safeMessage: String

    var status: BrandSyncRunStatus {
        get { BrandSyncRunStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        status: BrandSyncRunStatus = .running,
        requestedAt: Date = .now,
        completedAt: Date? = nil,
        importedCount: Int = 0,
        skippedDuplicateCount: Int = 0,
        errorCategory: String = "",
        safeMessage: String = ""
    ) {
        self.id = id
        self.connectionID = connectionID
        self.statusRaw = status.rawValue
        self.requestedAt = requestedAt
        self.completedAt = completedAt
        self.importedCount = importedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.errorCategory = errorCategory
        self.safeMessage = safeMessage
    }
}

@Model
final class BrandSyncItemReceipt {
    @Attribute(.unique) var fingerprint: String
    var id: UUID
    var connectionID: UUID
    var remoteItemID: String
    var publishRecordID: UUID
    var metricSnapshotID: UUID
    var receivedAt: Date

    init(
        id: UUID = UUID(),
        fingerprint: String,
        connectionID: UUID,
        remoteItemID: String,
        publishRecordID: UUID,
        metricSnapshotID: UUID,
        receivedAt: Date = .now
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.connectionID = connectionID
        self.remoteItemID = remoteItemID
        self.publishRecordID = publishRecordID
        self.metricSnapshotID = metricSnapshotID
        self.receivedAt = receivedAt
    }
}

@Model
final class BrandExperiment {
    @Attribute(.unique) var id: UUID
    var title: String
    var dimensionRaw: String
    var hypothesis: String
    var variantALabel: String
    var variantAPublishRecordID: UUID
    var variantBLabel: String
    var variantBPublishRecordID: UUID
    var statusRaw: String
    var factualComparison: String
    var conclusion: String
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var dimension: BrandExperimentDimension {
        get { BrandExperimentDimension(rawValue: dimensionRaw) ?? .titleDirection }
        set { dimensionRaw = newValue.rawValue }
    }

    var status: BrandExperimentStatus {
        get { BrandExperimentStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        dimension: BrandExperimentDimension,
        hypothesis: String,
        variantALabel: String,
        variantAPublishRecordID: UUID,
        variantBLabel: String,
        variantBPublishRecordID: UUID,
        status: BrandExperimentStatus = .planned,
        factualComparison: String = "",
        conclusion: String = "",
        startedAt: Date = .now,
        endedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.dimensionRaw = dimension.rawValue
        self.hypothesis = hypothesis
        self.variantALabel = variantALabel
        self.variantAPublishRecordID = variantAPublishRecordID
        self.variantBLabel = variantBLabel
        self.variantBPublishRecordID = variantBPublishRecordID
        self.statusRaw = status.rawValue
        self.factualComparison = factualComparison
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
