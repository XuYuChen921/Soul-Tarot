import Foundation

struct BackupSnapshot: Codable, Sendable {
    static let formatVersion = 3

    var formatVersion: Int
    var createdAt: Date
    var appVersion: String
    var clients: [BackupClient]
    var services: [BackupServiceItem]
    var appointments: [BackupAppointment]
    var consents: [BackupConsent]
    var records: [BackupConsultation]
    var mediaAssets: [BackupMediaAsset]
    var payments: [BackupPaymentTransaction]? = nil
    var serviceOrders: [BackupServiceOrder]? = nil
    var orderPayments: [BackupOrderPaymentTransaction]? = nil
    var entitlementRedemptions: [BackupEntitlementRedemption]? = nil
    var serviceOrderChanges: [BackupServiceOrderChange]? = nil
    var consultationActivities: [BackupConsultationActivity]? = nil
    var consultationSummaryRevisions: [BackupConsultationSummaryRevision]? = nil
    var mediaFiles: [BackupMediaFile]
    var brandProfiles: [BackupBrandProfile]? = nil
    var brandTopics: [BackupBrandTopic]? = nil
    var brandDrafts: [BackupBrandDraft]? = nil
    var brandDraftRevisions: [BackupBrandDraftRevision]? = nil
    var brandPublishRecords: [BackupBrandPublishRecord]? = nil
    var brandAssets: [BackupBrandAsset]? = nil
    var brandMetricSnapshots: [BackupBrandMetricSnapshot]? = nil
    var brandWeeklyReviews: [BackupBrandWeeklyReview]? = nil
    var brandMarketingTouchpoints: [BackupBrandMarketingTouchpoint]? = nil
    var brandAssetAudits: [BackupBrandAssetAudit]? = nil
    var brandAssetUsages: [BackupBrandAssetUsage]? = nil
    var brandAssetTasks: [BackupBrandAssetTask]? = nil
    var brandFiles: [BackupBrandFile]? = nil
}

