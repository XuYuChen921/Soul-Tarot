import Foundation
import SwiftData

@Model
final class ServiceItem {
    @Attribute(.unique) var id: UUID
    var category: String
    var name: String
    var productKindRaw: String?
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

    var deliveryType: DeliveryType {
        get { DeliveryType(rawValue: deliveryTypeRaw) ?? .video }
        set { deliveryTypeRaw = newValue.rawValue }
    }

    var pricingMode: PricingMode {
        get { PricingMode(rawValue: pricingModeRaw) ?? .fixed }
        set { pricingModeRaw = newValue.rawValue }
    }

    var productKind: ProductKind {
        get {
            if let productKindRaw, let value = ProductKind(rawValue: productKindRaw) { return value }
            if deliveryType == .project { return .project }
            if includedSessions > 1 || name.contains("套餐") || name.contains("计划") { return .package }
            return .singleConsultation
        }
        set { productKindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        category: String,
        name: String,
        productKind: ProductKind? = nil,
        deliveryType: DeliveryType,
        durationMinutes: Int,
        pricingMode: PricingMode,
        priceCents: Int,
        unitLabel: String = "",
        includedSessions: Int = 1,
        validDays: Int = 0,
        requiresGuardian: Bool = false,
        isActive: Bool = true,
        sortOrder: Int,
        ruleVersion: String = "RULE-2026-08-12"
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.productKindRaw = productKind?.rawValue
        self.deliveryTypeRaw = deliveryType.rawValue
        self.durationMinutes = durationMinutes
        self.pricingModeRaw = pricingMode.rawValue
        self.priceCents = priceCents
        self.unitLabel = unitLabel
        self.includedSessions = includedSessions
        self.validDays = validDays
        self.requiresGuardian = requiresGuardian
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.ruleVersion = ruleVersion
    }
}
