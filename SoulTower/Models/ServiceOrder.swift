import Foundation
import SwiftData

@Model
final class ServiceOrder {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var clientCode: String
    var clientNameSnapshot: String
    var serviceID: UUID
    var serviceNameSnapshot: String
    var categorySnapshot: String
    var productKindRaw: String?
    var projectStageRaw: String?
    var deliveryTypeRaw: String
    var pricingModeRaw: String
    var unitLabel: String
    var unitQuantityHundredths: Int
    var totalPriceCents: Int
    var includedSessions: Int
    var validDaysSnapshot: Int?
    var statusRaw: String
    var paymentStatusRaw: String
    var policyVersion: String
    var placedAt: Date
    var validFrom: Date
    var expiresAt: Date?
    var activatedAt: Date?
    var guardianName: String
    var subjectName: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    var status: ServiceOrderStatus {
        get { ServiceOrderStatus(rawValue: statusRaw) ?? .pendingPayment }
        set { statusRaw = newValue.rawValue }
    }

    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: paymentStatusRaw) ?? .unpaid }
        set { paymentStatusRaw = newValue.rawValue }
    }

    var deliveryType: DeliveryType {
        DeliveryType(rawValue: deliveryTypeRaw) ?? .project
    }

    var pricingMode: PricingMode {
        PricingMode(rawValue: pricingModeRaw) ?? .fixed
    }

    var productKind: ProductKind {
        if let productKindRaw, let value = ProductKind(rawValue: productKindRaw) { return value }
        if deliveryType == .project { return .project }
        return includedSessions > 1 ? .package : .singleConsultation
    }

    var projectStage: ProjectStage {
        get {
            if let projectStageRaw, let value = ProjectStage(rawValue: projectStageRaw) { return value }
            if status == .completed { return .archived }
            if status == .active { return .inProgress }
            return .awaitingDeposit
        }
        set { projectStageRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        clientID: UUID,
        clientCode: String,
        clientNameSnapshot: String,
        serviceID: UUID,
        serviceNameSnapshot: String,
        categorySnapshot: String,
        productKind: ProductKind? = nil,
        projectStage: ProjectStage? = nil,
        deliveryType: DeliveryType,
        pricingMode: PricingMode,
        unitLabel: String = "",
        unitQuantityHundredths: Int = 100,
        totalPriceCents: Int,
        includedSessions: Int = 1,
        validDaysSnapshot: Int? = nil,
        status: ServiceOrderStatus = .pendingPayment,
        paymentStatus: PaymentStatus = .unpaid,
        policyVersion: String,
        placedAt: Date = .now,
        validFrom: Date = .now,
        expiresAt: Date? = nil,
        activatedAt: Date? = nil,
        guardianName: String = "",
        subjectName: String = "",
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clientID = clientID
        self.clientCode = clientCode
        self.clientNameSnapshot = clientNameSnapshot
        self.serviceID = serviceID
        self.serviceNameSnapshot = serviceNameSnapshot
        self.categorySnapshot = categorySnapshot
        self.productKindRaw = productKind?.rawValue
        self.projectStageRaw = projectStage?.rawValue
        self.deliveryTypeRaw = deliveryType.rawValue
        self.pricingModeRaw = pricingMode.rawValue
        self.unitLabel = unitLabel
        self.unitQuantityHundredths = unitQuantityHundredths
        self.totalPriceCents = totalPriceCents
        self.includedSessions = includedSessions
        self.validDaysSnapshot = validDaysSnapshot
        self.statusRaw = status.rawValue
        self.paymentStatusRaw = paymentStatus.rawValue
        self.policyVersion = policyVersion
        self.placedAt = placedAt
        self.validFrom = validFrom
        self.expiresAt = expiresAt
        self.activatedAt = activatedAt
        self.guardianName = guardianName
        self.subjectName = subjectName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
