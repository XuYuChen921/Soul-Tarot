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
