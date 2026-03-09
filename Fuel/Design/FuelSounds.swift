import AVFoundation

@MainActor
final class FuelSounds {
    static let shared = FuelSounds()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44100

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.12 // Subtle — enhancement, not distraction
    }

    private func ensureRunning() {
        guard !engine.isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // Silent fail — sounds are a nice-to-have
        }
    }

    // MARK: - Sound Effects

    /// Quick pop for card/option selections (~50ms, 880Hz)
    func pop() {
        playTone(frequency: 880, duration: 0.05, envelope: .sharp)
    }

    /// Forward swoosh for step transitions (~100ms, rising sweep)
    func swoosh() {
        playSweep(from: 450, to: 950, duration: 0.1, envelope: .smooth)
    }

    /// Short tick for counters and spinner clicks (~30ms)
    func tick() {
        playTone(frequency: 1100, duration: 0.03, envelope: .sharp)
    }

    /// Warm success chime — two ascending notes (C5 → E5)
    func chime() {
        playArpeggio(frequencies: [523.25, 659.25], noteDuration: 0.12, envelope: .warm)
    }

    /// Bright celebration — three ascending notes (C5 → E5 → G5)
    func celebration() {
        playArpeggio(frequencies: [523.25, 659.25, 783.99], noteDuration: 0.14, envelope: .warm)
    }

    // MARK: - Synthesis

    private enum Envelope {
        case sharp  // Fast attack, exponential decay
        case smooth // Linear fade
        case warm   // Soft attack, sustain, gentle release
    }

    private func playTone(frequency: Double, duration: Double, envelope: Envelope) {
        ensureRunning()
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let amp = envelopeValue(progress, type: envelope)
            data[i] = Float(sin(2.0 * .pi * frequency * t) * amp)
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func playSweep(from startFreq: Double, to endFreq: Double, duration: Double, envelope: Envelope) {
        ensureRunning()
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }

        var phase: Double = 0
        for i in 0..<Int(frameCount) {
            let progress = Double(i) / Double(frameCount)
            let freq = startFreq + (endFreq - startFreq) * progress
            let amp = envelopeValue(progress, type: envelope)
            data[i] = Float(sin(phase) * amp)
            phase += 2.0 * .pi * freq / sampleRate
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func playArpeggio(frequencies: [Double], noteDuration: Double, envelope: Envelope) {
        ensureRunning()
        let gap = 0.06
        let totalDuration = noteDuration * Double(frequencies.count) + gap * Double(max(0, frequencies.count - 1))
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        guard let data = buffer.floatChannelData?[0] else { return }

        // Zero fill
        for i in 0..<Int(frameCount) { data[i] = 0 }

        for (noteIndex, freq) in frequencies.enumerated() {
            let noteStart = Int(sampleRate * (noteDuration + gap) * Double(noteIndex))
            let noteFrames = Int(sampleRate * noteDuration)

            for i in 0..<noteFrames {
                let sampleIndex = noteStart + i
                guard sampleIndex < Int(frameCount) else { break }
                let t = Double(i) / sampleRate
                let progress = Double(i) / Double(noteFrames)
                let amp = envelopeValue(progress, type: envelope)
                // Fundamental + soft harmonic for warmth
                let fundamental = sin(2.0 * .pi * freq * t)
                let harmonic = sin(2.0 * .pi * freq * 2.0 * t) * 0.25
                data[sampleIndex] = Float((fundamental + harmonic) * amp * 0.8)
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func envelopeValue(_ progress: Double, type: Envelope) -> Double {
        switch type {
        case .sharp:
            if progress < 0.08 { return progress / 0.08 }
            return pow(1 - (progress - 0.08) / 0.92, 2.5)
        case .smooth:
            if progress < 0.12 { return progress / 0.12 }
            return 1.0 - (progress - 0.12) / 0.88
        case .warm:
            if progress < 0.15 { return progress / 0.15 }
            if progress < 0.5 { return 1.0 }
            return pow(1 - (progress - 0.5) / 0.5, 1.8)
        }
    }
}
