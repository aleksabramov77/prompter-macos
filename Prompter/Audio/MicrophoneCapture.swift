@preconcurrency import AVFoundation

/// Микрофон пользователя через AVAudioEngine. Работает без разрешения на запись экрана,
/// поэтому режим тренировки (без собеседника) требует только доступ к микрофону.
final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private(set) var isRunning = false

    /// Вызывается на аудиопотоке.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    /// Уровень сигнала в dBFS, вызывается на аудиопотоке.
    var onLevel: ((Float) -> Void)?

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw PrompterError.message("Не найден микрофон. Проверьте вход в Системных настройках → Звук.")
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onLevel?(AudioLevel.decibels(of: buffer))
            self.onBuffer?(buffer)
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}

enum AudioLevel {
    /// Порог «пользователь издаёт звук» в dBFS.
    static let voiceThreshold: Float = -42

    static func decibels(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -160 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count {
            sum += channel[i] * channel[i]
        }
        let rms = (sum / Float(count)).squareRoot()
        return rms > 0 ? 20 * log10(rms) : -160
    }
}
