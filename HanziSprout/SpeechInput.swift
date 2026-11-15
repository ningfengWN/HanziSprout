import AVFoundation
import Speech
import SwiftUI

/// Microphone capture is independent of Speech's silence/final-result detection.
/// Only the user, an audio interruption, or backgrounding ends capture.
@MainActor
final class SpeechInput: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum Phase { case idle, preparing, recording, transcribing }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var transcript = ""
    @Published private(set) var error: String?
    var isRecording: Bool { phase == .recording }
    var isBusy: Bool { phase != .idle }
    var buttonTitle: String {
        switch phase {
        case .idle: return "按一下，说给我听"
        case .preparing: return "正在准备，点此取消"
        case .recording: return "说好了，开始识别"
        case .transcribing: return "正在识别，点此取消"
        }
    }
    var elapsedText: String {
        let seconds = Int(elapsedSeconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var timeout: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?
    private var generation = 0
    private var localeIdentifier: String
    private let onDeviceOnly: Bool

    init(localeIdentifier: String = "zh-CN", onDeviceOnly: Bool = false) {
        self.localeIdentifier = localeIdentifier
        self.onDeviceOnly = onDeviceOnly
        super.init()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                == AVAudioSession.InterruptionType.began.rawValue
            guard began else { return }
            Task { @MainActor in self?.interrupted() }
        }
    }
    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        timer?.invalidate()
        timeout?.cancel()
        recorder?.delegate = nil
        recorder?.stop()
        task?.cancel()
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
    }

    func toggle() {
        switch phase {
        case .idle: authorize()
        case .recording: finishRecording()
        case .preparing, .transcribing: stop()
        }
    }
    func setLanguage(_ locale: String) {
        stop()
        localeIdentifier = locale
    }
    private func authorize() {
        stop()
        if onDeviceOnly {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.supportsOnDeviceRecognition else {
                error = "设备暂不支持这个语言的离线听写，请输入文字或点选句子。不会转用云端识别。"
                return
            }
        }
        error = nil
        phase = .preparing
        let token = generation
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self, self.accepts(token, phase: .preparing) else { return }
                guard status == .authorized else {
                    self.fail("请在系统设置里允许字芽使用语音识别，也可以直接输入文字。")
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                    Task { @MainActor in
                        guard let self, self.accepts(token, phase: .preparing) else { return }
                        guard allowed else {
                            self.fail("请在系统设置里允许麦克风，也可以直接输入文字。")
                            return
                        }
                        self.beginRecording()
                    }
                }
            }
        }
    }
    private func accepts(_ token: Int, phase: Phase) -> Bool {
        generation == token && self.phase == phase
    }
    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("HanziSprout-\(UUID().uuidString).m4a")
            audioURL = url
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            recorder.delegate = self
            self.recorder = recorder
            guard recorder.prepareToRecord(), recorder.record() else {
                fail("麦克风没有成功开始录音，请检查是否被其他 App 占用后重试。")
                return
            }
            transcript = ""
            elapsedSeconds = 0
            phase = .recording
            let token = generation
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.accepts(token, phase: .recording) else { return }
                    guard let recorder = self.recorder, recorder.isRecording else {
                        self.fail("录音被系统中断，请再点一次麦克风重新说。")
                        return
                    }
                    self.elapsedSeconds = recorder.currentTime
                }
            }
        } catch {
            fail("麦克风启动失败，请稍后重试或直接输入文字。")
        }
    }
    private func finishRecording() {
        guard phase == .recording, let recorder, let url = audioURL else { return }
        elapsedSeconds = recorder.currentTime
        // Change phase and detach the delegate before stop(), so a stop callback
        // cannot cancel the recognition task about to start.
        phase = .transcribing
        timer?.invalidate(); timer = nil
        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard elapsedSeconds >= 0.25 else {
            fail("刚才录音太短啦。再点一次，等出现“正在录音”后说话，说完再点“说好了”。")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            fail("语音识别暂不可用，请检查网络后重新录音，或直接输入文字。")
            return
        }
        if onDeviceOnly && !recognizer.supportsOnDeviceRecognition {
            fail("设备暂不支持离线听写，请输入文字或点选句子。")
            return
        }
        self.recognizer = recognizer
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDeviceOnly
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        let token = generation
        task = recognizer.recognitionTask(with: request) { [weak self] result, failure in
            Task { @MainActor in
                guard let self, self.accepts(token, phase: .transcribing) else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if result?.isFinal == true {
                    let empty = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    self.stop()
                    if empty { self.error = "没有听清文字，请靠近麦克风再说一次。" }
                } else if failure != nil {
                    self.fail(self.transcript.isEmpty
                        ? "没能识别这段录音，请检查网络后重试，或直接输入文字。"
                        : "识别没有完整完成，已保留听到的文字，请检查后继续。")
                }
            }
        }
        timeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
            guard let self, self.accepts(token, phase: .transcribing) else { return }
            self.fail("识别等待太久，已保留听到的文字。请检查网络后重试，或直接输入文字。")
        }
    }
    /// Cancel preparation/capture/recognition on explicit navigation or backgrounding.
    /// Inactive is deliberately NOT handled here: permission sheets cause inactivity.
    func stop() {
        generation += 1
        phase = .idle
        timer?.invalidate(); timer = nil
        timeout?.cancel(); timeout = nil
        recorder?.delegate = nil
        recorder?.stop(); recorder = nil
        task?.cancel(); task = nil; recognizer = nil
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func fail(_ message: String) { stop(); error = message }
    private func interrupted() {
        if phase == .recording { fail("录音被来电或其他音频打断，请再点麦克风重新说。") }
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder, self.phase == .recording else { return }
            self.fail(flag ? "录音已被系统停止，请重新录音。" : "录音未成功完成，请重试。")
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder, self.phase == .recording else { return }
            self.fail("录音保存失败，请检查设备存储空间后重试。")
        }
    }
}
