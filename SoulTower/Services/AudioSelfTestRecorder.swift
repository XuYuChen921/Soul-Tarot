import AVFoundation
import Combine
import Foundation

enum AudioSelfTestError: LocalizedError {
    case microphonePermissionDenied
    case recorderUnavailable
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "未获得麦克风权限，请在系统设置中允许心塔使用麦克风。"
        case .recorderUnavailable:
            return "没有检测到可用的麦克风，无法开始测试。"
        case .emptyRecording:
            return "测试录音没有生成有效声音文件。"
        }
    }
}

@MainActor
final class AudioSelfTestRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var canPlay = false
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var remainingSeconds = 10
    @Published private(set) var transcript = ""
    @Published private(set) var statusMessage = "尚未测试"

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var temporaryURL: URL?
    private var countdownTask: Task<Void, Never>?
    private var meteringTask: Task<Void, Never>?

    func start() async {
        cleanup()
        transcript = ""
        canPlay = false
        remainingSeconds = 10

        do {
            guard await requestMicrophonePermission() else {
                throw AudioSelfTestError.microphonePermissionDenied
            }
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            #endif

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("soultower-audio-test-\(UUID().uuidString)")
                .appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else {
                throw AudioSelfTestError.recorderUnavailable
            }

            self.recorder = recorder
            temporaryURL = url
            isRecording = true
            statusMessage = "正在录音，请读：心塔设备测试，本地录音不会保存。"
            startMetering()
            startCountdown()
        } catch {
            statusMessage = error.localizedDescription
            cleanup()
        }
    }

    func stopAndTranscribe() async {
        guard isRecording else { return }
        countdownTask?.cancel()
        countdownTask = nil
        meteringTask?.cancel()
        meteringTask = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        inputLevel = 0

        guard let url = temporaryURL else {
            statusMessage = AudioSelfTestError.emptyRecording.localizedDescription
            return
        }

        do {
            let audioData = try Data(contentsOf: url)
            guard !audioData.isEmpty else { throw AudioSelfTestError.emptyRecording }
            player = try AVAudioPlayer(data: audioData)
            player?.prepareToPlay()
            canPlay = true
            isTranscribing = true
            statusMessage = "录音正常，正在进行本机离线中文转写…"
            defer {
                isTranscribing = false
                removeTemporaryFile()
            }

            transcript = try await LocalAudioTranscriptionService().transcribe(fileURL: url)
            statusMessage = "设备自检通过：麦克风、回放和本机离线转写均可用。"
        } catch {
            statusMessage = "已完成麦克风录音；本机转写未通过：\(error.localizedDescription)"
            removeTemporaryFile()
            isTranscribing = false
        }
    }

    func play() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
        statusMessage = transcript.isEmpty ? "正在回放测试录音。" : "正在回放测试录音；本机转写也已完成。"
    }

    func cleanup() {
        countdownTask?.cancel()
        meteringTask?.cancel()
        countdownTask = nil
        meteringTask = nil
        recorder?.stop()
        player?.stop()
        recorder = nil
        player = nil
        isRecording = false
        isTranscribing = false
        canPlay = false
        inputLevel = 0
        removeTemporaryFile()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func startCountdown() {
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for value in stride(from: 9, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, self.isRecording else { return }
                self.remainingSeconds = value
            }
            await self.stopAndTranscribe()
        }
    }

    private func startMetering() {
        meteringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isRecording {
                self.recorder?.updateMeters()
                let decibels = Double(self.recorder?.averagePower(forChannel: 0) ?? -60)
                self.inputLevel = min(max((decibels + 60) / 60, 0), 1)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func removeTemporaryFile() {
        if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        temporaryURL = nil
    }

    private func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        default:
            return false
        }
        #endif
    }
}
