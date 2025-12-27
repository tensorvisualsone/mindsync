import Foundation
import AVFoundation

final class IsochronicAudioService {
    static let shared = IsochronicAudioService()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isPlaying = false

    /// Carrier frequency (Hz) - the audible tone that will be gated by the entrainment pulse
    var carrierFrequency: Double = 200.0

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("IsochronicAudioService: Audio session error - \(error)")
        }
    }

    /// Startet den isochronen Ton synchron zum Entrainment-Mode (ramping wird anhand der Mode-Parameter berechnet)
    /// - Parameters:
    ///   - mode: Entrainment mode describing start/target frequency and ramp duration
    ///   - attachToEngine: Optional external AVAudioEngine to attach the source node to. If provided,
    ///                     the service will attach its node to that engine's main mixer (recommended
    ///                     for cinematic mode to ensure perfect sync with file playback). If nil, the
    ///                     service will use an internal engine.
    func start(mode: EntrainmentMode, attachToEngine externalEngine: AVAudioEngine? = nil) {
        stop()

        let startFreq = mode.startFrequency
        let targetFreq = mode.targetFrequency
        let rampDuration = mode.rampDuration
        let carrierFreq = carrierFrequency

        var sampleTime: Double = 0
        var carrierPhase: Double = 0
        var pulsePhase: Double = 0

        let sampleRate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Create source node
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = abl[0].mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                let currentTime = sampleTime / sampleRate

                let progress = rampDuration > 0 ? min(currentTime / rampDuration, 1.0) : 1.0
                let smooth = MathHelpers.smoothstep(progress)
                let currentEntrainmentFreq = startFreq + (targetFreq - startFreq) * smooth

                carrierPhase += 2.0 * .pi * carrierFreq / sampleRate
                pulsePhase += 2.0 * .pi * currentEntrainmentFreq / sampleRate

                if carrierPhase >= 2.0 * .pi { carrierPhase -= 2.0 * .pi }
                if pulsePhase >= 2.0 * .pi { pulsePhase -= 2.0 * .pi }

                let carrierSignal = sin(carrierPhase)
                let modulator = (1.0 + cos(pulsePhase - .pi)) * 0.5
                let sampleValue = Float(carrierSignal * modulator) * 0.5

                buffer[frame] = sampleValue

                sampleTime += 1
            }

            return noErr
        }

        sourceNode = node

        // If an external engine is provided, attach to it. Otherwise use internal engine.
        if let engineToUse = externalEngine {
            engineToUse.attach(node)
            engineToUse.connect(node, to: engineToUse.mainMixerNode, format: format)

            // If the external engine isn't running, try to start it (best-effort)
            if !engineToUse.isRunning {
                do {
                    try engineToUse.start()
                } catch {
                    print("IsochronicAudioService: failed to start external engine: \(error)")
                }
            }

            isPlaying = true
            print("IsochronicAudioService: attached to external engine (carrier: \(carrierFreq)Hz)")
            return
        }

        // Fallback: use internal engine
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            isPlaying = true
            print("IsochronicAudioService: started internal engine (carrier: \(carrierFreq)Hz)")
        } catch {
            print("IsochronicAudioService: engine start error - \(error)")
        }
    }

    func stop() {
        if isPlaying {
            engine.stop()
            engine.reset()
            if let node = sourceNode { engine.detach(node) }
            sourceNode = nil
            isPlaying = false
        }
    }

    func setVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = max(0.0, min(1.0, volume))
    }
}
