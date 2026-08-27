import Foundation
import SwiftData

@MainActor
enum SeedService {
    static func seedServiceCatalogIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<ServiceItem>()
        guard try context.fetchCount(descriptor) == 0 else { return }

        defaultServices.forEach(context.insert)
        try context.save()
    }

    static func insertDemoData(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Client>())
        guard !existing.contains(where: { $0.clientCode == "C-DEMO" }) else { return }
        guard let service = try context.fetch(FetchDescriptor<ServiceItem>(sortBy: [SortDescriptor(\.sortOrder)])).first else { return }

        let client = Client(
            clientCode: "C-DEMO",
            displayName: "演示客户",
            wechatNickname: "仅供体验",
            source: "演示数据",
            notes: "这是一条可安全删除的演示记录，不是真实客户。"
        )
        context.insert(client)

        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let start = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: base) ?? base
        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            startAt: start,
            endAt: start.addingTimeInterval(TimeInterval(max(service.durationMinutes, 30) * 60)),
            status: .confirmed,
            paymentStatus: .paid,
            videoDevice: .mac,
            priceCents: service.priceCents,
            policyVersion: DefaultBusinessRules.policyVersion,
            notes: "演示预约"
        )
        context.insert(appointment)
        context.insert(PaymentTransaction(
            appointmentID: appointment.id,
            clientID: client.id,
            clientCode: client.clientCode,
            serviceNameSnapshot: service.name,
            kind: .servicePayment,
            method: .wechat,
            amountCents: service.priceCents,
            note: "演示预约收款"
        ))
        try context.save()
    }

    #if DEBUG
    static func insertV06UITestData(context: ModelContext) throws {
        let code = "C-UI-V06"
        guard !((try context.fetch(FetchDescriptor<Client>())).contains { $0.clientCode == code }) else { return }
        guard let service = (try context.fetch(FetchDescriptor<ServiceItem>())).first(where: { $0.includedSessions > 1 }) else { return }

        let client = Client(
            clientCode: code,
            displayName: "界面验证客户",
            source: "自动界面测试",
            notes: "仅用于 V0.6 界面验证的虚构资料"
        )
        context.insert(client)
        let expiresAt = Calendar.current.date(byAdding: .day, value: max(service.validDays, 30), to: .now)
        let order = ServiceOrder(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            categorySnapshot: service.category,
            deliveryType: service.deliveryType,
            pricingMode: service.pricingMode,
            totalPriceCents: service.priceCents,
            includedSessions: service.includedSessions,
            status: .active,
            paymentStatus: .paid,
            policyVersion: DefaultBusinessRules.policyVersion,
            expiresAt: expiresAt,
            notes: "V0.6 界面验证套餐"
        )
        context.insert(order)
        context.insert(OrderPaymentTransaction(
            orderID: order.id,
            clientID: client.id,
            clientCode: client.clientCode,
            serviceNameSnapshot: service.name,
            kind: .servicePayment,
            method: .wechat,
            amountCents: service.priceCents,
            note: "界面测试虚构收款"
        ))

        let appointmentStart = Date.now.addingTimeInterval(900)
        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceOrderID: order.id,
            serviceNameSnapshot: service.name,
            startAt: appointmentStart,
            endAt: appointmentStart.addingTimeInterval(3_600),
            status: .confirmed,
            paymentStatus: .entitlement,
            priceCents: service.priceCents,
            policyVersion: DefaultBusinessRules.policyVersion,
            notes: "V0.6 界面验证预约"
        )
        context.insert(appointment)
        context.insert(EntitlementRedemption(
            orderID: order.id,
            appointmentID: appointment.id,
            clientID: client.id,
            clientCode: client.clientCode,
            serviceNameSnapshot: service.name,
            note: "界面验证核销"
        ))
        context.insert(ServiceOrderChangeService.audit(
            order: order,
            kind: .scopeChanged,
            title: "服务范围确认",
            beforeValue: "初步需求",
            afterValue: "确认交付范围",
            reason: "V0.6 界面验证记录"
        ))
        try context.save()
    }

    static func insertV07UITestData(context: ModelContext) throws {
        let code = "C-UI-V07"
        guard !((try context.fetch(FetchDescriptor<Client>())).contains { $0.clientCode == code }) else { return }
        guard let service = (try context.fetch(FetchDescriptor<ServiceItem>())).first(where: { $0.deliveryType == .video }) else { return }

        let client = Client(
            clientCode: code,
            displayName: "归档验证客户",
            source: "自动界面测试",
            notes: "仅用于 V0.7 咨询归档界面验证的虚构资料"
        )
        context.insert(client)
        let start = Date.now.addingTimeInterval(-7_200)
        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            startAt: start,
            endAt: start.addingTimeInterval(3_600),
            status: .completed,
            paymentStatus: .paid,
            videoDevice: .mac,
            priceCents: service.priceCents,
            policyVersion: DefaultBusinessRules.policyVersion,
            notes: "V0.7 界面验证预约"
        )
        context.insert(appointment)
        for type in [ConsentType.servicePolicy, .recording, .photo, .localAI, .longTermRetention] {
            context.insert(ConsentRecord(
                clientID: client.id,
                appointmentID: appointment.id,
                type: type,
                textVersion: "UI-TEST-V07",
                textSnapshot: "V0.7 界面测试虚构同意文本",
                accepted: true
            ))
        }

        let transcript = "客户希望梳理近期关系沟通中的压力。本段为界面测试虚构转写，不包含真实客户资料。"
        let record = ConsultationRecord(
            appointmentID: appointment.id,
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceName: service.name,
            occurredAt: start,
            transcriptText: transcript,
            summaryDraft: "## 本次主题\n关系沟通压力（界面测试虚构内容）",
            aiStatus: .draft,
            aiModelName: "qwen3.5:4b",
            transcriptSource: .manual,
            transcriptUpdatedAt: .now
        )
        context.insert(record)
        context.insert(ConsultationWorkflowService.activity(
            record: record,
            kind: .recordCreated,
            title: "建立 V0.7 界面验证资料",
            detail: "全部为虚构测试数据"
        ))
        try context.save()
    }

    static func insertBrandM2UITestData(context: ModelContext) throws {
        let clientCode = "C-UI-M2"
        guard !((try context.fetch(FetchDescriptor<Client>())).contains { $0.clientCode == clientCode }) else { return }
        guard let service = try context.fetch(FetchDescriptor<ServiceItem>(sortBy: [SortDescriptor(\.sortOrder)])).first,
              let profile = try context.fetch(FetchDescriptor<BrandProfile>()).first else { return }

        let week = BrandGrowthAnalyticsService.naturalWeek(containing: .now)
        let publishedAt = max(week.start.addingTimeInterval(3_600), Date.now.addingTimeInterval(-86_400))
        let topic = BrandContentTopic(
            profileID: profile.id,
            title: "测试内容：边界练习",
            rawIdea: "把事实、感受和请求分开记录。全部为虚构测试内容。",
            targetAudience: "界面验证人群",
            pillar: "心理成长练习",
            goal: .inquiry,
            sourceType: .personalOpinion,
            sensitivity: "公开测试内容",
            customerReference: "",
            actionHint: "保存练习清单",
            priority: 1,
            status: .completed
        )
        context.insert(topic)
        let publishRecord = BrandPublishRecord(
            topicID: topic.id,
            channel: .wechatMoments,
            publishedAt: publishedAt,
            platformPostID: "UI-M2-POST-001",
            note: "自动界面测试虚构发布记录",
            snapshotTitle: topic.title,
            snapshotContent: topic.rawIdea,
            publishedAsApproved: true,
            collectedBy: "自动界面测试"
        )
        context.insert(publishRecord)
        let snapshot = BrandMetricSnapshot(
            publishRecordID: publishRecord.id,
            collectedAt: .now,
            periodStart: publishedAt,
            periodEnd: .now.addingTimeInterval(1),
            method: .manual,
            exposure: 320,
            views: 180,
            likes: 21,
            comments: 4,
            favorites: 12,
            shares: 3,
            profileVisits: 8,
            followers: nil,
            privateMessages: 1,
            missingReasons: "平台未提供新增关注",
            sourceFile: "自动界面测试",
            isConfirmed: true
        )
        context.insert(snapshot)

        let client = Client(
            clientCode: clientCode,
            displayName: "品牌归因测试客户",
            source: "自动界面测试",
            notes: "仅用于 M2 临时界面验证的虚构客户"
        )
        context.insert(client)
        let appointment = Appointment(
            clientID: client.id,
            clientCode: client.clientCode,
            clientNameSnapshot: client.displayName,
            serviceID: service.id,
            serviceNameSnapshot: service.name,
            startAt: min(Date.now, week.end.addingTimeInterval(-3_600)),
            endAt: min(Date.now, week.end.addingTimeInterval(-3_600)).addingTimeInterval(3_600),
            status: .completed,
            paymentStatus: .paid,
            priceCents: 66_600,
            policyVersion: DefaultBusinessRules.policyVersion,
            notes: "M2 自动界面测试预约"
        )
        context.insert(appointment)
        let payment = PaymentTransaction(
            appointmentID: appointment.id,
            clientID: client.id,
            clientCode: client.clientCode,
            serviceNameSnapshot: service.name,
            kind: .servicePayment,
            method: .wechat,
            amountCents: 66_600,
            occurredAt: min(Date.now, week.end.addingTimeInterval(-1_800)),
            note: "M2 自动界面测试虚构实收"
        )
        context.insert(payment)
        let touchpoint = BrandMarketingTouchpoint(
            clientID: client.id,
            clientCodeSnapshot: client.clientCode,
            clientNameSnapshot: client.displayName,
            channel: .wechatMoments,
            publishRecordID: publishRecord.id,
            keyword: "边界练习",
            firstContactAt: min(Date.now, week.end.addingTimeInterval(-7_200)),
            evidence: .confirmedContent,
            confirmationMethod: "自动界面测试：客户主动说明",
            note: "全部为虚构数据"
        )
        context.insert(touchpoint)

        let draft = BrandGrowthAnalyticsService.makeWeeklyReview(
            interval: week,
            publishRecords: [publishRecord],
            snapshots: [snapshot],
            touchpoints: [touchpoint],
            appointments: [appointment],
            orders: [],
            appointmentPayments: [payment],
            orderPayments: []
        )
        let review = BrandWeeklyReview(
            periodStart: draft.periodStart,
            periodEnd: draft.periodEnd,
            plannedGenerateAt: draft.plannedGenerateAt,
            generatedAt: draft.generatedAt,
            summaryText: draft.facts,
            conclusionText: draft.interpretation,
            bestText: draft.best,
            worstText: draft.worst,
            conversionText: draft.conversion,
            channelWechatRole: draft.wechatRole,
            channelXhsRole: draft.xiaohongshuRole,
            dataGapText: draft.dataGaps,
            continueText: draft.continueDoing,
            stopText: draft.stopDoing,
            experimentText: draft.experiments,
            usedSnapshotIDsText: draft.usedSnapshotIDs.map(\.uuidString).joined(separator: "\n")
        )
        context.insert(review)
        try context.save()
    }

    static func insertBrandM3UITestData(context: ModelContext) throws {
        let clientCode = "C-UI-M3"
        guard !((try context.fetch(FetchDescriptor<Client>())).contains { $0.clientCode == clientCode }) else { return }
        let client = Client(
            clientCode: clientCode,
            displayName: "匿名授权测试客户",
            source: "自动界面测试",
            notes: "仅用于 M3 临时界面验证的虚构客户"
        )
        context.insert(client)
        let consent = ConsentRecord(
            clientID: client.id,
            type: .anonymousContentUse,
            textVersion: "ANON-UI-M3-1",
            textSnapshot: "仅用于已完成去身份化复核的图文共性主题。全部为虚构测试数据。",
            accepted: true,
            confirmationMethod: "自动界面测试确认",
            permissionScope: "匿名共性主题与成长练习",
            allowedChannelsText: "微信朋友圈，小红书",
            allowedFormatsText: "图文、匿名共性主题",
            expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: .now),
            withdrawalMethod: "联系服务方登记撤回"
        )
        context.insert(consent)
        let asset = BrandAsset(
            name: "测试素材：关系边界匿名主题",
            kind: .document,
            source: "虚构客户主动反馈",
            owner: "界面测试客户",
            permission: .usable,
            allowedChannelsText: "微信朋友圈，小红书",
            useScope: "匿名共性主题与成长练习",
            note: "全部为虚构界面测试数据",
            category: .customerRelated,
            clientID: client.id,
            consentID: consent.id,
            deidentifiedSummary: "有人过去习惯压下自己的需求，后来开始用事实、感受和请求练习表达边界。",
            directIdentifiersRemoved: true,
            indirectIdentifiersReviewed: true,
            secondReviewCompleted: true,
            secondReviewer: "M3 测试复核人",
            reviewedAt: .now,
            allowedFormatsText: "图文"
        )
        context.insert(asset)
        context.insert(BrandAssetAuditEvent(
            assetID: asset.id,
            consentID: consent.id,
            action: .reviewed,
            detail: "虚构素材已完成独立授权和双重去身份化复核。",
            actor: "自动界面测试"
        ))

        let withdrawnConsent = ConsentRecord(
            clientID: client.id,
            type: .anonymousContentUse,
            textVersion: "ANON-UI-M3-OLD",
            textSnapshot: "历史虚构测试授权",
            accepted: true,
            confirmedAt: Date.now.addingTimeInterval(-172_800),
            confirmationMethod: "自动界面测试确认",
            withdrawnAt: Date.now.addingTimeInterval(-86_400),
            permissionScope: "历史测试范围",
            allowedChannelsText: "微信朋友圈",
            allowedFormatsText: "图文",
            withdrawalMethod: "自动界面测试撤回"
        )
        context.insert(withdrawnConsent)
        let withdrawnAsset = BrandAsset(
            name: "测试素材：已撤回",
            kind: .document,
            source: "虚构历史反馈",
            owner: "界面测试客户",
            permission: .withdrawn,
            allowedChannelsText: "微信朋友圈",
            revokedAt: withdrawnConsent.withdrawnAt,
            useScope: "历史测试范围",
            category: .customerRelated,
            clientID: client.id,
            consentID: withdrawnConsent.id,
            deidentifiedSummary: "已撤回的虚构测试摘要",
            directIdentifiersRemoved: true,
            indirectIdentifiersReviewed: true,
            secondReviewCompleted: true,
            secondReviewer: "M3 测试复核人",
            reviewedAt: Date.now.addingTimeInterval(-172_800),
            allowedFormatsText: "图文"
        )
        context.insert(withdrawnAsset)
        context.insert(BrandAssetActionTask(
            assetID: withdrawnAsset.id,
            type: .reviewPublishedContent,
            detail: "虚构外部内容需要人工下架或修改；系统未操作平台。"
        ))
        context.insert(BrandAssetAuditEvent(
            assetID: withdrawnAsset.id,
            consentID: withdrawnConsent.id,
            action: .withdrawn,
            detail: "虚构客户已撤回授权，素材已停止再次使用。",
            actor: "自动界面测试"
        ))
        try context.save()
    }

    static func insertBrandM4UITestData(context: ModelContext) throws {
        try BrandPlatformCapabilityRegistry.registerDefaults(context: context)
        let marker = "M4 测试：标题方向对比"
        guard !(try context.fetch(FetchDescriptor<BrandExperiment>())).contains(where: { $0.title == marker }) else { return }
        guard let profile = try context.fetch(FetchDescriptor<BrandProfile>()).first else { return }

        let firstTopic = BrandContentTopic(
            profileID: profile.id,
            title: "M4 测试：温和标题",
            rawIdea: "虚构内容：用三句话记录今天的感受。",
            targetAudience: "界面验证人群",
            pillar: "成长练习",
            goal: .interaction,
            sourceType: .personalOpinion,
            sensitivity: "公开测试内容",
            customerReference: "",
            actionHint: "收藏练习",
            priority: 1,
            status: .completed
        )
        let secondTopic = BrandContentTopic(
            profileID: profile.id,
            title: "M4 测试：问题标题",
            rawIdea: "虚构内容：你会怎样描述今天的感受？",
            targetAudience: "界面验证人群",
            pillar: "成长练习",
            goal: .interaction,
            sourceType: .personalOpinion,
            sensitivity: "公开测试内容",
            customerReference: "",
            actionHint: "留言练习",
            priority: 1,
            status: .completed
        )
        context.insert(firstTopic)
        context.insert(secondTopic)
        let firstRecord = BrandPublishRecord(
            topicID: firstTopic.id,
            channel: .wechatMoments,
            publishedAt: .now.addingTimeInterval(-172_800),
            platformPostID: "UI-M4-A",
            note: "虚构 M4 对比内容",
            snapshotTitle: firstTopic.title,
            snapshotContent: firstTopic.rawIdea,
            publishedAsApproved: true,
            collectedBy: "自动界面测试"
        )
        let secondRecord = BrandPublishRecord(
            topicID: secondTopic.id,
            channel: .wechatMoments,
            publishedAt: .now.addingTimeInterval(-86_400),
            platformPostID: "UI-M4-B",
            note: "虚构 M4 对比内容",
            snapshotTitle: secondTopic.title,
            snapshotContent: secondTopic.rawIdea,
            publishedAsApproved: true,
            collectedBy: "自动界面测试"
        )
        context.insert(firstRecord)
        context.insert(secondRecord)
        context.insert(BrandMetricSnapshot(
            publishRecordID: firstRecord.id,
            periodStart: .now.addingTimeInterval(-172_800),
            periodEnd: .now,
            method: .manual,
            views: 120,
            likes: 15,
            comments: 3,
            favorites: 4,
            shares: 2,
            missingReasons: "曝光未提供",
            sourceFile: "M4 虚构人工快照",
            isConfirmed: true
        ))
        context.insert(BrandMetricSnapshot(
            publishRecordID: secondRecord.id,
            periodStart: .now.addingTimeInterval(-86_400),
            periodEnd: .now,
            method: .manual,
            views: 150,
            likes: 17,
            comments: 6,
            favorites: 5,
            shares: 1,
            missingReasons: "曝光未提供",
            sourceFile: "M4 虚构人工快照",
            isConfirmed: true
        ))
        let experiment = BrandExperiment(
            title: marker,
            dimension: .titleDirection,
            hypothesis: "问题式标题可能带来更多互动。",
            variantALabel: "温和陈述",
            variantAPublishRecordID: firstRecord.id,
            variantBLabel: "问题引导",
            variantBPublishRecordID: secondRecord.id,
            status: .running
        )
        context.insert(experiment)
        if let wechat = try context.fetch(FetchDescriptor<BrandPlatformConnection>()).first(where: { $0.platform == .wechatPersonalMoments }) {
            context.insert(BrandSyncRun(
                connectionID: wechat.id,
                status: .skipped,
                requestedAt: .now.addingTimeInterval(-3_600),
                completedAt: .now.addingTimeInterval(-3_599),
                errorCategory: "capability_unavailable",
                safeMessage: "个人朋友圈未开放已核验的官方指标同步，人工流程保持可用。"
            ))
        }
        try context.save()
    }
    #endif

    private static var defaultServices: [ServiceItem] {
        [
            ServiceItem(category: "咨询疗愈系列", name: "单项精细化心理分析", productKind: .singleConsultation, deliveryType: .video, durationMinutes: 40, pricingMode: .fixed, priceCents: 66_600, sortOrder: 1),
            ServiceItem(category: "咨询疗愈系列", name: "双项深度心理剖析", productKind: .singleConsultation, deliveryType: .video, durationMinutes: 60, pricingMode: .fixed, priceCents: 111_100, sortOrder: 2),
            ServiceItem(category: "咨询疗愈系列", name: "全年运势整合套餐", productKind: .package, deliveryType: .video, durationMinutes: 100, pricingMode: .fixed, priceCents: 166_600, sortOrder: 3),
            ServiceItem(category: "咨询疗愈系列", name: "单次疗愈整合", productKind: .singleConsultation, deliveryType: .video, durationMinutes: 70, pricingMode: .fixed, priceCents: 99_900, sortOrder: 4),
            ServiceItem(category: "周期疗愈套餐", name: "季度能量净化套餐", productKind: .package, deliveryType: .video, durationMinutes: 90, pricingMode: .fixed, priceCents: 399_900, includedSessions: 4, validDays: 120, sortOrder: 5),
            ServiceItem(category: "周期疗愈套餐", name: "全年定制陪伴成长计划", productKind: .package, deliveryType: .video, durationMinutes: 90, pricingMode: .fixed, priceCents: 1_100_000, includedSessions: 11, validDays: 365, sortOrder: 6),
            ServiceItem(category: "老客户服务", name: "极速问题解决通道", productKind: .singleConsultation, deliveryType: .nonVideo, durationMinutes: 20, pricingMode: .fixed, priceCents: 36_800, sortOrder: 7),
            ServiceItem(category: "起名/改名", name: "新生儿命名规划", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 277_700, requiresGuardian: true, sortOrder: 8),
            ServiceItem(category: "起名/改名", name: "青少年改名赋能（1-17 岁）", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 222_200, requiresGuardian: true, sortOrder: 9),
            ServiceItem(category: "起名/改名", name: "成人改名焕新", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 444_400, sortOrder: 10),
            ServiceItem(category: "起名/改名", name: "商业实体命名", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 1_111_100, sortOrder: 11),
            ServiceItem(category: "空间服务", name: "场域能量净化赋新", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 1_888_800, sortOrder: 12),
            ServiceItem(category: "空间服务", name: "3D 场域能量重构", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .startingAt, priceCents: 1_888_800, sortOrder: 13),
            ServiceItem(category: "空间服务", name: "私人定制能量场域装修设计", productKind: .project, deliveryType: .project, durationMinutes: 0, pricingMode: .perSquareMeter, priceCents: 30_000, unitLabel: "㎡", sortOrder: 14)
        ]
    }
}
