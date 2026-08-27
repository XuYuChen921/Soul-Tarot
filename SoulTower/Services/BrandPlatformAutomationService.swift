import CryptoKit
import Foundation
import SwiftData

struct BrandPlatformCapabilityReport: Equatable, Sendable {
    let platform: BrandPlatformKind
    let accountType: String
    let capability: BrandPlatformCapability
    let status: BrandPlatformConnectionStatus
    let officialDocumentURL: String
    let verificationNote: String
    let supportsMetricSync: Bool
}

enum BrandPlatformCapabilityRegistry {
    static let reports: [BrandPlatformCapabilityReport] = [
        BrandPlatformCapabilityReport(
            platform: .wechatPersonalMoments,
            accountType: "个人微信账号",
            capability: .manualImportOnly,
            status: .manualOnly,
            officialDocumentURL: "https://open.tencent.com/",
            verificationNote: "未核验到适用于个人朋友圈内容指标的官方公开接口；继续使用人工录入或表格导入。",
            supportsMetricSync: false
        ),
        BrandPlatformCapabilityReport(
            platform: .xiaohongshuOpenAccount,
            accountType: "小红书开放账号",
            capability: .basicIdentityOnly,
            status: .manualOnly,
            officialDocumentURL: "https://openaccount.xiaohongshu.com/docs/quick-start",
            verificationNote: "当前公开开放账号首期仅提供 basic_info 基础身份授权，未提供笔记指标同步能力。",
            supportsMetricSync: false
        ),
        BrandPlatformCapabilityReport(
            platform: .wecomCustomerMoments,
            accountType: "企业微信企业账号",
            capability: .metricSyncRequiresApproval,
            status: .verificationRequired,
            officialDocumentURL: "https://developer.work.weixin.qq.com/document/path/93333",
            verificationNote: "仅作为后续扩展登记；必须使用真实企业账号逐项验证客户联系权限和接口范围后才能启用。",
            supportsMetricSync: false
        )
    ]

    static func report(for platform: BrandPlatformKind) -> BrandPlatformCapabilityReport {
        reports.first(where: { $0.platform == platform }) ?? reports[0]
    }

    @MainActor
    static func registerDefaults(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<BrandPlatformConnection>())
        for report in reports where !existing.contains(where: { $0.platform == report.platform }) {
            context.insert(BrandPlatformConnection(
                platform: report.platform,
                accountLabel: report.platform.rawValue,
                accountType: report.accountType,
                capability: report.capability,
                status: report.status,
                officialDocumentURL: report.officialDocumentURL,
                verificationNote: report.verificationNote
            ))
        }
        try context.save()
    }
}

struct BrandPlatformCredential: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

enum BrandPlatformCredentialStore {
    private static func account(for connectionID: UUID) -> String {
        "brand-platform-credential-\(connectionID.uuidString.lowercased())"
    }

    static func save(_ credential: BrandPlatformCredential, connectionID: UUID) throws {
        try KeychainStore.set(JSONEncoder().encode(credential), account: account(for: connectionID))
    }

    static func load(connectionID: UUID) throws -> BrandPlatformCredential? {
        guard let data = try KeychainStore.data(account: account(for: connectionID)) else { return nil }
        return try JSONDecoder().decode(BrandPlatformCredential.self, from: data)
    }

    static func delete(connectionID: UUID) throws {
        try KeychainStore.delete(account: account(for: connectionID))
    }
}

struct BrandRemoteMetricPayload: Equatable, Sendable {
    let remoteItemID: String
    let publishRecordID: UUID
    let collectedAt: Date
    let periodStart: Date
    let periodEnd: Date
    let exposure: Int?
    let views: Int?
    let likes: Int?
    let comments: Int?
    let favorites: Int?
    let shares: Int?
    let profileVisits: Int?
    let followers: Int?
    let privateMessages: Int?
    let missingReasons: String
    let isCumulative: Bool
}

protocol BrandPlatformMetricProvider: Sendable {
    var platform: BrandPlatformKind { get }
    func fetchMetrics(credential: BrandPlatformCredential) async throws -> [BrandRemoteMetricPayload]
}

enum BrandPlatformSyncError: LocalizedError {
    case capabilityUnavailable
    case accountNotApproved
    case missingCredential
    case tokenExpired
    case providerMismatch
    case invalidPayload
    case publishRecordNotFound
    case channelMismatch

