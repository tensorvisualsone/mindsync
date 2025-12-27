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
    
    func testGenerateLightScript_AlphaMode_SineWaveform() {
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
        
        // Alpha mode should use sine waveform
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
}

