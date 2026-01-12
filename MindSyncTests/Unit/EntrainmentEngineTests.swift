import XCTest
@testable import MindSync

final class EntrainmentEngineTests: XCTestCase {
    
    var engine: EntrainmentEngine!
    
    override func setUp() {
        super.setUp()
        engine = EntrainmentEngine()
    }
    
    func testGenerateLightScript_WithBeats() {
        let track = AudioTrack(
            title: "Test Track",
            artist: "Test Artist",
            duration: 10.0,
            bpm: 120.0,
            beatTimestamps: [0.0, 0.5, 1.0, 1.5, 2.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen,
            screenColor: .white
        )
        
        XCTAssertEqual(script.trackId, track.id)
        XCTAssertEqual(script.mode, .alpha)
        XCTAssertEqual(script.events.count, 5) // One event per beat
        XCTAssertGreaterThan(script.targetFrequency, 0)
    }
    
    func testGenerateLightScript_NoBeats_Fallback() {
        let track = AudioTrack(
            title: "Test Track",
            duration: 10.0,
            bpm: 120.0,
            beatTimestamps: []
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen
        )
        
        // Should generate fallback events
        XCTAssertGreaterThan(script.events.count, 0)
    }
    
    func testGenerateLightScript_AlphaMode_SquareWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0, 0.5, 1.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen
        )
        