struct BackupClient: Codable, Sendable {
    var id: UUID
    var clientCode: String
    var displayName: String
    var wechatNickname: String
    var phone: String
    var source: String
    var birthDate: Date?
    var notes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(_ value: Client) {
        id = value.id; clientCode = value.clientCode; displayName = value.displayName
        wechatNickname = value.wechatNickname; phone = value.phone; source = value.source
        birthDate = value.birthDate; notes = value.notes; isArchived = value.isArchived
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> Client {
        Client(id: id, clientCode: clientCode, displayName: displayName, wechatNickname: wechatNickname, phone: phone, source: source, birthDate: birthDate, notes: notes, isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupServiceItem: Codable, Sendable {
    var id: UUID
    var category: String
    var name: String
    var productKindRaw: String? = nil
    var deliveryTypeRaw: String
    var durationMinutes: Int
    var pricingModeRaw: String
    var priceCents: Int
    var unitLabel: String
    var includedSessions: Int
    var validDays: Int
    var requiresGuardian: Bool
    var isActive: Bool
    var sortOrder: Int
    var ruleVersion: String

    init(_ value: ServiceItem) {
        id = value.id; category = value.category; name = value.name
        productKindRaw = value.productKindRaw
        deliveryTypeRaw = value.deliveryTypeRaw; durationMinutes = value.durationMinutes
        pricingModeRaw = value.pricingModeRaw; priceCents = value.priceCents
        unitLabel = value.unitLabel; includedSessions = value.includedSessions; validDays = value.validDays
        requiresGuardian = value.requiresGuardian; isActive = value.isActive
        sortOrder = value.sortOrder; ruleVersion = value.ruleVersion
    }

    func model() -> ServiceItem {
        ServiceItem(id: id, category: category, name: name, productKind: productKindRaw.flatMap(ProductKind.init(rawValue:)), deliveryType: DeliveryType(rawValue: deliveryTypeRaw) ?? .video, durationMinutes: durationMinutes, pricingMode: PricingMode(rawValue: pricingModeRaw) ?? .fixed, priceCents: priceCents, unitLabel: unitLabel, includedSessions: includedSessions, validDays: validDays, requiresGuardian: requiresGuardian, isActive: isActive, sortOrder: sortOrder, ruleVersion: ruleVersion)
    }
}

struct BackupAppointment: Codable, Sendable {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var clientNameSnapshot: String
    var serviceID: UUID
    var serviceOrderID: UUID?
    var serviceNameSnapshot: String
    var startAt: Date
    var endAt: Date
    var statusRaw: String
    var paymentStatusRaw: String
    var videoDeviceRaw: String
    var priceCents: Int
    var policyVersion: String
    var reminder24Identifier: String
    var reminder1Identifier: String
    var guardianName: String
    var notes: String
    var changeCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(_ value: Appointment) {
        id = value.id; clientID = value.clientID; clientCode = value.clientCode
        clientNameSnapshot = value.clientNameSnapshot; serviceID = value.serviceID
        serviceOrderID = value.serviceOrderID; serviceNameSnapshot = value.serviceNameSnapshot; startAt = value.startAt; endAt = value.endAt
        statusRaw = value.statusRaw; paymentStatusRaw = value.paymentStatusRaw; videoDeviceRaw = value.videoDeviceRaw
        priceCents = value.priceCents; policyVersion = value.policyVersion
        reminder24Identifier = value.reminder24Identifier; reminder1Identifier = value.reminder1Identifier
        guardianName = value.guardianName; notes = value.notes; changeCount = value.changeCount
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> Appointment {
        let item = Appointment(id: id, clientID: clientID, clientCode: clientCode, clientNameSnapshot: clientNameSnapshot, serviceID: serviceID, serviceOrderID: serviceOrderID, serviceNameSnapshot: serviceNameSnapshot, startAt: startAt, endAt: endAt, status: AppointmentStatus(rawValue: statusRaw) ?? .pendingRules, paymentStatus: PaymentStatus(rawValue: paymentStatusRaw) ?? .unpaid, videoDevice: VideoDevice(rawValue: videoDeviceRaw) ?? .undecided, priceCents: priceCents, policyVersion: policyVersion, guardianName: guardianName, notes: notes, changeCount: changeCount, createdAt: createdAt, updatedAt: updatedAt)
        item.reminder24Identifier = reminder24Identifier
        item.reminder1Identifier = reminder1Identifier
        return item
    }
}

struct BackupConsent: Codable, Sendable {
    var id: UUID
    var clientID: UUID
    var appointmentID: UUID?
    var serviceOrderID: UUID?
    var typeRaw: String
    var textVersion: String
    var textSnapshot: String
    var accepted: Bool
    var confirmedAt: Date
    var confirmationMethod: String
    var withdrawnAt: Date?
    var permissionScope: String? = nil
    var allowedChannelsText: String? = nil
    var allowedFormatsText: String? = nil
    var expiresAt: Date? = nil
    var withdrawalMethod: String? = nil

    init(_ value: ConsentRecord) {
        id = value.id; clientID = value.clientID; appointmentID = value.appointmentID; serviceOrderID = value.serviceOrderID
        typeRaw = value.typeRaw; textVersion = value.textVersion; textSnapshot = value.textSnapshot
        accepted = value.accepted; confirmedAt = value.confirmedAt
        confirmationMethod = value.confirmationMethod; withdrawnAt = value.withdrawnAt
        permissionScope = value.permissionScope; allowedChannelsText = value.allowedChannelsText
        allowedFormatsText = value.allowedFormatsText; expiresAt = value.expiresAt
        withdrawalMethod = value.withdrawalMethod
    }

    func model() -> ConsentRecord {
        ConsentRecord(id: id, clientID: clientID, appointmentID: appointmentID, serviceOrderID: serviceOrderID, type: ConsentType(rawValue: typeRaw) ?? .servicePolicy, textVersion: textVersion, textSnapshot: textSnapshot, accepted: accepted, confirmedAt: confirmedAt, confirmationMethod: confirmationMethod, withdrawnAt: withdrawnAt, permissionScope: permissionScope, allowedChannelsText: allowedChannelsText, allowedFormatsText: allowedFormatsText, expiresAt: expiresAt, withdrawalMethod: withdrawalMethod)
    }
}

struct BackupConsultation: Codable, Sendable {
    var id: UUID
    var appointmentID: UUID?
    var clientID: UUID
    var clientCode: String
    var clientNameSnapshot: String
    var serviceName: String
    var occurredAt: Date
    var transcriptText: String
    var summaryDraft: String
    var formalSummary: String
    var aiStatusRaw: String
    var aiModelName: String
    var approvedAt: Date?
    var transcriptSourceRaw: String? = nil
    var transcriptUpdatedAt: Date? = nil
    var formalSummaryVersion: Int? = nil
    var recordingDeliveredAt: Date? = nil
    var archivedAt: Date? = nil
    var createdAt: Date
    var updatedAt: Date

    init(_ value: ConsultationRecord) {
        id = value.id; appointmentID = value.appointmentID; clientID = value.clientID
        clientCode = value.clientCode; clientNameSnapshot = value.clientNameSnapshot
        serviceName = value.serviceName; occurredAt = value.occurredAt
        transcriptText = value.transcriptText; summaryDraft = value.summaryDraft; formalSummary = value.formalSummary
        aiStatusRaw = value.aiStatusRaw; aiModelName = value.aiModelName; approvedAt = value.approvedAt
        transcriptSourceRaw = value.transcriptSourceRaw; transcriptUpdatedAt = value.transcriptUpdatedAt
        formalSummaryVersion = value.formalSummaryVersion; recordingDeliveredAt = value.recordingDeliveredAt
        archivedAt = value.archivedAt
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> ConsultationRecord {
        ConsultationRecord(
            id: id, appointmentID: appointmentID, clientID: clientID,
            clientCode: clientCode, clientNameSnapshot: clientNameSnapshot,
            serviceName: serviceName, occurredAt: occurredAt,
            transcriptText: transcriptText, summaryDraft: summaryDraft,
            formalSummary: formalSummary,
            aiStatus: AIRecordStatus(rawValue: aiStatusRaw) ?? .noTranscript,
            aiModelName: aiModelName, approvedAt: approvedAt,
            transcriptSource: TranscriptSource(rawValue: transcriptSourceRaw ?? "") ?? .manual,
            transcriptUpdatedAt: transcriptUpdatedAt,
            formalSummaryVersion: formalSummaryVersion ?? (formalSummary.isEmpty ? 0 : 1),
            recordingDeliveredAt: recordingDeliveredAt,
            archivedAt: archivedAt,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

struct BackupMediaAsset: Codable, Sendable {
    var id: UUID
    var sessionID: UUID
    var clientID: UUID
    var kindRaw: String
    var originalFilename: String
    var relativePath: String
    var fileSize: Int64
    var sha256: String? = nil
    var importedAt: Date
    var retentionMode: String

    init(_ value: MediaAsset) {
        id = value.id; sessionID = value.sessionID; clientID = value.clientID
        kindRaw = value.kindRaw; originalFilename = value.originalFilename
        relativePath = value.relativePath; fileSize = value.fileSize
        sha256 = value.sha256
        importedAt = value.importedAt; retentionMode = value.retentionMode
    }

    func model() -> MediaAsset {
        MediaAsset(id: id, sessionID: sessionID, clientID: clientID, kind: MediaKind(rawValue: kindRaw) ?? .document, originalFilename: originalFilename, relativePath: relativePath, fileSize: fileSize, sha256: sha256, importedAt: importedAt, retentionMode: retentionMode)
    }
}

struct BackupConsultationActivity: Codable, Sendable {
    var id: UUID
    var recordID: UUID
    var clientID: UUID
    var kindRaw: String
    var title: String
    var detail: String
    var occurredAt: Date
    var createdAt: Date

    init(_ value: ConsultationActivity) {
        id = value.id; recordID = value.recordID; clientID = value.clientID
        kindRaw = value.kindRaw; title = value.title; detail = value.detail
        occurredAt = value.occurredAt; createdAt = value.createdAt
    }

    func model() -> ConsultationActivity {
        ConsultationActivity(
            id: id, recordID: recordID, clientID: clientID,
            kind: ConsultationActivityKind(rawValue: kindRaw) ?? .recordCreated,
            title: title, detail: detail, occurredAt: occurredAt, createdAt: createdAt
        )
    }
}

struct BackupConsultationSummaryRevision: Codable, Sendable {
    var id: UUID
    var recordID: UUID
    var clientID: UUID
    var version: Int
    var content: String
    var aiModelName: String
    var approvedAt: Date
    var createdAt: Date

    init(_ value: ConsultationSummaryRevision) {
        id = value.id; recordID = value.recordID; clientID = value.clientID
        version = value.version; content = value.content; aiModelName = value.aiModelName
        approvedAt = value.approvedAt; createdAt = value.createdAt
    }

    func model() -> ConsultationSummaryRevision {
        ConsultationSummaryRevision(
            id: id, recordID: recordID, clientID: clientID,
            version: version, content: content, aiModelName: aiModelName,
            approvedAt: approvedAt, createdAt: createdAt
        )
    }
}

struct BackupPaymentTransaction: Codable, Sendable {
    var id: UUID
    var appointmentID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var kindRaw: String
    var methodRaw: String
    var amountCents: Int
    var occurredAt: Date
    var note: String
    var createdAt: Date

    init(_ value: PaymentTransaction) {
        id = value.id; appointmentID = value.appointmentID; clientID = value.clientID
        clientCode = value.clientCode; serviceNameSnapshot = value.serviceNameSnapshot
        kindRaw = value.kindRaw; methodRaw = value.methodRaw; amountCents = value.amountCents
        occurredAt = value.occurredAt; note = value.note; createdAt = value.createdAt
    }

    func model() -> PaymentTransaction {
        PaymentTransaction(
            id: id,
            appointmentID: appointmentID,
            clientID: clientID,
            clientCode: clientCode,
            serviceNameSnapshot: serviceNameSnapshot,
            kind: PaymentTransactionKind(rawValue: kindRaw) ?? .servicePayment,
            method: PaymentMethod(rawValue: methodRaw) ?? .other,
            amountCents: amountCents,
            occurredAt: occurredAt,
            note: note,
            createdAt: createdAt
        )
    }
}

struct BackupServiceOrder: Codable, Sendable {
    var id: UUID
    var clientID: UUID
    var clientCode: String
    var clientNameSnapshot: String
    var serviceID: UUID
    var serviceNameSnapshot: String
    var categorySnapshot: String
    var productKindRaw: String? = nil
    var projectStageRaw: String? = nil
    var deliveryTypeRaw: String
    var pricingModeRaw: String
    var unitLabel: String
    var unitQuantityHundredths: Int
    var totalPriceCents: Int
    var includedSessions: Int
    var validDaysSnapshot: Int? = nil
    var statusRaw: String
    var paymentStatusRaw: String
    var policyVersion: String
    var placedAt: Date
    var validFrom: Date
    var expiresAt: Date?
    var activatedAt: Date? = nil
    var guardianName: String
    var subjectName: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(_ value: ServiceOrder) {
        id = value.id; clientID = value.clientID; clientCode = value.clientCode
        clientNameSnapshot = value.clientNameSnapshot; serviceID = value.serviceID
        serviceNameSnapshot = value.serviceNameSnapshot; categorySnapshot = value.categorySnapshot
        productKindRaw = value.productKindRaw
        projectStageRaw = value.projectStageRaw
        deliveryTypeRaw = value.deliveryTypeRaw; pricingModeRaw = value.pricingModeRaw
        unitLabel = value.unitLabel; unitQuantityHundredths = value.unitQuantityHundredths
        totalPriceCents = value.totalPriceCents; includedSessions = value.includedSessions
        validDaysSnapshot = value.validDaysSnapshot
        statusRaw = value.statusRaw; paymentStatusRaw = value.paymentStatusRaw
        policyVersion = value.policyVersion; placedAt = value.placedAt; validFrom = value.validFrom
        expiresAt = value.expiresAt; guardianName = value.guardianName; subjectName = value.subjectName
        activatedAt = value.activatedAt
        notes = value.notes; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> ServiceOrder {
        ServiceOrder(
            id: id, clientID: clientID, clientCode: clientCode, clientNameSnapshot: clientNameSnapshot,
            serviceID: serviceID, serviceNameSnapshot: serviceNameSnapshot, categorySnapshot: categorySnapshot,
            productKind: productKindRaw.flatMap(ProductKind.init(rawValue:)),
            projectStage: projectStageRaw.flatMap(ProjectStage.init(rawValue:)),
            deliveryType: DeliveryType(rawValue: deliveryTypeRaw) ?? .project,
            pricingMode: PricingMode(rawValue: pricingModeRaw) ?? .fixed,
            unitLabel: unitLabel, unitQuantityHundredths: unitQuantityHundredths,
            totalPriceCents: totalPriceCents, includedSessions: includedSessions, validDaysSnapshot: validDaysSnapshot,
            status: ServiceOrderStatus(rawValue: statusRaw) ?? .pendingPayment,
            paymentStatus: PaymentStatus(rawValue: paymentStatusRaw) ?? .unpaid,
            policyVersion: policyVersion, placedAt: placedAt, validFrom: validFrom, expiresAt: expiresAt, activatedAt: activatedAt,
            guardianName: guardianName, subjectName: subjectName, notes: notes,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

struct BackupOrderPaymentTransaction: Codable, Sendable {
    var id: UUID
    var orderID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var kindRaw: String
    var methodRaw: String
    var amountCents: Int
    var occurredAt: Date
    var note: String
    var createdAt: Date

    init(_ value: OrderPaymentTransaction) {
        id = value.id; orderID = value.orderID; clientID = value.clientID; clientCode = value.clientCode
        serviceNameSnapshot = value.serviceNameSnapshot; kindRaw = value.kindRaw; methodRaw = value.methodRaw
        amountCents = value.amountCents; occurredAt = value.occurredAt; note = value.note; createdAt = value.createdAt
    }

    func model() -> OrderPaymentTransaction {
        OrderPaymentTransaction(
            id: id, orderID: orderID, clientID: clientID, clientCode: clientCode,
            serviceNameSnapshot: serviceNameSnapshot,
            kind: PaymentTransactionKind(rawValue: kindRaw) ?? .servicePayment,
            method: PaymentMethod(rawValue: methodRaw) ?? .other,
            amountCents: amountCents, occurredAt: occurredAt, note: note, createdAt: createdAt
        )
    }
}

struct BackupEntitlementRedemption: Codable, Sendable {
    var id: UUID
    var orderID: UUID
    var appointmentID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var stateRaw: String? = nil
    var redeemedAt: Date
    var note: String
    var reversedAt: Date?
    var reversalReason: String?
    var createdAt: Date

    init(_ value: EntitlementRedemption) {
        id = value.id; orderID = value.orderID; appointmentID = value.appointmentID
        clientID = value.clientID; clientCode = value.clientCode; serviceNameSnapshot = value.serviceNameSnapshot
        stateRaw = value.stateRaw
        redeemedAt = value.redeemedAt; note = value.note; reversedAt = value.reversedAt
        reversalReason = value.reversalReason; createdAt = value.createdAt
    }

    func model() -> EntitlementRedemption {
        EntitlementRedemption(
            id: id, orderID: orderID, appointmentID: appointmentID, clientID: clientID,
            clientCode: clientCode, serviceNameSnapshot: serviceNameSnapshot,
            state: stateRaw.flatMap(EntitlementRedemptionState.init(rawValue:)) ?? .reserved,
            redeemedAt: redeemedAt, note: note, reversedAt: reversedAt,
            reversalReason: reversalReason, createdAt: createdAt
        )
    }
}

struct BackupServiceOrderChange: Codable, Sendable {
    var id: UUID
    var orderID: UUID
    var clientID: UUID
    var clientCode: String
    var serviceNameSnapshot: String
    var kindRaw: String
    var title: String
    var beforeValue: String
    var afterValue: String
    var reason: String
    var occurredAt: Date
    var createdAt: Date

    init(_ value: ServiceOrderChange) {
        id = value.id; orderID = value.orderID; clientID = value.clientID
        clientCode = value.clientCode; serviceNameSnapshot = value.serviceNameSnapshot
        kindRaw = value.kindRaw; title = value.title; beforeValue = value.beforeValue
        afterValue = value.afterValue; reason = value.reason
        occurredAt = value.occurredAt; createdAt = value.createdAt
    }

    func model() -> ServiceOrderChange {
        ServiceOrderChange(
            id: id, orderID: orderID, clientID: clientID, clientCode: clientCode,
            serviceNameSnapshot: serviceNameSnapshot,
            kind: ServiceOrderChangeKind(rawValue: kindRaw) ?? .other,
            title: title, beforeValue: beforeValue, afterValue: afterValue,
            reason: reason, occurredAt: occurredAt, createdAt: createdAt
        )
    }
}

struct BackupMediaFile: Codable, Sendable {
    var assetID: UUID
    var relativePath: String
    var byteCount: Int64
    var chunkCount: Int
    var sha256: String
}

struct BackupPublicInfo: Codable, Sendable {
    var formatVersion: Int
    var createdAt: Date
    var salt: Data
    var iterations: Int
    var chunkSize: Int
    var snapshotFilename: String
}

struct PreparedRestore: Sendable {
    var snapshot: BackupSnapshot
    var stagedMediaRoot: URL
    var stagedBrandAssetRoot: URL? = nil
}
