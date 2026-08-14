import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let policyVersion = "policyVersion"
        static let recordingConsentVersion = "recordingConsentVersion"
        static let photoConsentVersion = "photoConsentVersion"
        static let aiConsentVersion = "aiConsentVersion"
        static let retentionConsentVersion = "retentionConsentVersion"
        static let aiBaseURL = "aiBaseURL"
        static let aiModelName = "aiModelName"
        static let aiModelPolicyVersion = "aiModelPolicyVersion"
    }

    @Published var policyVersion: String { didSet { save(policyVersion, key: Key.policyVersion) } }
    @Published var recordingConsentVersion: String { didSet { save(recordingConsentVersion, key: Key.recordingConsentVersion) } }
    @Published var photoConsentVersion: String { didSet { save(photoConsentVersion, key: Key.photoConsentVersion) } }
    @Published var aiConsentVersion: String { didSet { save(aiConsentVersion, key: Key.aiConsentVersion) } }
    @Published var retentionConsentVersion: String { didSet { save(retentionConsentVersion, key: Key.retentionConsentVersion) } }
    @Published var aiBaseURL: String { didSet { save(aiBaseURL, key: Key.aiBaseURL) } }
    @Published var aiModelName: String { didSet { save(aiModelName, key: Key.aiModelName) } }
    @Published var notificationAuthorization: String = "尚未检查"
    @Published var aiConnectionStatus: String = "尚未检测"
    @Published var migrationStatus: String = "正在检查"

    init(defaults: UserDefaults = .standard) {
        policyVersion = defaults.string(forKey: Key.policyVersion) ?? "RULE-2026-08-12"
        recordingConsentVersion = defaults.string(forKey: Key.recordingConsentVersion) ?? "RECORDING-DEFAULT-1"
        photoConsentVersion = defaults.string(forKey: Key.photoConsentVersion) ?? "PHOTO-DEFAULT-1"
        aiConsentVersion = defaults.string(forKey: Key.aiConsentVersion) ?? "LOCAL-AI-DEFAULT-1"
        retentionConsentVersion = defaults.string(forKey: Key.retentionConsentVersion) ?? "RETENTION-DEFAULT-1"
        aiBaseURL = defaults.string(forKey: Key.aiBaseURL) ?? "http://127.0.0.1:11434"

        let savedModel = defaults.string(forKey: Key.aiModelName)
        let savedPolicyVersion = defaults.integer(forKey: Key.aiModelPolicyVersion)
        if savedModel == nil || (savedPolicyVersion < LocalAIModelPolicy.policyVersion && savedModel == LocalAIModelPolicy.fallbackModel) {
            aiModelName = LocalAIModelPolicy.recommendedModel
            defaults.set(aiModelName, forKey: Key.aiModelName)
            defaults.set(LocalAIModelPolicy.policyVersion, forKey: Key.aiModelPolicyVersion)
        } else {
            aiModelName = savedModel ?? LocalAIModelPolicy.recommendedModel
        }
    }

    private func save(_ value: String, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
