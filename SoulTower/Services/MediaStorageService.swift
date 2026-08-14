import Foundation
import CryptoKit

enum MediaStorageError: LocalizedError {
    case cannotAccessFile
    case unsupportedLocation

    var errorDescription: String? {
        switch self {
        case .cannotAccessFile: return "无法读取所选文件。"
        case .unsupportedLocation: return "无法创建应用资料目录。"
        }
    }
}

enum MediaStorageService {
    static func importFile(
        from sourceURL: URL,
        clientID: UUID,
        sessionID: UUID
    ) throws -> (relativePath: String, size: Int64, kind: MediaKind, sha256: String) {
        let granted = sourceURL.startAccessingSecurityScopedResource()
        defer { if granted { sourceURL.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw MediaStorageError.cannotAccessFile
        }

        let root = try mediaRoot()
        let folder = root.appendingPathComponent(clientID.uuidString, isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let safeExtension = sourceURL.pathExtension.lowercased()
        let filename = UUID().uuidString + (safeExtension.isEmpty ? "" : ".\(safeExtension)")
        let destination = folder.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        let relative = "\(clientID.uuidString)/\(sessionID.uuidString)/\(filename)"
        return (
            relative,
            Int64(values.fileSize ?? 0),
            mediaKind(for: safeExtension),
            try fileSHA256(at: destination)
        )
    }

    static func importData(
        _ data: Data,
        fileExtension: String,
        clientID: UUID,
        sessionID: UUID
    ) throws -> (relativePath: String, size: Int64, kind: MediaKind, sha256: String) {
        let safeExtension = fileExtension.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let root = try mediaRoot()
        let folder = root.appendingPathComponent(clientID.uuidString, isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = UUID().uuidString + (safeExtension.isEmpty ? "" : ".\(safeExtension)")
        let destination = folder.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        let relative = "\(clientID.uuidString)/\(sessionID.uuidString)/\(filename)"
        return (relative, Int64(data.count), mediaKind(for: safeExtension), sha256(data))
    }

    static func absoluteURL(for relativePath: String) throws -> URL {
        try mediaRoot().appendingPathComponent(relativePath)
    }

    static func text(for relativePath: String) throws -> String {
        try String(contentsOf: absoluteURL(for: relativePath), encoding: .utf8)
    }

    static func mediaRoot() throws -> URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MediaStorageError.unsupportedLocation
        }
        let root = support.appendingPathComponent("SoulTower/Media", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func removeFile(relativePath: String) throws {
        let url = try absoluteURL(for: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func verify(asset: MediaAsset) throws -> Bool {
        guard let expected = asset.sha256, !expected.isEmpty else { return false }
        return try fileSHA256(at: absoluteURL(for: asset.relativePath)) == expected
    }

    static func replaceMediaRoot(with stagedRoot: URL) throws {
        let manager = FileManager.default
        let current = try mediaRoot()
        let parent = current.deletingLastPathComponent()
        let rollback = parent.appendingPathComponent("Media-before-restore-\(UUID().uuidString)", isDirectory: true)

        if manager.fileExists(atPath: current.path) {
            try manager.moveItem(at: current, to: rollback)
        }
        do {
            try manager.moveItem(at: stagedRoot, to: current)
            if manager.fileExists(atPath: rollback.path) {
                try manager.removeItem(at: rollback)
            }
        } catch {
            if manager.fileExists(atPath: current.path) {
                try? manager.removeItem(at: current)
            }
            if manager.fileExists(atPath: rollback.path) {
                try? manager.moveItem(at: rollback, to: current)
            }
            throw error
        }
    }

    static func mediaKind(for fileExtension: String) -> MediaKind {
        if ["m4a", "mp3", "wav", "aac", "caf"].contains(fileExtension) { return .audio }
        if ["jpg", "jpeg", "png", "heic", "webp"].contains(fileExtension) { return .image }
        if ["txt", "md", "srt", "vtt"].contains(fileExtension) { return .transcript }
        return .document
    }

    private static func fileSHA256(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }
}
