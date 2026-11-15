import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechInput: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var installedTap = false
    private var generation = 0
    private var wanted = false

    func toggle() {
        if isRecording || wanted { stop(); return }
        wanted = true
        error = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard self?.wanted == true else { return }
                guard status == .authorized else { self?.error = "请在系统设置里允许字芽使用语音识别，也可以直接输入文字。"; return }
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    Task { @MainActor in
                        guard self?.wanted == true else { return }
                        guard allowed else { self?.error = "请在系统设置里允许麦克风，也可以直接输入文字。"; return }
                        self?.start()
                    }
                }
            }
        }
    }
    private func start() {
        stop()
        wanted = true
        let token = generation
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            error = "语音识别暂不可用，请输入文字。"; return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "Microphone", code: 1) }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            transcript = ""
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            installedTap = true
            engine.prepare()
            try engine.start()
            isRecording = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                Task { @MainActor in
                    guard self?.generation == token else { return }
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if failure != nil || result?.isFinal == true {
                        if failure != nil && self?.isRecording == true { self?.error = "录音已结束；可以检查文字后继续。" }
                        self?.stop()
                    }
                }
            }
        } catch { self.error = "麦克风启动失败，请稍后重试或输入文字。"; stop() }
    }
    func stop() {
        generation += 1
        wanted = false
        isRecording = false
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
