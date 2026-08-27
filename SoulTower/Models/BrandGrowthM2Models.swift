import Foundation
import SwiftData

enum BrandAttributionEvidence: String, CaseIterable, Codable, Identifiable {
    case confirmedContent = "已确认具体内容"
    case platformOnly = "只确认平台"
    case unattributed = "无法确认"

    var id: String { rawValue }
}

@Model
final class BrandMarketingTouchpoint {
    @Attribute(.unique) var id: UUID
    var clientID: UUID
    var clientCodeSnapshot: String
    var clientNameSnapshot: String
    var channelRaw: String?
    var publishRecordID: UUID?
    var keyword: String
    var firstContactAt: Date
    var evidenceRaw: String
    var confirmationMethod: String
    var note: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    var channel: BrandDistributionChannel? {
        get { channelRaw.flatMap(BrandDistributionChannel.init(rawValue:)) }
        set { channelRaw = newValue?.rawValue }
    }

    var evidence: BrandAttributionEvidence {
        get { BrandAttributionEvidence(rawValue: evidenceRaw) ?? .unattributed }
        set { evidenceRaw = newValue.rawValue }
    }

    var hasContentEvidence: Bool {
        isActive && evidence == .confirmedContent && publishRecordID != nil
    }

    init(
        id: UUID = UUID(),
        clientID: UUID,
        clientCodeSnapshot: String,
        clientNameSnapshot: String,
        channel: BrandDistributionChannel? = nil,
        publishRecordID: UUID? = nil,
        keyword: String = "",
        firstContactAt: Date = .now,
        evidence: BrandAttributionEvidence,
        confirmationMethod: String,
        note: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clientID = clientID
        self.clientCodeSnapshot = clientCodeSnapshot
        self.clientNameSnapshot = clientNameSnapshot
        self.channelRaw = channel?.rawValue
        self.publishRecordID = publishRecordID
        self.keyword = keyword
        self.firstContactAt = firstContactAt
        self.evidenceRaw = evidence.rawValue
        self.confirmationMethod = confirmationMethod
        self.note = note
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