    var category: String {
        switch self {
        case .capabilityUnavailable: return "capability_unavailable"
        case .accountNotApproved: return "account_not_approved"
        case .missingCredential: return "missing_credential"
        case .tokenExpired: return "token_expired"
        case .providerMismatch: return "provider_mismatch"
        case .invalidPayload: return "invalid_payload"
        case .publishRecordNotFound: return "publish_record_not_found"
        case .channelMismatch: return "channel_mismatch"
        }
    }

    var errorDescription: String? {
        switch self {
        case .capabilityUnavailable: return "该平台当前没有经过核验的官方指标同步能力，请继续使用人工录入或表格导入。"
        case .accountNotApproved: return "真实账号和接口权限尚未验收，不能启动自动同步。"
        case .missingCredential: return "钥匙串中没有可用的平台凭据。"
        case .tokenExpired: return "平台令牌已过期，请重新授权；历史数据不受影响。"
        case .providerMismatch: return "同步提供方与平台不匹配。"
        case .invalidPayload: return "平台返回的数据范围或指标无效，本次没有写入任何快照。"
        case .publishRecordNotFound: return "同步数据无法关联到现有发布记录，本次没有写入任何快照。"
        case .channelMismatch: return "同步数据的平台与发布记录不一致，本次没有写入任何快照。"
        }
    }
}

enum BrandPlatformAutomationService {
    static let staleInterval: TimeInterval = 48 * 60 * 60

    static func isStale(lastSuccessfulSyncAt: Date?, now: Date = .now) -> Bool {
        guard let lastSuccessfulSyncAt else { return true }
        return now.timeIntervalSince(lastSuccessfulSyncAt) > staleInterval
    }

    static func safeErrorMessage(_ error: Error) -> String {
        if let known = error as? BrandPlatformSyncError {
            return known.localizedDescription
        }
        return "同步未完成。已保留原有数据，请稍后重试或继续人工录入。"
    }

