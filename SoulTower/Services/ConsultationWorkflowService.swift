import Foundation

enum ConsultationWorkflowError: LocalizedError, Equatable {
    case archivedRecord
    case missingRetentionConsent
    case missingRecordingConsent
    case missingPhotoConsent
    case missingLocalAIConsent
    case archiveIncomplete([String])

    var errorDescription: String? {
        switch self {
        case .archivedRecord:
            return "该咨询已经归档；需要修改时请先重新打开归档。"
        case .missingRetentionConsent:
            return "未找到有效的长期保存同意，不能永久保存本次资料。"
        case .missingRecordingConsent:
            return "未找到有效的录音同意，不能导入或处理咨询录音。"
        case .missingPhotoConsent:
            return "未找到有效的牌阵照片同意，不能导入照片。"
        case .missingLocalAIConsent:
            return "未找到有效的本地 AI 处理同意，只能人工整理。"
        case .archiveIncomplete(let items):
            return "暂不能归档，请先完成：\(items.joined(separator: "、"))。"
        }
    }
}

struct ConsultationArchiveAssessment: Equatable {
    let status: ConsultationArchiveStatus
    let missingItems: [String]
    var canArchive: Bool { status != .archived && missingItems.isEmpty }
}

enum ConsultationWorkflowService {
    static func hasAcceptedConsent(
        _ type: ConsentType,
        appointmentID: UUID?,
        consents: [ConsentRecord]
    ) -> Bool {
        guard let appointmentID else { return false }
        return consents.contains {
            $0.appointmentID == appointmentID
                && $0.type == type
                && $0.accepted
                && $0.withdrawnAt == nil
        }
    }

    static func validateImport(
        kind: MediaKind,
        record: ConsultationRecord,
        consents: [ConsentRecord]
    ) throws {
        guard record.archivedAt == nil else { throw ConsultationWorkflowError.archivedRecord }
        guard hasAcceptedConsent(.longTermRetention, appointmentID: record.appointmentID, consents: consents) else {
            throw ConsultationWorkflowError.missingRetentionConsent
        }
        if kind == .audio,
           !hasAcceptedConsent(.recording, appointmentID: record.appointmentID, consents: consents) {
            throw ConsultationWorkflowError.missingRecordingConsent
        }
        if kind == .image,
           !hasAcceptedConsent(.photo, appointmentID: record.appointmentID, consents: consents) {
            throw ConsultationWorkflowError.missingPhotoConsent
        }
    }

    static func validateLocalAI(record: ConsultationRecord, consents: [ConsentRecord]) throws {
        guard record.archivedAt == nil else { throw ConsultationWorkflowError.archivedRecord }
        guard hasAcceptedConsent(.longTermRetention, appointmentID: record.appointmentID, consents: consents) else {
            throw ConsultationWorkflowError.missingRetentionConsent
        }
        guard hasAcceptedConsent(.localAI, appointmentID: record.appointmentID, consents: consents) else {
            throw ConsultationWorkflowError.missingLocalAIConsent
        }
    }

    static func assessment(
        record: ConsultationRecord,
        assets: [MediaAsset],
        consents: [ConsentRecord]
    ) -> ConsultationArchiveAssessment {
        if record.archivedAt != nil {
            return ConsultationArchiveAssessment(status: .archived, missingItems: [])
        }

        let hasAudio = assets.contains { $0.kind == .audio }
        let hasImage = assets.contains { $0.kind == .image }
        let recordingAccepted = hasAcceptedConsent(.recording, appointmentID: record.appointmentID, consents: consents)
        let photoAccepted = hasAcceptedConsent(.photo, appointmentID: record.appointmentID, consents: consents)
        let retentionAccepted = hasAcceptedConsent(.longTermRetention, appointmentID: record.appointmentID, consents: consents)
        let localAIAccepted = hasAcceptedConsent(.localAI, appointmentID: record.appointmentID, consents: consents)
        var missing: [String] = []

        if !retentionAccepted { missing.append("长期保存同意") }
        if recordingAccepted && !hasAudio { missing.append("咨询录音") }
        if hasAudio && !recordingAccepted { missing.append("录音同意") }
        if hasAudio && record.recordingDeliveredAt == nil { missing.append("录音已交付客户") }
        if hasImage && !photoAccepted { missing.append("牌阵照片同意") }
        if record.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.append("文字转写")
        }
        if record.formalSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || record.approvedAt == nil {
            missing.append("经人工批准的正式摘要")
        }
        if !record.aiModelName.isEmpty && !localAIAccepted { missing.append("本地 AI 处理同意") }

        let status: ConsultationArchiveStatus
        if missing.isEmpty {
            status = .review
        } else if assets.isEmpty || record.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .collecting
        } else if record.formalSummary.isEmpty || record.approvedAt == nil {
            status = .organizing
        } else {
            status = .review
        }
        return ConsultationArchiveAssessment(status: status, missingItems: missing)
    }

    static func validateArchive(
        record: ConsultationRecord,
        assets: [MediaAsset],
        consents: [ConsentRecord]
    ) throws {
        let result = assessment(record: record, assets: assets, consents: consents)
        guard result.status != .archived else { throw ConsultationWorkflowError.archivedRecord }
        guard result.missingItems.isEmpty else {
            throw ConsultationWorkflowError.archiveIncomplete(result.missingItems)
        }
    }

    static func mergedTranscript(existing: String, generated: String) -> String {
        let current = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let newText = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else { return current }
        guard !current.isEmpty else { return newText }
        return current + "\n\n--- 本机录音转写 ---\n" + newText
    }

    static func activity(
        record: ConsultationRecord,
        kind: ConsultationActivityKind,
        title: String,
        detail: String = "",
        at date: Date = .now
    ) -> ConsultationActivity {
        ConsultationActivity(
            recordID: record.id,
            clientID: record.clientID,
            kind: kind,
            title: title,
            detail: detail,
            occurredAt: date
        )
    }
}
