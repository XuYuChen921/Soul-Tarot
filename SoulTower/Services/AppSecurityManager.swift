import Foundation
import LocalAuthentication

private struct AppLockCredential: Codable, Sendable {
    let salt: Data
    let verifier: Data
    let iterations: Int
}

enum AppSecurityError: LocalizedError {
    case passwordTooShort
    case passwordMismatch
    case confirmationMismatch
    case credentialMissing
    case biometricUnavailable

    var errorDescription: String? {
        switch self {
        case .passwordTooShort: return "应用密码至少需要 6 位。"
        case .passwordMismatch: return "当前应用密码不正确。"
        case .confirmationMismatch: return "两次输入的新应用密码不一致。"
        case .credentialMissing: return "没有找到应用锁凭据，请重新启用应用锁。"
        case .biometricUnavailable: return "当前设备没有可用的 Face ID 或 Touch ID。"
        }
    }
}

@MainActor
final class AppSecurityManager: ObservableObject {
    private enum Key {
        static let enabled = "security.appLockEnabled"
        static let biometric = "security.biometricEnabled"
        static let credentialAccount = "app-lock-credential-v1"
    }

    private let defaults: UserDefaults
    @Published private(set) var isLockEnabled: Bool
    @Published private(set) var biometricUnlockEnabled: Bool
    @Published private(set) var isUnlocked: Bool
    @Published var errorMessage = ""
    private var autoLockSuspensionCount = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hasCredential = (try? KeychainStore.data(account: Key.credentialAccount)) != nil
        let enabled = defaults.bool(forKey: Key.enabled) && hasCredential
        isLockEnabled = enabled
        biometricUnlockEnabled = enabled && defaults.bool(forKey: Key.biometric)
        isUnlocked = !enabled
        if defaults.bool(forKey: Key.enabled) && !hasCredential {
            defaults.set(false, forKey: Key.enabled)
            defaults.set(false, forKey: Key.biometric)
        }
    }

    var biometryLabel: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "生物识别不可用"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "生物识别"
        }
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func configure(password: String, enableBiometrics: Bool) async throws {
        guard password.count >= 6 else { throw AppSecurityError.passwordTooShort }
        let credential = try await Task.detached(priority: .userInitiated) {
            let salt = try PasswordCrypto.randomData(count: 16)
            let key = try PasswordCrypto.deriveKey(password: password, salt: salt)
            return AppLockCredential(
                salt: salt,
                verifier: PasswordCrypto.verifier(for: key),
                iterations: PasswordCrypto.defaultIterations
            )
        }.value
        let data = try JSONEncoder().encode(credential)
        try KeychainStore.set(data, account: Key.credentialAccount)
        isLockEnabled = true
        biometricUnlockEnabled = enableBiometrics && canUseBiometrics
        isUnlocked = true
        defaults.set(true, forKey: Key.enabled)
        defaults.set(biometricUnlockEnabled, forKey: Key.biometric)
        errorMessage = ""
    }

    func verify(password: String) async throws -> Bool {
        guard let data = try KeychainStore.data(account: Key.credentialAccount) else {
            throw AppSecurityError.credentialMissing
        }
        let credential = try JSONDecoder().decode(AppLockCredential.self, from: data)
        return try await Task.detached(priority: .userInitiated) {
            let key = try PasswordCrypto.deriveKey(
                password: password,
                salt: credential.salt,
                iterations: credential.iterations
            )
            return PasswordCrypto.constantTimeEqual(
                PasswordCrypto.verifier(for: key),
                credential.verifier
            )
        }.value
    }

    func unlock(password: String) async {
        do {
            guard try await verify(password: password) else {
                throw AppSecurityError.passwordMismatch
            }
            isUnlocked = true
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlockWithBiometrics() async {
        guard biometricUnlockEnabled else { return }
        let context = LAContext()
        context.localizedCancelTitle = "使用应用密码"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            errorMessage = AppSecurityError.biometricUnavailable.localizedDescription
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁心塔并查看本机客户资料"
            )
            if success {
                isUnlocked = true
                errorMessage = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setBiometricUnlock(_ enabled: Bool) {
        biometricUnlockEnabled = enabled && canUseBiometrics && isLockEnabled
        defaults.set(biometricUnlockEnabled, forKey: Key.biometric)
    }

    func disable(password: String) async throws {
        guard try await verify(password: password) else {
            throw AppSecurityError.passwordMismatch
        }
        try KeychainStore.delete(account: Key.credentialAccount)
        isLockEnabled = false
        biometricUnlockEnabled = false
        isUnlocked = true
        defaults.set(false, forKey: Key.enabled)
        defaults.set(false, forKey: Key.biometric)
        errorMessage = ""
    }

    func lock() {
        guard isLockEnabled, autoLockSuspensionCount == 0 else { return }
        isUnlocked = false
        errorMessage = ""
    }

    func suspendAutoLock() {
        autoLockSuspensionCount += 1
    }

    func resumeAutoLock() {
        autoLockSuspensionCount = max(0, autoLockSuspensionCount - 1)
    }
}