        // Alpha mode should use square waveform for better visual patterns (Phosphene)
        XCTAssertEqual(script.events.first?.waveform, .square)
    }
    
    func testGenerateLightScript_ThetaMode_SquareWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0, 0.5, 1.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .theta,
            lightSource: .screen
        )
        
        // Theta mode should use square waveform for better visual patterns (Phosphene)
        XCTAssertEqual(script.events.first?.waveform, .square)
    }
    
    func testGenerateLightScript_Fallback_AlphaMode_SquareWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [] // No beats - triggers fallback
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen
        )
        
        // Fallback events for alpha mode should also use square waveform
        XCTAssertGreaterThan(script.events.count, 0)
        XCTAssertEqual(script.events.first?.waveform, .square)
    }
    
    func testGenerateLightScript_Fallback_ThetaMode_SquareWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [] // No beats - triggers fallback
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .theta,
            lightSource: .screen
        )
        
        // Fallback events for theta mode should also use square waveform
        XCTAssertGreaterThan(script.events.count, 0)
        XCTAssertEqual(script.events.first?.waveform, .square)
    }
    
    func testGenerateLightScript_Fallback_CinematicMode_SineWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [] // No beats - triggers fallback
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .cinematic,
            lightSource: .screen
        )
        
        // Fallback events for cinematic mode should use sine waveform
        XCTAssertGreaterThan(script.events.count, 0)
        XCTAssertEqual(script.events.first?.waveform, .sine)
    }
    
    func testGenerateLightScript_GammaMode_SquareWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0, 0.5, 1.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .gamma,
            lightSource: .screen
        )
        
        // Gamma mode should use square waveform
        XCTAssertEqual(script.events.first?.waveform, .square)
    }
    
    func testGenerateLightScript_ScreenMode_WithColor() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen,
            screenColor: .blue
        )
        
        XCTAssertEqual(script.events.first?.color, .blue)
    }
    
    func testGenerateLightScript_FlashlightMode_NoColor() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .flashlight,
            screenColor: .blue
        )
        
        // Flashlight mode should ignore color
        XCTAssertNil(script.events.first?.color)
    }
    
    func testGenerateLightScript_VerySlowBPM() {
        let track = AudioTrack(
            title: "Test",
            duration: 10.0,
            bpm: 30.0, // Very slow
            beatTimestamps: [0.0, 2.0, 4.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen
        )
        
        // Should still generate valid script
        XCTAssertGreaterThan(script.targetFrequency, 0)
        XCTAssertEqual(script.events.count, 3)
    }
    
    func testGenerateLightScript_VeryFastBPM() {
        let track = AudioTrack(
            title: "Test",
            duration: 10.0,
            bpm: 200.0, // Very fast
            beatTimestamps: [0.0, 0.3, 0.6]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .gamma,
            lightSource: .screen
        )
        
        // Should still generate valid script
        XCTAssertGreaterThan(script.targetFrequency, 0)
        XCTAssertEqual(script.events.count, 3)
    }
    
    func testGenerateLightScript_IntensityByMode() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0]
        )
        
        let alphaScript = engine.generateLightScript(
            from: track,
            mode: .alpha,
            lightSource: .screen
        )
        
        let gammaScript = engine.generateLightScript(
            from: track,
            mode: .gamma,
            lightSource: .screen
        )
        
        // Gamma should have higher intensity than alpha
        XCTAssertGreaterThan(
            gammaScript.events.first?.intensity ?? 0,
            alphaScript.events.first?.intensity ?? 0
        )
    }
    
    func testGenerateLightScript_CinematicMode_SineWaveform() {
        let track = AudioTrack(
            title: "Test",
            duration: 5.0,
            bpm: 120.0,
            beatTimestamps: [0.0, 0.5, 1.0]
        )
        
        let script = engine.generateLightScript(
            from: track,
            mode: .cinematic,
            lightSource: .screen
        )
        
        // Cinematic mode should use sine waveform
        XCTAssertEqual(script.events.first?.waveform, .sine)
        // Base intensity should be 0.5 (dynamically modulated at runtime)
        if let intensity = script.events.first?.intensity {
            XCTAssertEqual(intensity, 0.5, accuracy: 0.01)
        } else {
            XCTFail("Intensity should not be nil")
        }
    }
    
    func testCalculateCinematicIntensity_BaseCase() {
        let baseFreq = 6.5
        let currentTime: TimeInterval = 0.0
        let audioEnergy: Float = 0.5
        
        let intensity = EntrainmentEngine.calculateCinematicIntensity(
            baseFrequency: baseFreq,
            currentTime: currentTime,
            audioEnergy: audioEnergy
        )
        
        // Should return a valid intensity value in 0.0-1.0 range
        XCTAssertGreaterThanOrEqual(intensity, 0.0)
        XCTAssertLessThanOrEqual(intensity, 1.0)
    }
    
    func testCalculateCinematicIntensity_LowAudioEnergy() {
        let baseFreq = 6.5
        let currentTime: TimeInterval = 1.0
        let audioEnergy: Float = 0.0 // No audio energy
        
        let intensity = EntrainmentEngine.calculateCinematicIntensity(
            baseFrequency: baseFreq,
            currentTime: currentTime,
            audioEnergy: audioEnergy
        )
        
        // With low audio energy, baseIntensity should be minimum (0.3)
        // But wave modulation still applies, so intensity can vary
        XCTAssertGreaterThanOrEqual(intensity, 0.0)
        XCTAssertLessThanOrEqual(intensity, 1.0)
    }
    
    func testCalculateCinematicIntensity_HighAudioEnergy() {
        let baseFreq = 6.5
        let currentTime: TimeInterval = 1.0
        let audioEnergy: Float = 1.0 // Maximum audio energy
        
        let intensity = EntrainmentEngine.calculateCinematicIntensity(
            baseFrequency: baseFreq,
            currentTime: currentTime,
            audioEnergy: audioEnergy
        )
        
        // With high audio energy, should have higher base intensity
        XCTAssertGreaterThanOrEqual(intensity, 0.0)
        XCTAssertLessThanOrEqual(intensity, 1.0)
    }
    
    func testCalculateCinematicIntensity_FrequencyDrift() {
        let baseFreq = 6.5
        let audioEnergy: Float = 0.5
        
        // Test at different times to verify frequency drift
        let intensity1 = EntrainmentEngine.calculateCinematicIntensity(
            baseFrequency: baseFreq,
            currentTime: 0.0,
            audioEnergy: audioEnergy
        )
        
        let intensity2 = EntrainmentEngine.calculateCinematicIntensity(
            baseFrequency: baseFreq,
            currentTime: 5.0, // Different time = different drift
            audioEnergy: audioEnergy
        )
        
        // Intensities should be valid but may differ due to frequency drift
        XCTAssertGreaterThanOrEqual(intensity1, 0.0)
        XCTAssertLessThanOrEqual(intensity1, 1.0)
        XCTAssertGreaterThanOrEqual(intensity2, 0.0)
        XCTAssertLessThanOrEqual(intensity2, 1.0)
    }
    
    // MARK: - DMN-Shutdown Mode Tests
    
    func testGenerateDMNShutdownScript_StructureAndDuration() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Verify script properties
        XCTAssertEqual(script.mode, .dmnShutdown)
        XCTAssertEqual(script.targetFrequency, 40.0) // Peak frequency (Gamma)
        XCTAssertEqual(script.multiplier, 1)
        
        // Verify total duration is 30 minutes (1800 seconds)
        XCTAssertEqual(script.duration, 1800.0, accuracy: 1.0)
        
        // Verify events exist
        XCTAssertGreaterThan(script.events.count, 0)
    }
    
    func testGenerateDMNShutdownScript_Phase1Structure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Phase 1: ENTRY (0-180 seconds = 3 minutes)
        // 180 events at 1-second intervals at constant 10Hz with sine waves
        let phase1Events = script.events.filter { $0.timestamp < 180 }
        
        XCTAssertEqual(phase1Events.count, 180)
        
        // Verify first event
        if let firstEvent = phase1Events.first {
            XCTAssertEqual(firstEvent.timestamp, 0.0)
            XCTAssertEqual(firstEvent.waveform, .sine) // Changed to sine
            XCTAssertEqual(firstEvent.intensity, 0.4, accuracy: 0.01)
            XCTAssertEqual(firstEvent.duration, 1.0)
            XCTAssertEqual(firstEvent.color, .blue)
            // Frequency should be constant 10Hz
            XCTAssertNotNil(firstEvent.frequencyOverride)
            XCTAssertEqual(firstEvent.frequencyOverride ?? 0, 10.0, accuracy: 0.01)
        }
        
        // Verify last event of phase 1
        if let lastEvent = phase1Events.last {
            XCTAssertEqual(lastEvent.waveform, .sine) // Changed to sine
            // Frequency should still be 10Hz (constant)
            XCTAssertNotNil(lastEvent.frequencyOverride)
            XCTAssertEqual(lastEvent.frequencyOverride ?? 0, 10.0, accuracy: 0.01)
        }
    }
    
    func testGenerateDMNShutdownScript_Phase2Structure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Phase 2: THE ABYSS (180-720 seconds = 9 minutes)
        // 270 events at 2-second intervals at 4.5Hz
        let phase2Events = script.events.filter { $0.timestamp >= 180 && $0.timestamp < 720 }
        
        XCTAssertEqual(phase2Events.count, 270)
        
        // Verify phase 2 events
        if let firstEvent = phase2Events.first {
            XCTAssertEqual(firstEvent.waveform, .sine) // Changed to sine
            XCTAssertEqual(firstEvent.duration, 2.0)
            XCTAssertEqual(firstEvent.color, .purple)
            XCTAssertNotNil(firstEvent.frequencyOverride)
            XCTAssertEqual(firstEvent.frequencyOverride ?? 0, 4.5, accuracy: 0.01)
        }
        
        // Verify alternating intensity (0.35/0.1 instead of 0.35/0.0)
        if phase2Events.count >= 2 {
            let firstIntensity = phase2Events[0].intensity
            let secondIntensity = phase2Events[1].intensity
            XCTAssertNotEqual(firstIntensity, secondIntensity)
            XCTAssertTrue([0.35, 0.1].contains { abs($0 - firstIntensity) < 0.01 })
            XCTAssertTrue([0.35, 0.1].contains { abs($0 - secondIntensity) < 0.01 })
        }
    }
    
    func testGenerateDMNShutdownScript_Phase3Structure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Phase 3: DISSOLUTION (720-1200 seconds = 8 minutes)
        // Randomized events with varying frequency, intensity, and duration
        // Uses fixed seed for reproducibility
        let phase3Events = script.events.filter { $0.timestamp >= 720 && $0.timestamp < 1200 }
        
        // Should have multiple events (actual count varies due to random durations)
        XCTAssertGreaterThan(phase3Events.count, 100) // At least 100 events expected
        XCTAssertLessThan(phase3Events.count, 400) // At most 400 events expected
        
        // Verify randomized properties
        if let firstEvent = phase3Events.first {
            XCTAssertEqual(firstEvent.waveform, .sine)
            XCTAssertEqual(firstEvent.color, .purple)
            XCTAssertNotNil(firstEvent.frequencyOverride)
            // Frequency should be between 3.5-6.0 Hz
            let freq = firstEvent.frequencyOverride ?? 0
            XCTAssertGreaterThanOrEqual(freq, 3.5)
            XCTAssertLessThanOrEqual(freq, 6.0)
            // Intensity should be between 0.2-0.5
            XCTAssertGreaterThanOrEqual(firstEvent.intensity, 0.2)
            XCTAssertLessThanOrEqual(firstEvent.intensity, 0.5)
            // Duration should be between 1.5-3.0
            XCTAssertGreaterThanOrEqual(firstEvent.duration, 1.5)
            XCTAssertLessThanOrEqual(firstEvent.duration, 3.0)
        }
        
        // Verify events have varying properties (not all the same)
        let uniqueFrequencies = Set(phase3Events.compactMap { $0.frequencyOverride })
        let uniqueIntensities = Set(phase3Events.map { $0.intensity })
        XCTAssertGreaterThan(uniqueFrequencies.count, 10) // Multiple different frequencies
        XCTAssertGreaterThan(uniqueIntensities.count, 10) // Multiple different intensities
    }
    
    func testGenerateDMNShutdownScript_TransitionRampStructure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Transition Ramp (1200-1230 seconds = 30 seconds)
        // Smooth transition from Theta to Gamma
        let transitionEvents = script.events.filter { $0.timestamp >= 1200 && $0.timestamp < 1230 }
        
        XCTAssertEqual(transitionEvents.count, 30) // 30 1-second events
        
        if let firstEvent = transitionEvents.first {
            XCTAssertEqual(firstEvent.waveform, .square)
            XCTAssertEqual(firstEvent.intensity, 0.5, accuracy: 0.01)
            XCTAssertEqual(firstEvent.color, .white)
        }
        
        // Verify frequency ramps from ~4.5Hz to 40Hz
        if transitionEvents.count >= 2 {
            let firstFreq = transitionEvents.first?.frequencyOverride ?? 0
            let lastFreq = transitionEvents.last?.frequencyOverride ?? 0
            XCTAssertLessThan(firstFreq, 10.0) // Should start low
            XCTAssertGreaterThan(lastFreq, 35.0) // Should end high
        }
    }
    
    func testGenerateDMNShutdownScript_Phase4Structure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Phase 4: THE VOID (1230-1740 seconds = 8.5 minutes = 510 seconds, reduced to allow for cooldown)
        // Single long event at 40Hz with maximum intensity
        let phase4Events = script.events.filter { $0.timestamp >= 1230 && $0.timestamp < 1740 }
        
        XCTAssertEqual(phase4Events.count, 1)
        
        if let event = phase4Events.first {
            XCTAssertEqual(event.timestamp, 1230.0, accuracy: 1.0) // After Phase 3 + Transition
            XCTAssertEqual(event.waveform, .square)
            XCTAssertEqual(event.intensity, 0.9, accuracy: 0.01) // Maximum brightness
            XCTAssertEqual(event.duration, 510.0, accuracy: 1.0) // 8.5 minutes (reduced from 9.5)
            XCTAssertEqual(event.color, .white)
            XCTAssertNotNil(event.frequencyOverride)
            XCTAssertEqual(event.frequencyOverride ?? 0, 40.0, accuracy: 0.01)
        }
    }
    
    func testGenerateDMNShutdownScript_Phase5CooldownStructure() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Phase 5: REINTEGRATION COOLDOWN (1740-1800 seconds = 1 minute)
        // Gradual ramp-down from high Gamma to Alpha for safe transition
        let phase5Events = script.events.filter { $0.timestamp >= 1740 }
        
        XCTAssertEqual(phase5Events.count, 60) // 60 1-second events for 1-minute cooldown
        
        if let firstEvent = phase5Events.first {
            XCTAssertEqual(firstEvent.waveform, .sine) // Sine wave for gentle reintegration
            XCTAssertEqual(firstEvent.color, .blue)
            XCTAssertEqual(firstEvent.duration, 1.0)
            // Should start near 40Hz
            let firstFreq = firstEvent.frequencyOverride ?? 0
            XCTAssertGreaterThan(firstFreq, 35.0)
            // Should start at high intensity
            XCTAssertGreaterThan(firstEvent.intensity, 0.8)
        }
        
        if let lastEvent = phase5Events.last {
            XCTAssertEqual(lastEvent.waveform, .sine)
            XCTAssertEqual(lastEvent.color, .blue)
            // Should end near 10Hz (Alpha)
            let lastFreq = lastEvent.frequencyOverride ?? 0
            XCTAssertLessThan(lastFreq, 15.0)
            XCTAssertGreaterThan(lastFreq, 8.0)
            // Should fade to lower intensity
            XCTAssertLessThan(lastEvent.intensity, 0.5)
        }
        
        // Verify frequency ramps down smoothly
        if phase5Events.count >= 2 {
            let firstFreq = phase5Events.first?.frequencyOverride ?? 0
            let lastFreq = phase5Events.last?.frequencyOverride ?? 0
            XCTAssertGreaterThan(firstFreq, lastFreq) // Should ramp down
        }
    }
    
    func testGenerateDMNShutdownScript_AllEventsHaveFrequencyOverride() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // All events should have frequencyOverride set (not relying on audio BPM)
        for event in script.events {
            XCTAssertNotNil(event.frequencyOverride, "Event at \(event.timestamp) missing frequency override")
        }
    }
    
    func testGenerateDMNShutdownScript_EventTimestampsContinuous() {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        // Events should have continuous timestamps (no gaps)
        for i in 0..<script.events.count - 1 {
            let currentEvent = script.events[i]
            let nextEvent = script.events[i + 1]
            
            let expectedNextTimestamp = currentEvent.timestamp + currentEvent.duration
            let gap = nextEvent.timestamp - expectedNextTimestamp
            
            // Allow small floating point error (< 0.01 seconds)
            XCTAssertLessThanOrEqual(abs(gap), 0.01, "Gap detected between event \(i) and \(i+1)")
        }
    }
    
    func testGenerateDMNShutdownVibrationScript_StructureAndDuration() throws {
        let script = try EntrainmentEngine.generateDMNShutdownVibrationScript(intensity: 0.7)
        
        // Verify script properties
        XCTAssertEqual(script.mode, .dmnShutdown)
        XCTAssertEqual(script.targetFrequency, 40.0) // Peak frequency
        
        // Note: Phase 4 now has minimal background vibration (0.5 Hz) for user comfort
        // Total duration covers all 5 phases:
        // Phase 1 (180s) + Phase 2 (540s) + Phase 3 (480s) + Phase 4 (510s) + Phase 5 (60s) = 1770s (~30 minutes)
        if let lastEvent = script.events.last {
            let totalDuration = lastEvent.timestamp + lastEvent.duration
            XCTAssertEqual(totalDuration, 1770.0, accuracy: 10.0)
        }
        
        // Verify events exist
        XCTAssertGreaterThan(script.events.count, 0)
    }
    
    func testGenerateDMNShutdownVibrationScript_Phase1HeartbeatSync() throws {
        let script = try EntrainmentEngine.generateDMNShutdownVibrationScript(intensity: 0.7)
        
        // Phase 1: Synchronized with heartbeat (60 BPM = 1 Hz)
        // Events should have constant duration at 1 second
        let phase1Events = script.events.filter { $0.timestamp < 180 }
        
        XCTAssertGreaterThan(phase1Events.count, 0)
        
        // Events should have ~1s duration (1 Hz = 60 BPM)
        if let firstEvent = phase1Events.first {
            let period = firstEvent.duration
            XCTAssertEqual(period, 1.0, accuracy: 0.01) // 1 Hz heartbeat
            XCTAssertEqual(firstEvent.waveform, .sine)
        }
        
        // All Phase 1 events should have same duration
        let uniqueDurations = Set(phase1Events.map { $0.duration })
        XCTAssertEqual(uniqueDurations.count, 1) // All should be the same
    }
    
    func testGenerateDMNShutdownVibrationScript_IntensityRespected() throws {
        let lowIntensityScript = try EntrainmentEngine.generateDMNShutdownVibrationScript(intensity: 0.3)
        let highIntensityScript = try EntrainmentEngine.generateDMNShutdownVibrationScript(intensity: 0.9)
        
        // Events should respect the intensity parameter (within reasonable bounds)
        if let lowEvent = lowIntensityScript.events.first,
           let highEvent = highIntensityScript.events.first {
            XCTAssertLessThan(lowEvent.intensity, highEvent.intensity)
        }
    }
}

