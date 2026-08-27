import Foundation
import SwiftData

@Model
final class ConsentRecord {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var appointmentID: UUID?
    var serviceOrderID: UUID?
    var typeRaw: String
    var textVersion: String
    var textSnapshot: String = ""
    var accepted: Bool
    var confirmedAt: Date
    var confirmationMethod: String
    var withdrawnAt: Date?
    var permissionScope: String? = nil
    var allowedChannelsText: String? = nil
    var allowedFormatsText: String? = nil
    var expiresAt: Date? = nil
    var withdrawalMethod: String? = nil

    var type: ConsentType {
        get { ConsentType(rawValue: typeRaw) ?? .servicePolicy }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        clientID: UUID,
        appointmentID: UUID? = nil,
        serviceOrderID: UUID? = nil,
        type: ConsentType,
        textVersion: String,
        textSnapshot: String,
        accepted: Bool,
        confirmedAt: Date = .now,
        confirmationMethod: String = "微信文字确认",
        withdrawnAt: Date? = nil,
        permissionScope: String? = nil,
        allowedChannelsText: String? = nil,
        allowedFormatsText: String? = nil,
        expiresAt: Date? = nil,
        withdrawalMethod: String? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.appointmentID = appointmentID
        self.serviceOrderID = serviceOrderID
        self.typeRaw = type.rawValue
        self.textVersion = textVersion
        self.textSnapshot = textSnapshot
        self.accepted = accepted
        self.confirmedAt = confirmedAt
        self.confirmationMethod = confirmationMethod
        self.withdrawnAt = withdrawnAt
        self.permissionScope = permissionScope
        self.allowedChannelsText = allowedChannelsText
        self.allowedFormatsText = allowedFormatsText
        self.expiresAt = expiresAt
        self.withdrawalMethod = withdrawalMethod
    }

    var isActiveAnonymousContentConsent: Bool {
        type == .anonymousContentUse
            && accepted
            && withdrawnAt == nil
            && (expiresAt == nil || expiresAt! >= .now)
    }

    var allowedBrandChannels: [BrandDistributionChannel] {
        (allowedChannelsText ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(BrandDistributionChannel.init(rawValue:))
    }
}
