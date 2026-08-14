import Foundation
import SwiftData

@Model
final class ConsultationRecord {
    @Attribute(.unique) var id: UUID
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
    var transcriptSourceRaw: String
    var transcriptUpdatedAt: Date?
    var formalSummaryVersion: Int
    var recordingDeliveredAt: Date?
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var aiStatus: AIRecordStatus {
        get { AIRecordStatus(rawValue: aiStatusRaw) ?? .noTranscript }
        set { aiStatusRaw = newValue.rawValue }
    }

    var transcriptSource: TranscriptSource {
        get { TranscriptSource(rawValue: transcriptSourceRaw) ?? .manual }
        set { transcriptSourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        appointmentID: UUID? = nil,
        clientID: UUID,
        clientCode: String,
        clientNameSnapshot: String,
        serviceName: String,
        occurredAt: Date = .now,
        transcriptText: String = "",
        summaryDraft: String = "",
        formalSummary: String = "",
        aiStatus: AIRecordStatus = .noTranscript,
        aiModelName: String = "",
        approvedAt: Date? = nil,
        transcriptSource: TranscriptSource = .manual,
        transcriptUpdatedAt: Date? = nil,
        formalSummaryVersion: Int = 0,
        recordingDeliveredAt: Date? = nil,
        archivedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.appointmentID = appointmentID
        self.clientID = clientID
        self.clientCode = clientCode
        self.clientNameSnapshot = clientNameSnapshot
        self.serviceName = serviceName
        self.occurredAt = occurredAt
        self.transcriptText = transcriptText
        self.summaryDraft = summaryDraft
        self.formalSummary = formalSummary
        self.aiStatusRaw = aiStatus.rawValue
        self.aiModelName = aiModelName
        self.approvedAt = approvedAt
        self.transcriptSourceRaw = transcriptSource.rawValue
        self.transcriptUpdatedAt = transcriptUpdatedAt
        self.formalSummaryVersion = formalSummaryVersion
        self.recordingDeliveredAt = recordingDeliveredAt
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
