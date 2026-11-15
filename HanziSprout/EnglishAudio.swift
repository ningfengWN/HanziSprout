import AVFoundation
import SwiftUI

@MainActor
final class EnglishAudio: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var preparing = false
    @Published private(set) var hasRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var seconds: TimeInterval = 0
    @Published private(set) var error: String?
    private let speaker = AVSpeechSynthesizer()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var file: URL?
    private var timer: Timer?
    private var generation = 0
    private var observer: NSObjectProtocol?
    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in
                guard let self else { return }
                self.clear()
                self.error = "声音被系统打断，请重新录音或播放。"
            }
        }
    }
    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        timer?.invalidate(); recorder?.delegate = nil; recorder?.stop(); player?.stop()
        if let file { try? FileManager.default.removeItem(at: file) }
    }
    private func playbackSession() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .spokenAudio, options: .mixWithOthers)
        try audio.setActive(true)
    }
    func speak(_ text: String, language: String = "en-US", slow: Bool = false) {
        guard !isRecording && !preparing else { return }
        error = nil
        do {
            try playbackSession()
            guard let voice = AVSpeechSynthesisVoice(language: language) else {
                error = "设备暂时没有可用的朗读语音。"; return
            }
            player?.stop(); isPlaying = false; speaker.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice; utterance.rate = slow ? 0.32 : 0.45; utterance.volume = 1
            speaker.speak(utterance)
        } catch { self.error = "无法播放，请检查设备音频输出。" }
    }
    func toggleRecording() {
        if isRecording { finish(); return }
        if preparing { clear(); return }
        clear(); error = nil; preparing = true
        let token = generation
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self, self.generation == token, self.preparing else { return }
                guard allowed else { self.preparing = false; self.error = "请在系统设置里允许麦克风；仍可以听例句。"; return }
                self.start()
            }
        }
    }
    private func start() {
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .default); try audio.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("SproutEnglish-\(UUID().uuidString).m4a")
            file = url
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey:kAudioFormatMPEG4AAC, AVSampleRateKey:44100, AVNumberOfChannelsKey:1, AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue])
            self.recorder = recorder; recorder.delegate = self
            guard recorder.prepareToRecord(), recorder.record() else { clear(); error = "录音没能启动，请重试。"; return }
            preparing = false; isRecording = true; seconds = 0
            let token = generation
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == token, self.isRecording else { return }
                    guard self.recorder?.isRecording == true else { self.clear(); self.error = "录音被打断，请重试。"; return }
                    self.seconds = self.recorder?.currentTime ?? 0
                }
            }
        } catch { clear(); self.error = "麦克风启动失败，请重试。" }
    }
    private func finish() {
        seconds = recorder?.currentTime ?? 0
        timer?.invalidate(); timer = nil
        recorder?.delegate = nil; recorder?.stop(); recorder = nil; isRecording = false
        hasRecording = seconds >= 0.25
        if !hasRecording { error = "录音太短了，再试一次吧。"; if let file { try? FileManager.default.removeItem(at:file) }; file = nil }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func replay() {
        guard hasRecording, !isRecording, let file else { return }
        if isPlaying { player?.stop(); isPlaying = false; return }
        do {
            speaker.stopSpeaking(at: .immediate); try playbackSession()
            let player = try AVAudioPlayer(contentsOf: file); self.player = player; player.delegate = self
            guard player.play() else { error = "无法播放这段录音，请重新录制。"; return }
            isPlaying = true
        } catch { self.error = "录音回放失败，请重试。" }
    }
    func clear() {
        error = nil
        generation += 1
        preparing = false; isRecording = false; hasRecording = false; isPlaying = false; seconds = 0
        timer?.invalidate(); timer = nil
        recorder?.delegate = nil; recorder?.stop(); recorder = nil
        player?.stop(); player = nil; speaker.stopSpeaking(at: .immediate)
        if let file { try? FileManager.default.removeItem(at: file) }; file = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder, self.isRecording else { return }
            self.clear(); self.error = "录音被系统结束，请重试。"
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.clear(); self.error = "录音保存失败，请重试。"
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.player === player else { return }
            self?.isPlaying = false
        }
    }
}
