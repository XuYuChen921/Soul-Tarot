#if os(macOS)
import AVFoundation
import Combine
import Foundation
import Speech

enum VoiceIntakeRecorderError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable
    case onDeviceRecognitionUnavailable
    case invalidAudioInput

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied: return "未获得语音识别权限，请在系统设置的隐私与安全性中允许心塔使用语音识别。"
        case .microphonePermissionDenied: return "未获得麦克风权限，请在系统设置的隐私与安全性中允许心塔使用麦克风。"
        case .recognizerUnavailable: return "当前中文语音识别器不可用。"
        case .onDeviceRecognitionUnavailable: return "这台 Mac 当前不支持本机离线中文语音识别。为避免上传客户资料，请改为手动输入转写。"
        case .invalidAudioInput: return "没有检测到可用的麦克风输入。"
        }
    }
}

enum VoiceTranscriptRetention {
    static func resolvedText(current: String, lastNonEmpty: String, recognitionCandidate: String) -> String {
        let currentText = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousText = lastNonEmpty.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = recognitionCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let retained = currentText.isEmpty ? previousText : currentText

        guard !candidate.isEmpty else { return retained }
        guard !retained.isEmpty else { return candidate }
        if candidate == retained || retained.contains(candidate) { return retained }
        if candidate.contains(retained) { return candidate }

        // 本机识别的 partial result 可能突然回退成更短、但非空的句子。
        // 这种结果不能覆盖已经显示给用户的内容。
        if candidate.count <= retained.count { return retained }

        // 同一识别任务通常会返回从头开始的完整候选。只有公共前缀足够长时，
        // 才把更长候选当成对当前文字的继续修订。
        let prefixLength = commonPrefixLength(retained, candidate)
        if prefixLength >= max(2, min(retained.count, candidate.count) / 2) {
            return candidate
        }

        // 识别器若在长口述中重新起段，按前后重叠合并，防止整段消失或重复。
        let overlap = suffixPrefixOverlap(retained, candidate)
        if overlap >= 2 {
            return retained + candidate.dropFirst(overlap)
        }
        return retained + "\n" + candidate
    }

    private static func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        zip(lhs, rhs).prefix { $0 == $1 }.count
    }

    private static func suffixPrefixOverlap(_ lhs: String, _ rhs: String) -> Int {
        let maximum = min(lhs.count, rhs.count)
        guard maximum > 0 else { return 0 }
        for length in stride(from: maximum, through: 1, by: -1) {
            if lhs.suffix(length) == rhs.prefix(length) { return length }
        }
        return 0
    }
}

@MainActor
final class VoiceIntakeRecorder: ObservableObject {
    @Published var transcript = ""
    @Published private(set) var isRecording = false
    @Published var statusMessage = "尚未开始录音"

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var lastNonEmptyTranscript = ""
    private var activeSessionID: UUID?

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            do {
                try await startRecording()
            } catch {
                statusMessage = error.localizedDescription
                stopRecording()
            }
        }
    }

    func startRecording() async throws {
        guard await requestSpeechPermission() == .authorized else {
            throw VoiceIntakeRecorderError.speechPermissionDenied
        }
        guard await requestMicrophonePermission() else {
            throw VoiceIntakeRecorderError.microphonePermissionDenied
        }
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceIntakeRecorderError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw VoiceIntakeRecorderError.onDeviceRecognitionUnavailable
        }

        stopRecording(cancelRecognition: true)
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = true
        request = newRequest
        let sessionID = UUID()
        activeSessionID = sessionID

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceIntakeRecorderError.invalidAudioInput
        }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak newRequest] buffer, _ in
            newRequest?.append(buffer)
        }
        tapInstalled = true

        recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.activeSessionID == sessionID else { return }
                if let result {
                    let resolved = VoiceTranscriptRetention.resolvedText(
                        current: self.transcript,
                        lastNonEmpty: self.lastNonEmptyTranscript,
                        recognitionCandidate: result.bestTranscription.formattedString
                    )
                    self.transcript = resolved
                    if !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.lastNonEmptyTranscript = resolved
                    }
                    self.statusMessage = result.isFinal ? "本机转写完成，可交给本地 AI 整理" : "正在本机转写…"
                    if result.isFinal {
                        self.finishAudioCapture()
                        self.finishRecognitionSession(sessionID: sessionID)
                    }
                } else if let error {
                    if self.isRecording {
                        self.statusMessage = "转写中断：\(error.localizedDescription)"
                    } else if !self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.statusMessage = "本机转写完成，可交给本地 AI 整理"
                    }
                    self.finishAudioCapture()
                    self.finishRecognitionSession(sessionID: sessionID)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        statusMessage = "正在录音并使用本机语音识别…"
    }

    func stopRecording(cancelRecognition: Bool = false) {
        if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastNonEmptyTranscript = transcript
        }
        finishAudioCapture()
        if cancelRecognition {
            activeSessionID = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            request = nil
        } else {
            request?.endAudio()
            statusMessage = transcript.isEmpty ? "录音已停止，未识别到文字" : "录音已停止，正在完成转写…"
        }
    }

    func reset() {
        stopRecording(cancelRecognition: true)
        transcript = ""
        lastNonEmptyTranscript = ""
        statusMessage = "尚未开始录音"
    }

    private func finishRecognitionSession(sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        recognitionTask = nil
        request = nil
    }

    private func finishAudioCapture() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        isRecording = false
    }

    private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        default: return false
        }
    }
}
#endif
