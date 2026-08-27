import Foundation
import SwiftData
import CryptoKit

enum BackupServiceError: LocalizedError {
    case passwordTooShort
    case invalidPackage
    case unsupportedVersion
    case missingMedia(String)
    case integrityCheckFailed(String)
    case unsafePath

    var errorDescription: String? {
        switch self {
        case .passwordTooShort: return "备份密码至少需要 8 位，且不会保存在应用中。"
        case .invalidPackage: return "所选内容不是有效的心塔加密备份。"
        case .unsupportedVersion: return "该备份版本与当前心塔不兼容。"
        case .missingMedia(let name): return "备份失败：找不到资料文件 \(name)。"
        case .integrityCheckFailed(let name): return "备份完整性校验失败：\(name)。"
        case .unsafePath: return "备份中包含不安全的文件路径。"
        }
    }
}

enum BackupService {
    private static let infoFilename = "backup-info.json"
    private static let snapshotFilename = "snapshot.enc"
    private static let chunkSize = 4 * 1024 * 1024

    @MainActor
    static func captureSnapshot(context: ModelContext) throws -> BackupSnapshot {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
        return BackupSnapshot(
            formatVersion: BackupSnapshot.formatVersion,
            createdAt: .now,
            appVersion: version,
            clients: try context.fetch(FetchDescriptor<Client>()).map(BackupClient.init),
            services: try context.fetch(FetchDescriptor<ServiceItem>()).map(BackupServiceItem.init),
            appointments: try context.fetch(FetchDescriptor<Appointment>()).map(BackupAppointment.init),
            consents: try context.fetch(FetchDescriptor<ConsentRecord>()).map(BackupConsent.init),
            records: try context.fetch(FetchDescriptor<ConsultationRecord>()).map(BackupConsultation.init),
            mediaAssets: try context.fetch(FetchDescriptor<MediaAsset>()).map(BackupMediaAsset.init),
            payments: try context.fetch(FetchDescriptor<PaymentTransaction>()).map(BackupPaymentTransaction.init),
            serviceOrders: try context.fetch(FetchDescriptor<ServiceOrder>()).map(BackupServiceOrder.init),
            orderPayments: try context.fetch(FetchDescriptor<OrderPaymentTransaction>()).map(BackupOrderPaymentTransaction.init),
            entitlementRedemptions: try context.fetch(FetchDescriptor<EntitlementRedemption>()).map(BackupEntitlementRedemption.init),
            serviceOrderChanges: try context.fetch(FetchDescriptor<ServiceOrderChange>()).map(BackupServiceOrderChange.init),
            consultationActivities: try context.fetch(FetchDescriptor<ConsultationActivity>()).map(BackupConsultationActivity.init),
            consultationSummaryRevisions: try context.fetch(FetchDescriptor<ConsultationSummaryRevision>()).map(BackupConsultationSummaryRevision.init),
            mediaFiles: [],
            brandProfiles: try context.fetch(FetchDescriptor<BrandProfile>()).map(BackupBrandProfile.init),
            brandTopics: try context.fetch(FetchDescriptor<BrandContentTopic>()).map(BackupBrandTopic.init),
            brandDrafts: try context.fetch(FetchDescriptor<BrandDraft>()).map(BackupBrandDraft.init),
            brandDraftRevisions: try context.fetch(FetchDescriptor<BrandDraftRevision>()).map(BackupBrandDraftRevision.init),
            brandPublishRecords: try context.fetch(FetchDescriptor<BrandPublishRecord>()).map(BackupBrandPublishRecord.init),
            brandAssets: try context.fetch(FetchDescriptor<BrandAsset>()).map(BackupBrandAsset.init),
            brandMetricSnapshots: try context.fetch(FetchDescriptor<BrandMetricSnapshot>()).map(BackupBrandMetricSnapshot.init),
            brandWeeklyReviews: try context.fetch(FetchDescriptor<BrandWeeklyReview>()).map(BackupBrandWeeklyReview.init),
            brandMarketingTouchpoints: try context.fetch(FetchDescriptor<BrandMarketingTouchpoint>()).map(BackupBrandMarketingTouchpoint.init),
            brandAssetAudits: try context.fetch(FetchDescriptor<BrandAssetAuditEvent>()).map(BackupBrandAssetAudit.init),
            brandAssetUsages: try context.fetch(FetchDescriptor<BrandAssetUsage>()).map(BackupBrandAssetUsage.init),
            brandAssetTasks: try context.fetch(FetchDescriptor<BrandAssetActionTask>()).map(BackupBrandAssetTask.init),
            brandFiles: []
        )
    }

