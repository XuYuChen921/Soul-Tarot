import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ScheduleSyncPackage: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let appointments: [Entry]

    struct Entry: Codable, Identifiable {
        let id: UUID
        let clientCode: String
        let startAt: Date
        let endAt: Date
        let statusRaw: String
        let paymentStatusRaw: String
        let videoDeviceRaw: String
        let policyVersion: String
        let changeCount: Int
    }

    init(appointments: [Appointment]) {
        schemaVersion = 1
        exportedAt = .now
        self.appointments = appointments.map {
            Entry(
                id: $0.id,
                clientCode: $0.clientCode,
                startAt: $0.startAt,
                endAt: $0.endAt,
                statusRaw: $0.statusRaw,
                paymentStatusRaw: $0.paymentStatusRaw,
                videoDeviceRaw: $0.videoDeviceRaw,
                policyVersion: $0.policyVersion,
                changeCount: $0.changeCount
            )
        }
    }
}

struct ScheduleSyncDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let package: ScheduleSyncPackage

    init(package: ScheduleSyncPackage) {
        self.package = package
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        package = try Self.decoder.decode(ScheduleSyncPackage.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Self.encoder.encode(package))
    }

    static func decode(data: Data) throws -> ScheduleSyncPackage {
        try decoder.decode(ScheduleSyncPackage.self, from: data)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

