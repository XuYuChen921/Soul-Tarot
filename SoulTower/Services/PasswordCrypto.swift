import Foundation
import CryptoKit
import CommonCrypto
import Security

enum PasswordCryptoError: LocalizedError {
    case randomGenerationFailed
    case keyDerivationFailed
    case invalidEncryptedData

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed: return "无法生成安全随机数。"
        case .keyDerivationFailed: return "无法生成加密密钥。"
        case .invalidEncryptedData: return "加密资料已损坏或密码不正确。"
        }
    }
}

enum PasswordCrypto {
    static let defaultIterations = 210_000

    static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw PasswordCryptoError.randomGenerationFailed }
        return data
    }

    static func deriveKey(
        password: String,
        salt: Data,
        iterations: Int = defaultIterations,
        keyLength: Int = 32
    ) throws -> Data {
        guard let passwordData = password.data(using: .utf8), !passwordData.isEmpty else {
            throw PasswordCryptoError.keyDerivationFailed
        }
        var key = Data(count: keyLength)
        let status: Int32 = passwordData.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                key.withUnsafeMutableBytes { keyBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        keyBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw PasswordCryptoError.keyDerivationFailed }
        return key
    }

    static func verifier(for keyData: Data) -> Data {
        let key = SymmetricKey(data: keyData)
        let code = HMAC<SHA256>.authenticationCode(
            for: Data("SoulTower-App-Lock-V1".utf8),
            using: key
        )
        return Data(code)
    }

    static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func seal(_ data: Data, keyData: Data) throws -> Data {
        let box = try AES.GCM.seal(data, using: SymmetricKey(data: keyData))
        guard let combined = box.combined else { throw PasswordCryptoError.invalidEncryptedData }
        return combined
    }

    static func open(_ encrypted: Data, keyData: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: encrypted)
            return try AES.GCM.open(box, using: SymmetricKey(data: keyData))
        } catch {
            throw PasswordCryptoError.invalidEncryptedData
        }
    }
}