    static func fingerprint(connectionID: UUID, remoteItemID: String) -> String {
        let source = "\(connectionID.uuidString.lowercased())|\(remoteItemID)"
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    static func synchronize(
        connection: BrandPlatformConnection,
        context: ModelContext,
        provider: any BrandPlatformMetricProvider,
        now: Date = .now
    ) async -> BrandSyncRun {
        let run = BrandSyncRun(connectionID: connection.id, requestedAt: now)
        context.insert(run)
        connection.lastAttemptAt = now
        connection.updatedAt = now
        do {
            guard connection.capability == .officialMetricSync else {
                throw BrandPlatformSyncError.capabilityUnavailable
            }
            guard connection.isAPIApproved else { throw BrandPlatformSyncError.accountNotApproved }
            guard provider.platform == connection.platform else { throw BrandPlatformSyncError.providerMismatch }
            guard let credential = try BrandPlatformCredentialStore.load(connectionID: connection.id) else {
                throw BrandPlatformSyncError.missingCredential
            }
            guard credential.expiresAt > now else { throw BrandPlatformSyncError.tokenExpired }
            let payloads = try await provider.fetchMetrics(credential: credential)
            try importPayloads(payloads, connection: connection, run: run, context: context, now: now)
        } catch {
            markFailure(error, connection: connection, run: run, now: now)
            try? context.save()
        }
        return run
    }

    @MainActor
    static func importPayloads(
        _ payloads: [BrandRemoteMetricPayload],
        connection: BrandPlatformConnection,
        run: BrandSyncRun,
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard connection.capability == .officialMetricSync else {
            throw BrandPlatformSyncError.capabilityUnavailable
        }
        guard connection.isAPIApproved else { throw BrandPlatformSyncError.accountNotApproved }

        let publishRecords = try context.fetch(FetchDescriptor<BrandPublishRecord>())
        let recordsByID = Dictionary(uniqueKeysWithValues: publishRecords.map { ($0.id, $0) })
        let existingFingerprints = Set(try context.fetch(FetchDescriptor<BrandSyncItemReceipt>()).map(\.fingerprint))

        var validated: [(BrandRemoteMetricPayload, String)] = []
        var duplicateCount = 0
        for payload in payloads {
            let fingerprint = fingerprint(connectionID: connection.id, remoteItemID: payload.remoteItemID)
            if existingFingerprints.contains(fingerprint) || validated.contains(where: { $0.1 == fingerprint }) {
                duplicateCount += 1
                continue
            }
            guard !payload.remoteItemID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  payload.periodEnd > payload.periodStart,
                  payload.collectedAt <= now.addingTimeInterval(300),
                  allMetrics(in: payload).allSatisfy({ $0 == nil || $0! >= 0 }) else {
                throw BrandPlatformSyncError.invalidPayload
            }
            guard let record = recordsByID[payload.publishRecordID], record.isPublished else {
                throw BrandPlatformSyncError.publishRecordNotFound
            }
            guard record.channel == connection.platform.channel else {
                throw BrandPlatformSyncError.channelMismatch
            }
            validated.append((payload, fingerprint))
        }

        for (payload, fingerprint) in validated {
            let snapshot = BrandMetricSnapshot(
                publishRecordID: payload.publishRecordID,
                collectedAt: payload.collectedAt,
                periodStart: payload.periodStart,
                periodEnd: payload.periodEnd,
                method: .api,
                exposure: payload.exposure,
                views: payload.views,
                likes: payload.likes,
                comments: payload.comments,
                favorites: payload.favorites,
                shares: payload.shares,
                profileVisits: payload.profileVisits,
                followers: payload.followers,
                privateMessages: payload.privateMessages,
                missingReasons: payload.missingReasons,
                sourceFile: "官方接口同步 · \(connection.accountLabel)",
                isCumulative: payload.isCumulative,
                isConfirmed: true
            )
            context.insert(snapshot)
            context.insert(BrandSyncItemReceipt(
                fingerprint: fingerprint,
                connectionID: connection.id,
                remoteItemID: payload.remoteItemID,
                publishRecordID: payload.publishRecordID,
                metricSnapshotID: snapshot.id,
                receivedAt: now
            ))
        }

        run.status = .succeeded
        run.completedAt = now
        run.importedCount = validated.count
        run.skippedDuplicateCount = duplicateCount
        run.safeMessage = validated.isEmpty ? "没有新数据，历史快照保持不变。" : "新增 \(validated.count) 条已确认接口快照。"
        connection.status = .connected
        connection.lastSuccessfulSyncAt = now
        connection.lastErrorCategory = ""
        connection.lastErrorMessage = ""
        connection.updatedAt = now
        try context.save()
    }

    static func markFailure(
        _ error: Error,
        connection: BrandPlatformConnection,
        run: BrandSyncRun,
        now: Date = .now
    ) {
        let known = error as? BrandPlatformSyncError
        run.status = known == .capabilityUnavailable || known == .accountNotApproved ? .skipped : .failed
        run.completedAt = now
        run.errorCategory = known?.category ?? "provider_error"
        run.safeMessage = safeErrorMessage(error)
        switch known {
        case .tokenExpired:
            connection.status = .tokenExpired
        case .accountNotApproved, .missingCredential:
            connection.status = .verificationRequired
        case .capabilityUnavailable:
            connection.status = connection.capability == .basicIdentityOnly ? .manualOnly : connection.status
        default:
            connection.status = .syncFailed
        }
        connection.lastErrorCategory = run.errorCategory
        connection.lastErrorMessage = run.safeMessage
        connection.updatedAt = now
    }

    static func factualComparison(
        experiment: BrandExperiment,
        snapshots: [BrandMetricSnapshot]
    ) -> String {
        let confirmed = snapshots.filter(\.isConfirmed)
        let a = confirmed.filter { $0.publishRecordID == experiment.variantAPublishRecordID }.max(by: { $0.collectedAt < $1.collectedAt })
        let b = confirmed.filter { $0.publishRecordID == experiment.variantBPublishRecordID }.max(by: { $0.collectedAt < $1.collectedAt })
        guard let a, let b else {
            return "数据不足：两个版本都需要至少一条已确认快照，暂不作比较。"
        }
        return "A（\(experiment.variantALabel)）：阅读/播放 \(value(a.views))，互动 \(engagement(a))；B（\(experiment.variantBLabel)）：阅读/播放 \(value(b.views))，互动 \(engagement(b))。仅记录事实，不自动推断因果。"
    }

    private static func allMetrics(in payload: BrandRemoteMetricPayload) -> [Int?] {
        [payload.exposure, payload.views, payload.likes, payload.comments, payload.favorites,
         payload.shares, payload.profileVisits, payload.followers, payload.privateMessages]
    }

    private static func engagement(_ snapshot: BrandMetricSnapshot) -> Int {
        [snapshot.likes, snapshot.comments, snapshot.favorites, snapshot.shares].compactMap { $0 }.reduce(0, +)
    }

    private static func value(_ value: Int?) -> String {
        value.map(String.init) ?? "未提供"
    }
}