    static func createBackup(
        snapshot originalSnapshot: BackupSnapshot,
        password: String,
        destinationFolder: URL,
        mediaRoot: URL? = nil,
        brandAssetRoot: URL? = nil
    ) async throws -> URL {
        guard password.count >= 8 else { throw BackupServiceError.passwordTooShort }
        return try await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let filename = "心塔备份-\(formatter.string(from: .now))-\(UUID().uuidString.prefix(6)).xintabackup"
            let package = destinationFolder.appendingPathComponent(filename, isDirectory: true)
            let mediaDirectory = package.appendingPathComponent("media", isDirectory: true)
            let brandDirectory = package.appendingPathComponent("brand-media", isDirectory: true)
            do {
                try manager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
                try manager.createDirectory(at: brandDirectory, withIntermediateDirectories: true)
                let salt = try PasswordCrypto.randomData(count: 16)
                let key = try PasswordCrypto.deriveKey(password: password, salt: salt)
                var snapshot = originalSnapshot
                var mediaFiles: [BackupMediaFile] = []

                for asset in snapshot.mediaAssets {
                    let source = try mediaRoot?.appendingPathComponent(asset.relativePath)
                        ?? MediaStorageService.absoluteURL(for: asset.relativePath)
                    guard manager.isReadableFile(atPath: source.path) else {
                        throw BackupServiceError.missingMedia(asset.originalFilename)
                    }
                    let assetDirectory = mediaDirectory.appendingPathComponent(asset.id.uuidString, isDirectory: true)
                    try manager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
                    let input = try FileHandle(forReadingFrom: source)
                    defer { try? input.close() }
                    var hasher = SHA256()
                    var index = 0
                    var byteCount: Int64 = 0
                    while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
                        hasher.update(data: chunk)
                        byteCount += Int64(chunk.count)
                        let encrypted = try PasswordCrypto.seal(chunk, keyData: key)
                        let target = assetDirectory.appendingPathComponent(String(format: "%06d.enc", index))
                        try encrypted.write(to: target, options: .atomic)
                        index += 1
                    }
                    mediaFiles.append(BackupMediaFile(
                        assetID: asset.id,
                        relativePath: asset.relativePath,
                        byteCount: byteCount,
                        chunkCount: index,
                        sha256: Data(hasher.finalize()).hexString
                    ))
                }

                snapshot.mediaFiles = mediaFiles
                var brandFiles: [BackupBrandFile] = []
                for asset in snapshot.brandAssets ?? [] {
                    guard let relativePath = asset.relativePath, !relativePath.isEmpty else { continue }
                    let source = try brandAssetRoot?.appendingPathComponent(relativePath)
                        ?? BrandAssetStorageService.absoluteURL(for: relativePath)
                    guard manager.isReadableFile(atPath: source.path) else {
                        throw BackupServiceError.missingMedia(asset.originalFilename ?? asset.name)
                    }
                    let assetDirectory = brandDirectory.appendingPathComponent(asset.id.uuidString, isDirectory: true)
                    try manager.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
                    let input = try FileHandle(forReadingFrom: source)
                    defer { try? input.close() }
                    var hasher = SHA256()
                    var index = 0
                    var byteCount: Int64 = 0
                    while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
                        hasher.update(data: chunk)
                        byteCount += Int64(chunk.count)
                        let encrypted = try PasswordCrypto.seal(chunk, keyData: key)
                        try encrypted.write(
                            to: assetDirectory.appendingPathComponent(String(format: "%06d.enc", index)),
                            options: .atomic
                        )
                        index += 1
                    }
                    brandFiles.append(BackupBrandFile(
                        assetID: asset.id,
                        relativePath: relativePath,
                        byteCount: byteCount,
                        chunkCount: index,
                        sha256: Data(hasher.finalize()).hexString
                    ))
                }
                snapshot.brandFiles = brandFiles
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let snapshotData = try encoder.encode(snapshot)
                let encryptedSnapshot = try PasswordCrypto.seal(snapshotData, keyData: key)
                try encryptedSnapshot.write(to: package.appendingPathComponent(snapshotFilename), options: .atomic)

