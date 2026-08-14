import Foundation
import SwiftData

@Model
final class Client {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var clientCode: String
    var displayName: String
    var wechatNickname: String
    var phone: String
    var source: String
    var birthDate: Date?
    var notes: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        clientCode: String,
        displayName: String,
        wechatNickname: String = "",
        phone: String = "",
        source: String = "熟人介绍",
        birthDate: Date? = nil,
        notes: String = "",
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.clientCode = clientCode
        self.displayName = displayName
        self.wechatNickname = wechatNickname
        self.phone = phone
        self.source = source
        self.birthDate = birthDate
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

