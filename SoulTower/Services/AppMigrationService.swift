import Foundation
import SwiftData

private struct AppMigrationState: Codable {
    var version: Int
    var updatedAt: Date
}

enum AppMigrationService {
    static let currentVersion = 11

    @MainActor
    static func run(context: ModelContext) throws -> String {
        var state = try loadState() ?? AppMigrationState(version: 1, updatedAt: .now)
        guard state.version <= currentVersion else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "本机数据版本高于当前应用，请升级心塔后再打开。"
            ])
        }

        var completedSteps: [String] = []
        if state.version < 2 {
            try backfillConsentSnapshots(context: context)
            state.version = 2
            state.updatedAt = .now
            completedSteps.append("告知文本")
        }
        if state.version < 3 {
            try backfillLegacyPaymentTransactions(context: context)
            state.version = 3
            state.updatedAt = .now
            completedSteps.append("收付款流水")
        }
        if state.version < 4 {
            state.version = 4
            state.updatedAt = .now
            completedSteps.append("套餐与项目订单")
        }
        if state.version < 5 {
            state.version = 5
            state.updatedAt = .now
            completedSteps.append("套餐售后与订单变更")
        }
        if state.version < 6 {
            try backfillConsultationArchiveHistory(context: context)
            state.version = 6
            state.updatedAt = .now
            completedSteps.append("咨询过程归档与留痕")
        }
        if state.version < 7 {
            try backfillV08BusinessStructure(context: context)
            state.version = 7
            state.updatedAt = .now
            completedSteps.append("产品、订单与套餐权益拆分")
        }
        if state.version < 8 {
            try backfillBrandDefaults(context: context)
            state.version = 8
            state.updatedAt = .now
            completedSteps.append("品牌增长初始模型接入")
        }
        if state.version < 9 {
            state.version = 9
            state.updatedAt = .now
            completedSteps.append("品牌数据、归因与周复盘接入")
        }
        if state.version < 10 {
            state.version = 10
            state.updatedAt = .now
            completedSteps.append("品牌素材、匿名授权与撤回闭环接入")
        }
        if state.version < 11 {
            try BrandPlatformCapabilityRegistry.registerDefaults(context: context)
            state.version = 11
            state.updatedAt = .now
            completedSteps.append("平台能力、同步恢复与优化实验接入")
        }
        if !completedSteps.isEmpty {
            try saveState(state)
            return "已安全升级到 V\(currentVersion)（\(completedSteps.joined(separator: "、"))）"
        }
        return "V\(currentVersion)，已是最新"
    }

    @MainActor
    static func backfillBrandDefaults(context: ModelContext) throws {
        let descriptor = FetchDescriptor<BrandProfile>()
        let count = try context.fetchCount(descriptor)
        if count == 0 {
            context.insert(BrandProfile.defaultProfile())
            try context.save()
        }
    }

    @MainActor
    static func backfillV08BusinessStructure(context: ModelContext) throws {
        let services = try context.fetch(FetchDescriptor<ServiceItem>())
        let serviceByID = Dictionary(uniqueKeysWithValues: services.map { ($0.id, $0) })
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        let appointmentByID = Dictionary(uniqueKeysWithValues: appointments.map { ($0.id, $0) })
        let orders = try context.fetch(FetchDescriptor<ServiceOrder>())
        let redemptions = try context.fetch(FetchDescriptor<EntitlementRedemption>())
        var changed = false

        for service in services where service.productKindRaw == nil {
            service.productKindRaw = service.productKind.rawValue
            changed = true
        }

        for order in orders {
            if order.productKindRaw == nil {
                order.productKindRaw = serviceByID[order.serviceID]?.productKind.rawValue ?? order.productKind.rawValue
                changed = true
            }
            if order.productKind == .project, order.projectStageRaw == nil {
                order.projectStage = order.status == .completed ? .archived : (order.status == .active ? .inProgress : .awaitingDeposit)
                changed = true
            }
            if order.validDaysSnapshot == nil {
                order.validDaysSnapshot = serviceByID[order.serviceID]?.validDays ?? 0
                changed = true
            }
            if order.activatedAt == nil, [.active, .completed, .expired].contains(order.status) {
                order.activatedAt = order.validFrom
                changed = true
            }
        }

        for redemption in redemptions where redemption.stateRaw == nil {
            redemption.state = appointmentByID[redemption.appointmentID]?.status == .completed ? .consumed : .reserved
            changed = true
        }

        if changed { try context.save() }
    }

    @MainActor
    static func backfillConsultationArchiveHistory(context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<ConsultationRecord>())
        let existingActivities = try context.fetch(FetchDescriptor<ConsultationActivity>())
        let activityRecordIDs = Set(existingActivities.map(\.recordID))
        let existingRevisions = try context.fetch(FetchDescriptor<ConsultationSummaryRevision>())
        let revisionRecordIDs = Set(existingRevisions.map(\.recordID))
        var changed = false

        for record in records {
            if !activityRecordIDs.contains(record.id) {
                context.insert(ConsultationWorkflowService.activity(
                    record: record,
                    kind: .recordCreated,
                    title: "旧版咨询资料接入 V0.7 归档流程",
                    detail: "原有转写和摘要内容保持不变",
                    at: record.createdAt
                ))
                changed = true
            }
            if !record.formalSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !revisionRecordIDs.contains(record.id) {
                let version = max(record.formalSummaryVersion, 1)
                record.formalSummaryVersion = version
                context.insert(ConsultationSummaryRevision(
                    recordID: record.id,
                    clientID: record.clientID,
                    version: version,
                    content: record.formalSummary,
                    aiModelName: record.aiModelName,
                    approvedAt: record.approvedAt ?? record.updatedAt,
                    createdAt: record.updatedAt
                ))
                changed = true
            }
        }
        if changed { try context.save() }
    }

    @MainActor
    static func backfillConsentSnapshots(context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<ConsentRecord>())
        var changed = false
        for record in records where record.textSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch record.type {
            case .servicePolicy: record.textSnapshot = DefaultBusinessRules.servicePolicySummary
            case .recording: record.textSnapshot = DefaultBusinessRules.recordingConsentNotice
            case .photo: record.textSnapshot = DefaultBusinessRules.photoConsentNotice
            case .localAI: record.textSnapshot = DefaultBusinessRules.localAIConsentNotice
            case .longTermRetention: record.textSnapshot = DefaultBusinessRules.retentionNotice
            case .anonymousContentUse: record.textSnapshot = "仅允许在已保存范围、平台和期限内使用完成去身份化复核的客户内容；客户可随时撤回。"
            }
            changed = true
        }
        if changed { try context.save() }
    }

    @MainActor
    static func backfillLegacyPaymentTransactions(context: ModelContext) throws {
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        let existing = try context.fetch(FetchDescriptor<PaymentTransaction>())
        let existingAppointmentIDs = Set(existing.map(\.appointmentID))
        var changed = false

        for appointment in appointments where
            appointment.status != .rescheduled &&
            appointment.priceCents > 0 &&
            !existingAppointmentIDs.contains(appointment.id) {
            switch appointment.paymentStatus {
            case .paid:
                context.insert(legacyTransaction(
                    appointment: appointment,
                    kind: .servicePayment,
                    amountCents: appointment.priceCents,
                    note: "由 V0.3 的“已付款”状态迁移，请按实际微信或转账记录核对。"
                ))
                changed = true
            case .balance:
                context.insert(legacyTransaction(
                    appointment: appointment,
                    kind: .balanceOffset,
                    amountCents: appointment.priceCents,
                    note: "由 V0.3 的“余额抵扣”状态迁移，请核对余额来源。"
                ))
                changed = true
            case .refunded:
                context.insert(legacyTransaction(
                    appointment: appointment,
                    kind: .servicePayment,
                    amountCents: appointment.priceCents,
                    note: "由 V0.3 的“已退款”状态迁移：补建原收款。"
                ))
                context.insert(legacyTransaction(
                    appointment: appointment,
                    kind: .refund,
                    amountCents: appointment.priceCents,
                    note: "由 V0.3 的“已退款”状态迁移：补建退款。"
                ))
                changed = true
            case .unpaid, .partial, .entitlement:
                break
            }
        }
        if changed { try context.save() }
    }

    private static func legacyTransaction(
        appointment: Appointment,
        kind: PaymentTransactionKind,
        amountCents: Int,
        note: String
    ) -> PaymentTransaction {
        PaymentTransaction(
            appointmentID: appointment.id,
            clientID: appointment.clientID,
            clientCode: appointment.clientCode,
            serviceNameSnapshot: appointment.serviceNameSnapshot,
            kind: kind,
            method: kind == .balanceOffset ? .balance : .legacy,
            amountCents: amountCents,
            occurredAt: appointment.createdAt,
            note: note,
            createdAt: .now
        )
    }

    private static func stateURL() throws -> URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = support.appendingPathComponent("SoulTower/Migrations", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("migration-state.json")
    }

    private static func loadState() throws -> AppMigrationState? {
        let url = try stateURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppMigrationState.self, from: Data(contentsOf: url))
    }

    private static func saveState(_ state: AppMigrationState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: stateURL(), options: .atomic)
    }
}
