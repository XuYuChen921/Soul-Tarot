import Foundation

struct BackupBrandProfile: Codable, Sendable {
    var id: UUID; var profileName: String; var brandName: String; var oneLinePositioning: String
    var targetAudience: String; var valuePromise: String; var tone: String; var commonWords: String
    var forbiddenWords: String; var serviceScope: String; var notSuitableFor: String; var pillars: String
    var wechatIntro: String; var xiaohongshuIntro: String; var visualStyle: String; var avatarHint: String
    var logoHint: String; var photoStyle: String; var signature: String; var profileVersion: String
    var effectiveAt: Date; var isActive: Bool; var createdAt: Date; var updatedAt: Date

    init(_ value: BrandProfile) {
        id = value.id; profileName = value.profileName; brandName = value.brandName
        oneLinePositioning = value.oneLinePositioning; targetAudience = value.targetAudience
        valuePromise = value.valuePromise; tone = value.tone; commonWords = value.commonWords
        forbiddenWords = value.forbiddenWords; serviceScope = value.serviceScope
        notSuitableFor = value.notSuitableFor; pillars = value.pillars; wechatIntro = value.wechatIntro
        xiaohongshuIntro = value.xiaohongshuIntro; visualStyle = value.visualStyle
        avatarHint = value.avatarHint; logoHint = value.logoHint; photoStyle = value.photoStyle
        signature = value.signature; profileVersion = value.profileVersion; effectiveAt = value.effectiveAt
        isActive = value.isActive; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandProfile {
        BrandProfile(id: id, profileName: profileName, brandName: brandName,
            oneLinePositioning: oneLinePositioning, targetAudience: targetAudience,
            valuePromise: valuePromise, tone: tone, commonWords: commonWords,
            forbiddenWords: forbiddenWords, serviceScope: serviceScope, notSuitableFor: notSuitableFor,
            pillars: pillars, wechatIntro: wechatIntro, xiaohongshuIntro: xiaohongshuIntro,
            visualStyle: visualStyle, avatarHint: avatarHint, logoHint: logoHint, photoStyle: photoStyle,
            signature: signature, profileVersion: profileVersion, effectiveAt: effectiveAt,
            isActive: isActive, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandTopic: Codable, Sendable {
    var id: UUID; var profileID: UUID; var title: String; var rawIdea: String; var targetAudience: String
    var pillar: String; var goalRaw: String; var sourceTypeRaw: String; var sensitivity: String
    var customerReference: String; var linkedAssetIDsText: String?; var actionHint: String; var priority: Int
    var plannedPublishAt: Date?; var statusRaw: String; var isArchived: Bool; var createdAt: Date; var updatedAt: Date

    init(_ value: BrandContentTopic) {
        id = value.id; profileID = value.profileID; title = value.title; rawIdea = value.rawIdea
        targetAudience = value.targetAudience; pillar = value.pillar; goalRaw = value.goalRaw
        sourceTypeRaw = value.sourceTypeRaw; sensitivity = value.sensitivity
        customerReference = value.customerReference; linkedAssetIDsText = value.linkedAssetIDsText
        actionHint = value.actionHint; priority = value.priority; plannedPublishAt = value.plannedPublishAt
        statusRaw = value.statusRaw; isArchived = value.isArchived; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandContentTopic {
        BrandContentTopic(id: id, profileID: profileID, title: title, rawIdea: rawIdea,
            targetAudience: targetAudience, pillar: pillar,
            goal: BrandTopicGoal(rawValue: goalRaw) ?? .trust,
            sourceType: BrandTopicSource(rawValue: sourceTypeRaw) ?? .personalOpinion,
            sensitivity: sensitivity, customerReference: customerReference,
            linkedAssetIDsText: linkedAssetIDsText, actionHint: actionHint, priority: priority,
            plannedPublishAt: plannedPublishAt, status: BrandTopicStatus(rawValue: statusRaw) ?? .active,
            isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandDraft: Codable, Sendable {
    var id: UUID; var topicID: UUID; var channelRaw: String; var statusRaw: String; var sourceRaw: String
    var version: Int; var title: String; var subtitle: String; var opening: String; var content: String
    var actionPrompt: String; var imageSuggestion: String; var keywordsText: String; var hashtagText: String
    var searchTitleText: String; var resonanceTitleText: String; var riskWarningsText: String
    var generatedBy: String; var aiModelName: String; var profileVersion: String; var generatedAt: Date
    var approvedAt: Date?; var approvedBy: String; var createdAt: Date; var updatedAt: Date
    var linkedAssetIDsText: String?

    init(_ value: BrandDraft) {
        id = value.id; topicID = value.topicID; channelRaw = value.channelRaw; statusRaw = value.statusRaw
        sourceRaw = value.sourceRaw; version = value.version; title = value.title; subtitle = value.subtitle
        opening = value.opening; content = value.content; actionPrompt = value.actionPrompt
        imageSuggestion = value.imageSuggestion; keywordsText = value.keywordsText; hashtagText = value.hashtagText
        searchTitleText = value.searchTitleText; resonanceTitleText = value.resonanceTitleText
        riskWarningsText = value.riskWarningsText; generatedBy = value.generatedBy; aiModelName = value.aiModelName
        profileVersion = value.profileVersion; generatedAt = value.generatedAt; approvedAt = value.approvedAt
        approvedBy = value.approvedBy; createdAt = value.createdAt; updatedAt = value.updatedAt
        linkedAssetIDsText = value.linkedAssetIDsText
    }

    func model() -> BrandDraft {
        let value = BrandDraft(id: id, topicID: topicID,
            channel: BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments,
            title: title, subtitle: subtitle, opening: opening, content: content,
            actionPrompt: actionPrompt, imageSuggestion: imageSuggestion, keywordsText: keywordsText,
            hashtagText: hashtagText, searchTitleText: searchTitleText, resonanceTitleText: resonanceTitleText,
            riskWarningsText: riskWarningsText, source: BrandDraftSource(rawValue: sourceRaw) ?? .manual,
            aiModelName: aiModelName, profileVersion: profileVersion, generatedBy: generatedBy,
            status: BrandDraftStatus(rawValue: statusRaw) ?? .drafting, version: version,
            createdAt: createdAt, updatedAt: updatedAt, linkedAssetIDsText: linkedAssetIDsText)
        value.generatedAt = generatedAt; value.approvedAt = approvedAt; value.approvedBy = approvedBy
        return value
    }
}

struct BackupBrandDraftRevision: Codable, Sendable {
    var id: UUID; var draftID: UUID; var topicID: UUID; var channelRaw: String; var version: Int
    var title: String; var subtitle: String; var opening: String; var content: String; var actionPrompt: String
    var imageSuggestion: String; var keywordsText: String; var hashtagText: String; var searchTitleText: String
    var resonanceTitleText: String; var riskWarningsText: String; var sourceRaw: String; var aiModelName: String
    var profileVersion: String; var statusRaw: String; var approvedAt: Date?; var savedAt: Date

    init(_ value: BrandDraftRevision) {
        id = value.id; draftID = value.draftID; topicID = value.topicID; channelRaw = value.channelRaw
        version = value.version; title = value.title; subtitle = value.subtitle; opening = value.opening
        content = value.content; actionPrompt = value.actionPrompt; imageSuggestion = value.imageSuggestion
        keywordsText = value.keywordsText; hashtagText = value.hashtagText; searchTitleText = value.searchTitleText
        resonanceTitleText = value.resonanceTitleText; riskWarningsText = value.riskWarningsText
        sourceRaw = value.sourceRaw; aiModelName = value.aiModelName; profileVersion = value.profileVersion
        statusRaw = value.statusRaw; approvedAt = value.approvedAt; savedAt = value.savedAt
    }

    func model() -> BrandDraftRevision {
        let draft = BrandDraft(id: draftID, topicID: topicID,
            channel: BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments,
            title: title, subtitle: subtitle, opening: opening, content: content,
            actionPrompt: actionPrompt, imageSuggestion: imageSuggestion, keywordsText: keywordsText,
            hashtagText: hashtagText, searchTitleText: searchTitleText, resonanceTitleText: resonanceTitleText,
            riskWarningsText: riskWarningsText, source: BrandDraftSource(rawValue: sourceRaw) ?? .manual,
            aiModelName: aiModelName, profileVersion: profileVersion,
            status: BrandDraftStatus(rawValue: statusRaw) ?? .drafting, version: version)
        draft.approvedAt = approvedAt
        let value = BrandDraftRevision(draft: draft, savedAt: savedAt)
        value.id = id
        return value
    }
}

struct BackupBrandPublishRecord: Codable, Sendable {
    var id: UUID; var topicID: UUID; var draftID: UUID?; var channelRaw: String; var plannedAt: Date?
    var publishedAt: Date?; var platformPostID: String; var platformLink: String; var note: String
    var snapshotTitle: String; var snapshotContent: String; var publishedAsApproved: Bool
    var collectedBy: String; var createdAt: Date; var updatedAt: Date

    init(_ value: BrandPublishRecord) {
        id = value.id; topicID = value.topicID; draftID = value.draftID; channelRaw = value.channelRaw
        plannedAt = value.plannedAt; publishedAt = value.publishedAt; platformPostID = value.platformPostID
        platformLink = value.platformLink; note = value.note; snapshotTitle = value.snapshotTitle
        snapshotContent = value.snapshotContent; publishedAsApproved = value.publishedAsApproved
        collectedBy = value.collectedBy; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandPublishRecord {
        BrandPublishRecord(id: id, topicID: topicID, draftID: draftID,
            channel: BrandDistributionChannel(rawValue: channelRaw) ?? .wechatMoments,
            plannedAt: plannedAt, publishedAt: publishedAt, platformPostID: platformPostID,
            platformLink: platformLink, note: note, snapshotTitle: snapshotTitle,
            snapshotContent: snapshotContent, publishedAsApproved: publishedAsApproved,
            collectedBy: collectedBy, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandAsset: Codable, Sendable {
    var id: UUID; var name: String; var kindRaw: String; var source: String; var owner: String
    var permissionRaw: String; var allowedChannelsText: String; var expiryAt: Date?; var revokedAt: Date?
    var useScope: String; var note: String; var createdAt: Date; var updatedAt: Date; var categoryRaw: String?
    var clientID: UUID?; var consentID: UUID?; var originalFilename: String?; var relativePath: String?
    var fileSize: Int64?; var sha256: String?; var deidentifiedSummary: String?
    var directIdentifiersRemoved: Bool?; var indirectIdentifiersReviewed: Bool?; var secondReviewCompleted: Bool?
    var secondReviewer: String?; var reviewedAt: Date?; var allowedFormatsText: String?

    init(_ value: BrandAsset) {
        id = value.id; name = value.name; kindRaw = value.kindRaw; source = value.source; owner = value.owner
        permissionRaw = value.permissionRaw; allowedChannelsText = value.allowedChannelsText
        expiryAt = value.expiryAt; revokedAt = value.revokedAt; useScope = value.useScope; note = value.note
        createdAt = value.createdAt; updatedAt = value.updatedAt; categoryRaw = value.categoryRaw
        clientID = value.clientID; consentID = value.consentID; originalFilename = value.originalFilename
        relativePath = value.relativePath; fileSize = value.fileSize; sha256 = value.sha256
        deidentifiedSummary = value.deidentifiedSummary; directIdentifiersRemoved = value.directIdentifiersRemoved
        indirectIdentifiersReviewed = value.indirectIdentifiersReviewed; secondReviewCompleted = value.secondReviewCompleted
        secondReviewer = value.secondReviewer; reviewedAt = value.reviewedAt; allowedFormatsText = value.allowedFormatsText
    }

    func model() -> BrandAsset {
        BrandAsset(id: id, name: name, kind: BrandAssetType(rawValue: kindRaw) ?? .photo,
            source: source, owner: owner, permission: BrandAssetPermission(rawValue: permissionRaw) ?? .pendingReview,
            allowedChannelsText: allowedChannelsText, expiryAt: expiryAt, revokedAt: revokedAt,
            useScope: useScope, note: note, createdAt: createdAt, updatedAt: updatedAt,
            category: BrandAssetCategory(rawValue: categoryRaw ?? "") ?? .brandOwned,
            clientID: clientID, consentID: consentID, originalFilename: originalFilename,
            relativePath: relativePath, fileSize: fileSize, sha256: sha256,
            deidentifiedSummary: deidentifiedSummary, directIdentifiersRemoved: directIdentifiersRemoved ?? false,
            indirectIdentifiersReviewed: indirectIdentifiersReviewed ?? false,
            secondReviewCompleted: secondReviewCompleted ?? false, secondReviewer: secondReviewer,
            reviewedAt: reviewedAt, allowedFormatsText: allowedFormatsText)
    }
}

struct BackupBrandMetricSnapshot: Codable, Sendable {
    var id: UUID; var publishRecordID: UUID; var collectedAt: Date; var periodStart: Date; var periodEnd: Date
    var methodRaw: String; var exposure: Int?; var views: Int?; var likes: Int?; var comments: Int?
    var favorites: Int?; var shares: Int?; var profileVisits: Int?; var followers: Int?; var privateMessages: Int?
    var missingReasons: String; var sourceFile: String; var isCumulative: Bool; var isConfirmed: Bool
    var createdAt: Date; var updatedAt: Date

    init(_ value: BrandMetricSnapshot) {
        id = value.id; publishRecordID = value.publishRecordID; collectedAt = value.collectedAt
        periodStart = value.periodStart; periodEnd = value.periodEnd; methodRaw = value.methodRaw
        exposure = value.exposure; views = value.views; likes = value.likes; comments = value.comments
        favorites = value.favorites; shares = value.shares; profileVisits = value.profileVisits
        followers = value.followers; privateMessages = value.privateMessages; missingReasons = value.missingReasons
        sourceFile = value.sourceFile; isCumulative = value.isCumulative; isConfirmed = value.isConfirmed
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandMetricSnapshot {
        BrandMetricSnapshot(id: id, publishRecordID: publishRecordID, collectedAt: collectedAt,
            periodStart: periodStart, periodEnd: periodEnd,
            method: BrandMetricCollectionMode(rawValue: methodRaw) ?? .manual,
            exposure: exposure, views: views, likes: likes, comments: comments, favorites: favorites,
            shares: shares, profileVisits: profileVisits, followers: followers, privateMessages: privateMessages,
            missingReasons: missingReasons, sourceFile: sourceFile, isCumulative: isCumulative,
            isConfirmed: isConfirmed, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandPlatformConnection: Codable, Sendable {
    var id: UUID; var platformRaw: String; var accountLabel: String; var accountType: String
    var capabilityRaw: String; var statusRaw: String; var officialDocumentURL: String; var verificationNote: String
    var isAPIApproved: Bool; var credentialStoredAt: Date?; var tokenExpiresAt: Date?
    var lastAttemptAt: Date?; var lastSuccessfulSyncAt: Date?; var lastErrorCategory: String; var lastErrorMessage: String
    var createdAt: Date; var updatedAt: Date

    init(_ value: BrandPlatformConnection) {
        id = value.id; platformRaw = value.platformRaw; accountLabel = value.accountLabel; accountType = value.accountType
        capabilityRaw = value.capabilityRaw; statusRaw = value.statusRaw
        officialDocumentURL = value.officialDocumentURL; verificationNote = value.verificationNote
        isAPIApproved = value.isAPIApproved; credentialStoredAt = value.credentialStoredAt; tokenExpiresAt = value.tokenExpiresAt
        lastAttemptAt = value.lastAttemptAt; lastSuccessfulSyncAt = value.lastSuccessfulSyncAt
        lastErrorCategory = value.lastErrorCategory; lastErrorMessage = value.lastErrorMessage
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandPlatformConnection {
        BrandPlatformConnection(
            id: id,
            platform: BrandPlatformKind(rawValue: platformRaw) ?? .wechatPersonalMoments,
            accountLabel: accountLabel,
            accountType: accountType,
            capability: BrandPlatformCapability(rawValue: capabilityRaw) ?? .manualImportOnly,
            status: BrandPlatformConnectionStatus(rawValue: statusRaw) ?? .manualOnly,
            officialDocumentURL: officialDocumentURL,
            verificationNote: verificationNote,
            isAPIApproved: isAPIApproved,
            credentialStoredAt: nil,
            tokenExpiresAt: nil,
            lastAttemptAt: lastAttemptAt,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            lastErrorCategory: lastErrorCategory,
            lastErrorMessage: lastErrorMessage,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct BackupBrandSyncRun: Codable, Sendable {
    var id: UUID; var connectionID: UUID; var statusRaw: String; var requestedAt: Date; var completedAt: Date?
    var importedCount: Int; var skippedDuplicateCount: Int; var errorCategory: String; var safeMessage: String

    init(_ value: BrandSyncRun) {
        id = value.id; connectionID = value.connectionID; statusRaw = value.statusRaw
        requestedAt = value.requestedAt; completedAt = value.completedAt
        importedCount = value.importedCount; skippedDuplicateCount = value.skippedDuplicateCount
        errorCategory = value.errorCategory; safeMessage = value.safeMessage
    }

    func model() -> BrandSyncRun {
        BrandSyncRun(
            id: id,
            connectionID: connectionID,
            status: BrandSyncRunStatus(rawValue: statusRaw) ?? .failed,
            requestedAt: requestedAt,
            completedAt: completedAt,
            importedCount: importedCount,
            skippedDuplicateCount: skippedDuplicateCount,
            errorCategory: errorCategory,
            safeMessage: safeMessage
        )
    }
}

struct BackupBrandSyncReceipt: Codable, Sendable {
    var id: UUID; var fingerprint: String; var connectionID: UUID; var remoteItemID: String
    var publishRecordID: UUID; var metricSnapshotID: UUID; var receivedAt: Date

    init(_ value: BrandSyncItemReceipt) {
        id = value.id; fingerprint = value.fingerprint; connectionID = value.connectionID
        remoteItemID = value.remoteItemID; publishRecordID = value.publishRecordID
        metricSnapshotID = value.metricSnapshotID; receivedAt = value.receivedAt
    }

    func model() -> BrandSyncItemReceipt {
        BrandSyncItemReceipt(
            id: id,
            fingerprint: fingerprint,
            connectionID: connectionID,
            remoteItemID: remoteItemID,
            publishRecordID: publishRecordID,
            metricSnapshotID: metricSnapshotID,
            receivedAt: receivedAt
        )
    }
}

struct BackupBrandExperiment: Codable, Sendable {
    var id: UUID; var title: String; var dimensionRaw: String; var hypothesis: String
    var variantALabel: String; var variantAPublishRecordID: UUID; var variantBLabel: String; var variantBPublishRecordID: UUID
    var statusRaw: String; var factualComparison: String; var conclusion: String
    var startedAt: Date; var endedAt: Date?; var createdAt: Date; var updatedAt: Date

    init(_ value: BrandExperiment) {
        id = value.id; title = value.title; dimensionRaw = value.dimensionRaw; hypothesis = value.hypothesis
        variantALabel = value.variantALabel; variantAPublishRecordID = value.variantAPublishRecordID
        variantBLabel = value.variantBLabel; variantBPublishRecordID = value.variantBPublishRecordID
        statusRaw = value.statusRaw; factualComparison = value.factualComparison; conclusion = value.conclusion
        startedAt = value.startedAt; endedAt = value.endedAt; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandExperiment {
        BrandExperiment(
            id: id,
            title: title,
            dimension: BrandExperimentDimension(rawValue: dimensionRaw) ?? .titleDirection,
            hypothesis: hypothesis,
            variantALabel: variantALabel,
            variantAPublishRecordID: variantAPublishRecordID,
            variantBLabel: variantBLabel,
            variantBPublishRecordID: variantBPublishRecordID,
            status: BrandExperimentStatus(rawValue: statusRaw) ?? .planned,
            factualComparison: factualComparison,
            conclusion: conclusion,
            startedAt: startedAt,
            endedAt: endedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct BackupBrandWeeklyReview: Codable, Sendable {
    var id: UUID; var periodStart: Date; var periodEnd: Date; var plannedGenerateAt: Date; var generatedAt: Date?
    var summaryText: String; var conclusionText: String; var bestText: String; var worstText: String
    var conversionText: String; var channelWechatRole: String; var channelXhsRole: String; var dataGapText: String
    var continueText: String; var stopText: String; var experimentText: String; var usedSnapshotIDsText: String?
    var statusRaw: String; var approvedAt: Date?; var approvedBy: String; var createdAt: Date; var updatedAt: Date

    init(_ value: BrandWeeklyReview) {
        id = value.id; periodStart = value.periodStart; periodEnd = value.periodEnd
        plannedGenerateAt = value.plannedGenerateAt; generatedAt = value.generatedAt
        summaryText = value.summaryText; conclusionText = value.conclusionText; bestText = value.bestText
        worstText = value.worstText; conversionText = value.conversionText
        channelWechatRole = value.channelWechatRole; channelXhsRole = value.channelXhsRole
        dataGapText = value.dataGapText; continueText = value.continueText; stopText = value.stopText
        experimentText = value.experimentText; usedSnapshotIDsText = value.usedSnapshotIDsText
        statusRaw = value.statusRaw; approvedAt = value.approvedAt; approvedBy = value.approvedBy
        createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandWeeklyReview {
        BrandWeeklyReview(id: id, periodStart: periodStart, periodEnd: periodEnd,
            plannedGenerateAt: plannedGenerateAt, generatedAt: generatedAt, summaryText: summaryText,
            conclusionText: conclusionText, bestText: bestText, worstText: worstText,
            conversionText: conversionText, channelWechatRole: channelWechatRole,
            channelXhsRole: channelXhsRole, dataGapText: dataGapText, continueText: continueText,
            stopText: stopText, experimentText: experimentText, usedSnapshotIDsText: usedSnapshotIDsText,
            status: BrandReviewStatus(rawValue: statusRaw) ?? .drafting, approvedAt: approvedAt,
            approvedBy: approvedBy, createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandMarketingTouchpoint: Codable, Sendable {
    var id: UUID; var clientID: UUID; var clientCodeSnapshot: String; var clientNameSnapshot: String
    var channelRaw: String?; var publishRecordID: UUID?; var keyword: String; var firstContactAt: Date
    var evidenceRaw: String; var confirmationMethod: String; var note: String; var isActive: Bool
    var createdAt: Date; var updatedAt: Date

    init(_ value: BrandMarketingTouchpoint) {
        id = value.id; clientID = value.clientID; clientCodeSnapshot = value.clientCodeSnapshot
        clientNameSnapshot = value.clientNameSnapshot; channelRaw = value.channelRaw
        publishRecordID = value.publishRecordID; keyword = value.keyword; firstContactAt = value.firstContactAt
        evidenceRaw = value.evidenceRaw; confirmationMethod = value.confirmationMethod; note = value.note
        isActive = value.isActive; createdAt = value.createdAt; updatedAt = value.updatedAt
    }

    func model() -> BrandMarketingTouchpoint {
        BrandMarketingTouchpoint(id: id, clientID: clientID, clientCodeSnapshot: clientCodeSnapshot,
            clientNameSnapshot: clientNameSnapshot,
            channel: channelRaw.flatMap(BrandDistributionChannel.init(rawValue:)),
            publishRecordID: publishRecordID, keyword: keyword, firstContactAt: firstContactAt,
            evidence: BrandAttributionEvidence(rawValue: evidenceRaw) ?? .unattributed,
            confirmationMethod: confirmationMethod, note: note, isActive: isActive,
            createdAt: createdAt, updatedAt: updatedAt)
    }
}

struct BackupBrandAssetAudit: Codable, Sendable {
    var id: UUID; var assetID: UUID; var consentID: UUID?; var actionRaw: String
    var detail: String; var actor: String; var occurredAt: Date
    init(_ value: BrandAssetAuditEvent) {
        id = value.id; assetID = value.assetID; consentID = value.consentID; actionRaw = value.actionRaw
        detail = value.detail; actor = value.actor; occurredAt = value.occurredAt
    }
    func model() -> BrandAssetAuditEvent {
        BrandAssetAuditEvent(id: id, assetID: assetID, consentID: consentID,
            action: BrandAssetAuditAction(rawValue: actionRaw) ?? .created,
            detail: detail, actor: actor, occurredAt: occurredAt)
    }
}

struct BackupBrandAssetUsage: Codable, Sendable {
    var id: UUID; var assetID: UUID; var topicID: UUID?; var draftID: UUID?
    var publishRecordID: UUID?; var channelRaw: String?; var action: String; var occurredAt: Date
    init(_ value: BrandAssetUsage) {
        id = value.id; assetID = value.assetID; topicID = value.topicID; draftID = value.draftID
        publishRecordID = value.publishRecordID; channelRaw = value.channelRaw
        action = value.action; occurredAt = value.occurredAt
    }
    func model() -> BrandAssetUsage {
        BrandAssetUsage(id: id, assetID: assetID, topicID: topicID, draftID: draftID,
            publishRecordID: publishRecordID,
            channel: channelRaw.flatMap(BrandDistributionChannel.init(rawValue:)),
            action: action, occurredAt: occurredAt)
    }
}

struct BackupBrandAssetTask: Codable, Sendable {
    var id: UUID; var assetID: UUID; var draftID: UUID?; var publishRecordID: UUID?
    var typeRaw: String; var statusRaw: String; var detail: String; var createdAt: Date; var resolvedAt: Date?
    init(_ value: BrandAssetActionTask) {
        id = value.id; assetID = value.assetID; draftID = value.draftID; publishRecordID = value.publishRecordID
        typeRaw = value.typeRaw; statusRaw = value.statusRaw; detail = value.detail
        createdAt = value.createdAt; resolvedAt = value.resolvedAt
    }
    func model() -> BrandAssetActionTask {
        BrandAssetActionTask(id: id, assetID: assetID, draftID: draftID,
            publishRecordID: publishRecordID, type: BrandAssetTaskType(rawValue: typeRaw) ?? .discardDraft,
            status: BrandAssetTaskStatus(rawValue: statusRaw) ?? .pending,
            detail: detail, createdAt: createdAt, resolvedAt: resolvedAt)
    }
}

struct BackupBrandFile: Codable, Sendable {
    var assetID: UUID
    var relativePath: String
    var byteCount: Int64
    var chunkCount: Int
    var sha256: String
}