                let info = BackupPublicInfo(
                    formatVersion: BackupSnapshot.formatVersion,
                    createdAt: snapshot.createdAt,
                    salt: salt,
                    iterations: PasswordCrypto.defaultIterations,
                    chunkSize: chunkSize,
                    snapshotFilename: snapshotFilename
                )
                try encoder.encode(info).write(to: package.appendingPathComponent(infoFilename), options: .atomic)
                return package
            } catch {
                if manager.fileExists(atPath: package.path) {
                    try? manager.removeItem(at: package)
                }
                throw error
            }
        }.value
    }

    static func validateBackup(at package: URL, password: String) async throws -> BackupSnapshot {
        let prepared = try await prepareRestore(from: package, password: password, writeMedia: false)
        try? FileManager.default.removeItem(at: prepared.stagedMediaRoot.deletingLastPathComponent())
        return prepared.snapshot
    }

    static func prepareRestore(from package: URL, password: String) async throws -> PreparedRestore {
        try await prepareRestore(from: package, password: password, writeMedia: true)
    }

    private static func prepareRestore(
        from package: URL,
        password: String,
        writeMedia: Bool
    ) async throws -> PreparedRestore {
        guard password.count >= 8 else { throw BackupServiceError.passwordTooShort }
        return try await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: package.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw BackupServiceError.invalidPackage
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let infoURL = package.appendingPathComponent(infoFilename)
            guard let infoData = try? Data(contentsOf: infoURL),
                  let info = try? decoder.decode(BackupPublicInfo.self, from: infoData) else {
                throw BackupServiceError.invalidPackage
            }
            guard (2...BackupSnapshot.formatVersion).contains(info.formatVersion),
                  info.iterations >= 100_000,
                  info.iterations <= 1_000_000,
                  info.chunkSize > 0,
                  info.chunkSize <= 16 * 1024 * 1024,
                  info.snapshotFilename == snapshotFilename else {
                throw BackupServiceError.unsupportedVersion
            }
            let key = try PasswordCrypto.deriveKey(password: password, salt: info.salt, iterations: info.iterations)
            let encryptedSnapshot = try Data(contentsOf: package.appendingPathComponent(info.snapshotFilename))
            let snapshotData = try PasswordCrypto.open(encryptedSnapshot, keyData: key)
            let snapshot = try decoder.decode(BackupSnapshot.self, from: snapshotData)
            guard snapshot.formatVersion == info.formatVersion,
                  (2...BackupSnapshot.formatVersion).contains(snapshot.formatVersion) else {
                throw BackupServiceError.unsupportedVersion
            }
            guard Set(snapshot.mediaAssets.map(\.id)) == Set(snapshot.mediaFiles.map(\.assetID)) else {
                throw BackupServiceError.integrityCheckFailed("资料清单不一致")
            }
            let brandAssetsWithFiles = Set((snapshot.brandAssets ?? []).compactMap { asset in
                asset.relativePath?.isEmpty == false ? asset.id : nil
            })
            guard brandAssetsWithFiles == Set((snapshot.brandFiles ?? []).map(\.assetID)) else {
                throw BackupServiceError.integrityCheckFailed("品牌素材清单不一致")
            }

            let temporary = manager.temporaryDirectory.appendingPathComponent("SoulTowerRestore-\(UUID().uuidString)", isDirectory: true)
            let stagedRoot = temporary.appendingPathComponent("Media", isDirectory: true)
            let stagedBrandRoot = temporary.appendingPathComponent("BrandAssets", isDirectory: true)
            try manager.createDirectory(at: stagedRoot, withIntermediateDirectories: true)
            try manager.createDirectory(at: stagedBrandRoot, withIntermediateDirectories: true)
            do {
                for file in snapshot.mediaFiles {
                    guard isSafeRelativePath(file.relativePath) else { throw BackupServiceError.unsafePath }
                    guard let asset = snapshot.mediaAssets.first(where: { $0.id == file.assetID }) else {
                        throw BackupServiceError.integrityCheckFailed("资料索引缺失")
                    }
                    let sourceDirectory = package.appendingPathComponent("media/\(file.assetID.uuidString)", isDirectory: true)
                    let outputURL = stagedRoot.appendingPathComponent(file.relativePath)
                    if writeMedia {
                        try manager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        manager.createFile(atPath: outputURL.path, contents: nil)
                    }
                    let output = writeMedia ? try FileHandle(forWritingTo: outputURL) : nil
                    defer { try? output?.close() }
                    var hasher = SHA256()
                    var byteCount: Int64 = 0
                    for index in 0..<file.chunkCount {
                        let chunkURL = sourceDirectory.appendingPathComponent(String(format: "%06d.enc", index))
                        guard manager.isReadableFile(atPath: chunkURL.path) else {
                            throw BackupServiceError.integrityCheckFailed(asset.originalFilename)
                        }
                        let decrypted = try PasswordCrypto.open(Data(contentsOf: chunkURL), keyData: key)
                        hasher.update(data: decrypted)
                        byteCount += Int64(decrypted.count)
                        try output?.write(contentsOf: decrypted)
                    }
                    let digest = Data(hasher.finalize()).hexString
                    guard byteCount == file.byteCount, digest == file.sha256 else {
                        throw BackupServiceError.integrityCheckFailed(asset.originalFilename)
                    }
                }
                for file in snapshot.brandFiles ?? [] {
                    guard isSafeRelativePath(file.relativePath) else { throw BackupServiceError.unsafePath }
                    guard let asset = (snapshot.brandAssets ?? []).first(where: { $0.id == file.assetID }) else {
                        throw BackupServiceError.integrityCheckFailed("品牌素材索引缺失")
                    }
                    let sourceDirectory = package.appendingPathComponent("brand-media/\(file.assetID.uuidString)", isDirectory: true)
                    let outputURL = stagedBrandRoot.appendingPathComponent(file.relativePath)
                    if writeMedia {
                        try manager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        manager.createFile(atPath: outputURL.path, contents: nil)
                    }
                    let output = writeMedia ? try FileHandle(forWritingTo: outputURL) : nil
                    defer { try? output?.close() }
                    var hasher = SHA256()
                    var byteCount: Int64 = 0
                    for index in 0..<file.chunkCount {
                        let chunkURL = sourceDirectory.appendingPathComponent(String(format: "%06d.enc", index))
                        guard manager.isReadableFile(atPath: chunkURL.path) else {
                            throw BackupServiceError.integrityCheckFailed(asset.originalFilename ?? asset.name)
                        }
                        let decrypted = try PasswordCrypto.open(Data(contentsOf: chunkURL), keyData: key)
                        hasher.update(data: decrypted)
                        byteCount += Int64(decrypted.count)
                        try output?.write(contentsOf: decrypted)
                    }
                    guard byteCount == file.byteCount, Data(hasher.finalize()).hexString == file.sha256 else {
                        throw BackupServiceError.integrityCheckFailed(asset.originalFilename ?? asset.name)
                    }
                }
                return PreparedRestore(snapshot: snapshot, stagedMediaRoot: stagedRoot, stagedBrandAssetRoot: stagedBrandRoot)
            } catch {
                try? manager.removeItem(at: temporary)
                throw error
            }
        }.value
    }

    @MainActor
    static func applyRestore(_ prepared: PreparedRestore, context: ModelContext) throws {
        let rollback = try captureSnapshot(context: context)
        do {
            try replaceModels(with: prepared.snapshot, context: context)
            try MediaStorageService.replaceMediaRoot(with: prepared.stagedMediaRoot)
            if let stagedBrandAssetRoot = prepared.stagedBrandAssetRoot {
                try BrandAssetStorageService.replaceBrandAssetRoot(with: stagedBrandAssetRoot)
            }
        } catch {
            context.rollback()
            try? replaceModels(with: rollback, context: context)
            throw error
        }
        try? FileManager.default.removeItem(at: prepared.stagedMediaRoot.deletingLastPathComponent())
    }

    #if DEBUG
    @MainActor
    static func applySnapshotModelsForTesting(_ snapshot: BackupSnapshot, context: ModelContext) throws {
        try replaceModels(with: snapshot, context: context)
    }
    #endif

    @MainActor
    static func rebuildFutureReminders(context: ModelContext) async {
        let status = await NotificationScheduler.authorizationStatus()
        let allowed: Bool
        switch status {
        case .authorized, .provisional:
            allowed = true
        #if os(iOS)
        case .ephemeral:
            allowed = true
        #endif
        default:
            allowed = false
        }
        guard allowed else { return }
        let appointments = (try? context.fetch(FetchDescriptor<Appointment>())) ?? []
        for appointment in appointments where appointment.status == .confirmed && appointment.startAt > .now {
            if let identifiers = try? await NotificationScheduler.schedule(for: appointment) {
                appointment.reminder24Identifier = identifiers.0
                appointment.reminder1Identifier = identifiers.1
            }
        }
        try? context.save()
    }

    @MainActor
    private static func replaceModels(with snapshot: BackupSnapshot, context: ModelContext) throws {
        let existingAppointments = try context.fetch(FetchDescriptor<Appointment>())
        existingAppointments.forEach(NotificationScheduler.cancel)

        try context.fetch(FetchDescriptor<BrandAssetActionTask>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandAssetUsage>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandAssetAuditEvent>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandMarketingTouchpoint>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandWeeklyReview>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandMetricSnapshot>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandPublishRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandDraftRevision>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandDraft>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandContentTopic>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandAsset>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<BrandProfile>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<MediaAsset>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ConsultationActivity>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ConsultationSummaryRevision>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ServiceOrderChange>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<EntitlementRedemption>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<OrderPaymentTransaction>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<PaymentTransaction>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ConsentRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ConsultationRecord>()).forEach(context.delete)
        existingAppointments.forEach(context.delete)
        try context.fetch(FetchDescriptor<ServiceOrder>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ServiceItem>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Client>()).forEach(context.delete)

        snapshot.clients.map { $0.model() }.forEach(context.insert)
        snapshot.services.map { $0.model() }.forEach(context.insert)
        snapshot.appointments.map { item in
            let model = item.model()
            model.reminder24Identifier = ""
            model.reminder1Identifier = ""
            return model
        }.forEach(context.insert)
        snapshot.consents.map { $0.model() }.forEach(context.insert)
        snapshot.records.map { $0.model() }.forEach(context.insert)
        snapshot.mediaAssets.map { $0.model() }.forEach(context.insert)
        (snapshot.payments ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.serviceOrders ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.orderPayments ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.entitlementRedemptions ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.serviceOrderChanges ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.consultationActivities ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.consultationSummaryRevisions ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandProfiles ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandTopics ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandDrafts ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandDraftRevisions ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandPublishRecords ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandAssets ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandMetricSnapshots ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandWeeklyReviews ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandMarketingTouchpoints ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandAssetAudits ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandAssetUsages ?? []).map { $0.model() }.forEach(context.insert)
        (snapshot.brandAssetTasks ?? []).map { $0.model() }.forEach(context.insert)
        try context.save()
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let components = NSString(string: path).pathComponents
        return !components.contains("..") && !components.contains("~")
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
