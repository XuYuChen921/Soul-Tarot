import Foundation
import SwiftData

@Model
final class MediaAsset {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var clientID: UUID
    var kindRaw: String
    var originalFilename: String
    var relativePath: String
    var fileSize: Int64
    var sha256: String?
    var importedAt: Date
    var retentionMode: String

    var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .document }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        clientID: UUID,
        kind: MediaKind,
        originalFilename: String,
        relativePath: String,
        fileSize: Int64,
        sha256: String? = nil,
        importedAt: Date = .now,
        retentionMode: String = "长期保存"
    ) {
        self.id = id
        self.sessionID = sessionID
        self.clientID = clientID
        self.kindRaw = kind.rawValue
        self.originalFilename = originalFilename
        self.relativePath = relativePath
        self.fileSize = fileSize
        self.sha256 = sha256
        self.importedAt = importedAt
        self.retentionMode = retentionMode
    }
}
