import Foundation
import CryptoKit

enum BrandAssetStorageError: LocalizedError {
    case cannotAccessFile
    case unsupportedLocation

    var errorDescription: String? {
        switch self {
        case .cannotAccessFile: return "无法读取所选品牌素材文件。"
        case .unsupportedLocation: return "无法创建品牌素材目录。"
        }
    }
}

enum BrandAssetStorageService {
    static func importFile(from sourceURL: URL, assetID: UUID) throws -> (relativePath: String, size: Int64, sha256: String) {
        let granted = sourceURL.startAccessingSecurityScopedResource()
        defer { if granted { sourceURL.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw BrandAssetStorageError.cannotAccessFile
        }
        let root = try brandAssetRoot()
        let extensionPart = sourceURL.pathExtension.lowercased()
        let filename = assetID.uuidString + (extensionPart.isEmpty ? "" : ".\(extensionPart)")
        let destination = root.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        return (filename, Int64(values.fileSize ?? 0), try fileSHA256(at: destination))
    }

    static func absoluteURL(for relativePath: String) throws -> URL {
        try brandAssetRoot().appendingPathComponent(relativePath)
    }

    static func brandAssetRoot() throws -> URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BrandAssetStorageError.unsupportedLocation
        }
        let root = support.appendingPathComponent("SoulTower/BrandAssets", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func verify(asset: BrandAsset) throws -> Bool {
        guard let path = asset.relativePath, !path.isEmpty,
              let expected = asset.sha256, !expected.isEmpty else { return false }
        return try fileSHA256(at: absoluteURL(for: path)) == expected
    }

    static func removeFile(relativePath: String) throws {
        let url = try absoluteURL(for: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func replaceBrandAssetRoot(with stagedRoot: URL) throws {
        let manager = FileManager.default
        let current = try brandAssetRoot()
        let parent = current.deletingLastPathComponent()
        let rollback = parent.appendingPathComponent("BrandAssets-before-restore-\(UUID().uuidString)", isDirectory: true)
        if manager.fileExists(atPath: current.path) { try manager.moveItem(at: current, to: rollback) }
        do {
            try manager.moveItem(at: stagedRoot, to: current)
            if manager.fileExists(atPath: rollback.path) { try manager.removeItem(at: rollback) }
        } catch {
            if manager.fileExists(atPath: current.path) { try? manager.removeItem(at: current) }
            if manager.fileExists(atPath: rollback.path) { try? manager.moveItem(at: rollback, to: current) }
            throw error
        }
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
}
