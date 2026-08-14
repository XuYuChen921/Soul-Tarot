import Foundation
import Speech

enum LocalAudioTranscriptionError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case onDeviceRecognitionUnavailable
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得语音识别权限，请在系统设置中允许心塔使用语音识别。"
        case .recognizerUnavailable:
            return "当前无法使用中文语音识别。"
        case .onDeviceRecognitionUnavailable:
            return "当前设备不支持本机离线中文转写；为避免上传客户录音，已停止处理。"
        case .emptyResult:
            return "本机没有从该录音中识别到文字。"
        }
    }
}

@MainActor
final class LocalAudioTranscriptionService {
    private var recognitionTask: SFSpeechRecognitionTask?

    func transcribe(fileURL: URL) async throws -> String {
        let authorization = await authorizationStatus()
        guard authorization == .authorized else {
            throw LocalAudioTranscriptionError.permissionDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            throw LocalAudioTranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw LocalAudioTranscriptionError.onDeviceRecognitionUnavailable
        }

        recognitionTask?.cancel()
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: LocalAudioTranscriptionError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }

    private func authorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
