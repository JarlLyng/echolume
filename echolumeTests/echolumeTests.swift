//
//  echolumeTests.swift
//  echolumeTests
//
//  Unit tests for pure-logic types. Audio engine, networking, and UI are
//  not exercised here — see UI tests and manual verification for those.
//

import Foundation
import Testing
import simd
@testable import echolume

// MARK: - TwitchChatManager.parseCommand

struct TwitchCommandParsingTests {

    // MARK: theme / scene / shape

    @Test func theme_withName_returnsTheme() {
        let command = TwitchChatManager.parseCommand("!theme aurora")
        guard case .theme(let name) = command else {
            Issue.record("Expected .theme, got \(String(describing: command))")
            return
        }
        #expect(name == "aurora")
    }

    @Test func theme_withoutArg_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!theme") == nil)
        #expect(TwitchChatManager.parseCommand("!theme   ") == nil)
    }

    @Test func scene_withName_returnsScene() {
        let command = TwitchChatManager.parseCommand("!scene radial")
        guard case .scene(let name) = command else {
            Issue.record("Expected .scene")
            return
        }
        #expect(name == "radial")
    }

    @Test func shape_withName_returnsShape() {
        let command = TwitchChatManager.parseCommand("!shape dots")
        guard case .shape(let name) = command else {
            Issue.record("Expected .shape")
            return
        }
        #expect(name == "dots")
    }

    // MARK: trigger commands

    @Test func randomize_returnsRandomize() {
        guard case .randomize = TwitchChatManager.parseCommand("!randomize") else {
            Issue.record("Expected .randomize")
            return
        }
    }

    @Test func glitch_returnsGlitch() {
        guard case .glitch = TwitchChatManager.parseCommand("!glitch") else {
            Issue.record("Expected .glitch")
            return
        }
    }

    // MARK: abstract (numeric arg)

    @Test func abstract_withValidNumber_returnsAbstract() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract 75") else {
            Issue.record("Expected .abstract")
            return
        }
        #expect(value == 75)
    }

    @Test func abstract_clampsAboveRange() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract 9999") else {
            Issue.record("Expected .abstract clamped")
            return
        }
        #expect(value == 100)
    }

    @Test func abstract_clampsBelowRange() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract -50") else {
            Issue.record("Expected .abstract clamped")
            return
        }
        #expect(value == 0)
    }

    @Test func abstract_withInvalidArg_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!abstract abc") == nil)
        #expect(TwitchChatManager.parseCommand("!abstract") == nil)
    }

    // MARK: preset (name arg)

    @Test func preset_withName_returnsPreset() {
        guard case .preset(let name) = TwitchChatManager.parseCommand("!preset chill vibes") else {
            Issue.record("Expected .preset")
            return
        }
        #expect(name == "chill vibes")
    }

    @Test func preset_withoutArg_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!preset") == nil)
        #expect(TwitchChatManager.parseCommand("!preset   ") == nil)
    }

    // MARK: rejection

    @Test func messageWithoutBang_returnsNil() {
        #expect(TwitchChatManager.parseCommand("theme aurora") == nil)
        #expect(TwitchChatManager.parseCommand("hello") == nil)
        #expect(TwitchChatManager.parseCommand("") == nil)
    }

    @Test func unknownCommand_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!ban someone") == nil)
        #expect(TwitchChatManager.parseCommand("!hello") == nil)
    }

    // MARK: case + whitespace

    @Test func commandIsCaseInsensitive() {
        guard case .theme(let name) = TwitchChatManager.parseCommand("!THEME aurora") else {
            Issue.record("Expected .theme")
            return
        }
        #expect(name == "aurora")
    }

    @Test func leadingWhitespaceIsTolerated() {
        guard case .randomize = TwitchChatManager.parseCommand("  !randomize") else {
            Issue.record("Expected .randomize")
            return
        }
    }

    @Test func trailingWhitespaceIsStripped() {
        guard case .theme(let name) = TwitchChatManager.parseCommand("!theme aurora   ") else {
            Issue.record("Expected .theme")
            return
        }
        #expect(name == "aurora")
    }
}

// MARK: - TwitchConnectionStatus equality

struct TwitchConnectionStatusTests {

    @Test func errorStatusEqualityRespectsMessage() {
        #expect(TwitchConnectionStatus.error("a") == TwitchConnectionStatus.error("a"))
        #expect(TwitchConnectionStatus.error("a") != TwitchConnectionStatus.error("b"))
    }

    @Test func differentCasesAreNotEqual() {
        #expect(TwitchConnectionStatus.connected != TwitchConnectionStatus.disconnected)
        #expect(TwitchConnectionStatus.connecting != TwitchConnectionStatus.connected)
    }
}

// MARK: - AudioManagerSnapshot

struct AudioManagerSnapshotTests {

    @Test func defaultsAreZeroAndDisabled() {
        let snap = AudioManagerSnapshot()
        #expect(snap.engineRunning == false)
        #expect(snap.lastError == nil)
        #expect(snap.formatSampleRate == 0)
        #expect(snap.formatChannelCount == 0)
        #expect(snap.rms == 0)
        #expect(snap.peak == 0)
        #expect(snap.frameCount == 0)
        #expect(snap.channelCount == 0)
    }

    @Test func equalityComparesAllFields() {
        var a = AudioManagerSnapshot()
        var b = AudioManagerSnapshot()
        #expect(a == b)
        a.rms = 0.5
        #expect(a != b)
        b.rms = 0.5
        #expect(a == b)
        a.lastError = "oops"
        #expect(a != b)
    }
}

// MARK: - ParamMapping

struct ParamMappingTests {

    private func makeSnapshot(level: Float = 0, peak: Float = 0, low: Float = 0, mid: Float = 0, high: Float = 0, impact: Float = 0) -> AnalyzerSnapshot {
        AnalyzerSnapshot(level: level, peak: peak, low: low, mid: mid, high: high, impact: impact)
    }

    private func mapParams(
        mapping: ParamMapping,
        abstraction: Float = 0.5,
        energyBias: Float = 0.5,
        motion: Float = 0.5,
        noise: Float = 0.5,
        glitch: Float = 0.2,
        snapshot: AnalyzerSnapshot? = nil
    ) -> VisualParams {
        let theme = ThemeLibrary.themes[0]
        return mapping.map(
            snapshot: snapshot ?? makeSnapshot(),
            abstraction: abstraction,
            energyBias: energyBias,
            theme: theme,
            seed: 0,
            shapeStyleIndex: 0,
            sceneTypeIndex: 0,
            time: 0,
            resolution: SIMD2<Float>(1280, 720),
            motion: motion,
            noise: noise,
            glitch: glitch
        )
    }

    @Test func abstractionClampsToZeroOne() {
        let m = ParamMapping()
        let high = mapParams(mapping: m, abstraction: 5.0)
        #expect(high.abstraction == 1.0)
        let low = mapParams(mapping: m, abstraction: -1.0)
        #expect(low.abstraction == 0.0)
    }

    @Test func motionNoiseGlitchClamp() {
        let m = ParamMapping()
        let p = mapParams(mapping: m, motion: 1.5, noise: -0.3, glitch: 99)
        #expect(p.motion == 1.0)
        #expect(p.noise == 0.0)
        #expect(p.glitch == 1.0)
    }

    @Test func sceneTypeIndexClampedToValidRange() {
        let m = ParamMapping()
        let theme = ThemeLibrary.themes[0]
        let oversized = m.map(
            snapshot: makeSnapshot(),
            abstraction: 0.5,
            energyBias: 0.5,
            theme: theme,
            seed: 0,
            shapeStyleIndex: 0,
            sceneTypeIndex: 999,
            time: 0,
            resolution: SIMD2<Float>(800, 600),
            motion: 0.5,
            noise: 0.5,
            glitch: 0.2
        )
        // ParamMapping clamps to 0...2 (current scene types).
        #expect(oversized.sceneType >= 0)
        #expect(oversized.sceneType <= 2)
    }

    @Test func impulseFiresOnRisingPeakAboveThreshold() {
        let m = ParamMapping()
        // First call: peak above threshold, should set impulse high.
        let firstHit = mapParams(mapping: m, snapshot: makeSnapshot(peak: 0.9))
        #expect(firstHit.impulse > 0.5)
    }

    @Test func impulseDecaysOnSubsequentLowPeaks() {
        let m = ParamMapping()
        // Trigger impulse with a peak hit.
        _ = mapParams(mapping: m, snapshot: makeSnapshot(peak: 0.9))
        // Repeated calls with low peak should decay impulse toward zero.
        var lastImpulse: Float = 1.0
        for _ in 0..<10 {
            let p = mapParams(mapping: m, snapshot: makeSnapshot(peak: 0.1))
            #expect(p.impulse <= lastImpulse)
            lastImpulse = p.impulse
        }
        #expect(lastImpulse < 0.2)
    }

    @Test func resetTransientsClearsImpulseAndGlitchPhase() {
        let m = ParamMapping()
        // Build up some state.
        _ = mapParams(mapping: m, glitch: 1.0, snapshot: makeSnapshot(peak: 0.95, impact: 0.9))
        m.resetTransients()
        // After reset, a quiet snapshot should produce zero impulse.
        let after = mapParams(mapping: m, snapshot: makeSnapshot(peak: 0.0))
        #expect(after.impulse == 0.0)
    }

    @Test func paletteFallbackForSparseTheme() {
        let mapping = ParamMapping()
        let sparseTheme = Theme(
            id: 99,
            name: "Sparse",
            palette: [SIMD4<Float>(1, 0, 0, 1)],   // Only one color
            defaultShapeStyle: .blobs
        )
        let p = mapping.map(
            snapshot: makeSnapshot(),
            abstraction: 0.5,
            energyBias: 0.5,
            theme: sparseTheme,
            seed: 0,
            shapeStyleIndex: 0,
            sceneTypeIndex: 0,
            time: 0,
            resolution: SIMD2<Float>(1280, 720),
            motion: 0.5,
            noise: 0.5,
            glitch: 0.2
        )
        // All five palette slots should be valid (filled with fallback).
        #expect(p.palette.0 == p.palette.4 || p.palette.4.w == 1)
    }
}

// MARK: - ShaderUniforms layout (regression guard for Swift/Metal drift)

struct ShaderUniformsLayoutTests {

    /// If this test fails, the Swift `ShaderUniforms` struct no longer matches
    /// the Metal `Uniforms` struct in Shaders.metal. Update both in lockstep.
    /// Expected stride: 224 bytes (computed from Metal layout rules).
    @Test func strideMatchesMetalLayout() {
        let stride = MemoryLayout<ShaderUniforms>.stride
        #expect(stride == 224, "ShaderUniforms stride changed: \(stride). Update Metal Uniforms struct to match.")
    }

    @Test func alignmentMatchesFloat4() {
        // Metal float4 requires 16-byte alignment for the containing struct.
        #expect(MemoryLayout<ShaderUniforms>.alignment == 16)
    }

    @Test func strideIsMultipleOfFloat4Alignment() {
        // Metal expects struct stride to be a multiple of its alignment.
        #expect(MemoryLayout<ShaderUniforms>.stride % 16 == 0)
    }
}

// MARK: - VisualPreset Codable

@MainActor
struct VisualPresetCodableTests {

    @Test func jsonRoundTripPreservesAllFields() throws {
        let original = VisualPreset(
            name: "Techno Peak",
            themeIndex: 3,
            shapeStyle: "lines",
            scene: "grid",
            abstraction: 0.7,
            energyBias: 0.4,
            motion: 0.9,
            noise: 0.1,
            glitch: 0.6
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VisualPreset.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - MidiMessage parsing

@MainActor
struct MidiMessageTests {

    @Test func parsesControlChange() {
        // 0xB0 = CC on channel 0
        #expect(MidiMessage.parse(status: 0xB0, 21, 64) == .controlChange(channel: 0, cc: 21, value: 64))
    }

    @Test func parsesControlChangeChannel() {
        // 0xB5 = CC on channel 5
        #expect(MidiMessage.parse(status: 0xB5, 7, 127) == .controlChange(channel: 5, cc: 7, value: 127))
    }

    @Test func parsesNoteOn() {
        // 0x90 = note-on channel 0
        #expect(MidiMessage.parse(status: 0x90, 60, 100) == .noteOn(channel: 0, note: 60, velocity: 100))
    }

    @Test func noteOnZeroVelocityIsNil() {
        // Note-on velocity 0 is a note-off by convention.
        #expect(MidiMessage.parse(status: 0x90, 60, 0) == nil)
    }

    @Test func noteOffIsNil() {
        #expect(MidiMessage.parse(status: 0x80, 60, 64) == nil)
    }

    @Test func unknownStatusIsNil() {
        #expect(MidiMessage.parse(status: 0xF0, 0, 0) == nil)   // sysex
        #expect(MidiMessage.parse(status: 0xE0, 0, 0) == nil)   // pitch bend
    }

    @Test func midiValueScales() {
        #expect(midiValueToUnit(0) == 0.0)
        #expect(midiValueToUnit(127) == 1.0)
        #expect(abs(midiValueToUnit(64) - 0.5039) < 0.001)
    }
}

// MARK: - BeatTracker

@MainActor
struct BeatTrackerTests {

    /// Feed a synthetic onset impulse train at `bpm` for `seconds` and return
    /// the final detected output.
    private func runTrain(bpm: Float, seconds: Double, dt: Double = 0.0427) -> BeatTracker.Output {
        let tracker = BeatTracker()
        let beatInterval = 60.0 / Double(bpm)
        var now = 0.0
        var nextBeat = 0.0
        var last = BeatTracker.Output(bpm: 0, beatPhase: 0, confidence: 0)
        while now < seconds {
            // Impulse on frames at/just past a beat boundary; quiet otherwise.
            var onset: Float = 0
            if now >= nextBeat {
                onset = 1.0
                nextBeat += beatInterval
            }
            last = tracker.ingest(onsetStrength: onset, now: now)
            now += dt
        }
        return last
    }

    @Test func detects120BPM() {
        let out = runTrain(bpm: 120, seconds: 10)
        #expect(abs(out.bpm - 120) <= 2, "expected ~120, got \(out.bpm)")
    }

    @Test func detects90BPM() {
        let out = runTrain(bpm: 90, seconds: 10)
        #expect(abs(out.bpm - 90) <= 2, "expected ~90, got \(out.bpm)")
    }

    @Test func detects140BPM() {
        let out = runTrain(bpm: 140, seconds: 10)
        #expect(abs(out.bpm - 140) <= 2, "expected ~140, got \(out.bpm)")
    }

    @Test func phaseStaysInUnitRange() {
        let tracker = BeatTracker()
        tracker.setManualBPM(120)
        var now = 0.0
        for _ in 0 ..< 200 {
            let out = tracker.ingest(onsetStrength: 0, now: now)
            #expect(out.beatPhase >= 0 && out.beatPhase < 1, "phase out of range: \(out.beatPhase)")
            now += 0.0427
        }
    }

    @Test func tapTempoSetsBPM() {
        let tracker = BeatTracker()
        // Four taps 0.5s apart → 120 BPM.
        for i in 0 ..< 4 { tracker.tap(now: Double(i) * 0.5) }
        let out = tracker.ingest(onsetStrength: 0, now: 2.0)
        #expect(abs(out.bpm - 120) <= 1, "expected 120 from taps, got \(out.bpm)")
    }

    @Test func tapResetsPhaseToZero() {
        let tracker = BeatTracker()
        tracker.setManualBPM(120)
        _ = tracker.ingest(onsetStrength: 0, now: 0.3)   // advance phase
        tracker.tap(now: 0.31)
        let out = tracker.ingest(onsetStrength: 0, now: 0.31)   // minimal advance after reset
        // Without the reset, ~0.3s at 120 BPM would leave phase ≈ 0.6; the reset
        // brings it back near 0 (a tiny advance from the dt floor remains).
        #expect(out.beatPhase < 0.05, "phase should reset on tap, got \(out.beatPhase)")
    }

    @Test func manualBPMOverridesDetection() {
        let tracker = BeatTracker()
        tracker.setManualBPM(128)
        var now = 0.0
        var out = BeatTracker.Output(bpm: 0, beatPhase: 0, confidence: 0)
        for _ in 0 ..< 50 { out = tracker.ingest(onsetStrength: 0, now: now); now += 0.0427 }
        #expect(out.bpm == 128)
    }
}

// MARK: - MidiMappingStore

@MainActor
struct MidiMappingStoreTests {

    private func makeStore() -> MidiMappingStore {
        let suite = "echolume-miditests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return MidiMappingStore(defaults: defaults)
    }

    @Test func bindCCToKnobAndLookUp() {
        let store = makeStore()
        store.bind(target: .motion, kind: .cc, number: 21)
        #expect(store.cc(for: .motion) == 21)
        #expect(store.target(forCC: 21) == .motion)
    }

    @Test func rebindingTargetReplacesPrevious() {
        let store = makeStore()
        store.bind(target: .motion, kind: .cc, number: 21)
        store.bind(target: .motion, kind: .cc, number: 22)
        #expect(store.cc(for: .motion) == 22)
        #expect(store.target(forCC: 21) == nil)   // old CC freed
        #expect(store.bindings.count == 1)
    }

    @Test func bindingSameNumberStealsItFromOldTarget() {
        let store = makeStore()
        store.bind(target: .motion, kind: .cc, number: 21)
        store.bind(target: .noise, kind: .cc, number: 21)
        #expect(store.target(forCC: 21) == .noise)
        #expect(store.cc(for: .motion) == nil)
        #expect(store.bindings.count == 1)
    }

    @Test func bindNoteToAction() {
        let store = makeStore()
        store.bind(target: .randomize, kind: .note, number: 36)
        #expect(store.note(for: .randomize) == 36)
        #expect(store.target(forNote: 36) == .randomize)
    }

    @Test func removeBinding() {
        let store = makeStore()
        store.bind(target: .glitch, kind: .cc, number: 50)
        store.removeBinding(for: .glitch)
        #expect(store.cc(for: .glitch) == nil)
        #expect(store.bindings.isEmpty)
    }

    @Test func bindingsPersistAcrossInstances() {
        let suite = "echolume-miditests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let first = MidiMappingStore(defaults: defaults)
        first.bind(target: .abstraction, kind: .cc, number: 1)
        first.bind(target: .panic, kind: .note, number: 48)

        let reopened = MidiMappingStore(defaults: defaults)
        #expect(reopened.cc(for: .abstraction) == 1)
        #expect(reopened.note(for: .panic) == 48)
    }
}

// MARK: - PresetStore

@MainActor
struct PresetStoreTests {

    /// A store backed by a unique throwaway directory so tests never touch
    /// the real Application Support location.
    private func makeStore() -> PresetStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("echolume-tests-\(UUID().uuidString)", isDirectory: true)
        return PresetStore(directory: dir)
    }

    private func sample(_ name: String) -> VisualPreset {
        VisualPreset(
            name: name,
            themeIndex: 1,
            shapeStyle: "blobs",
            scene: "radial",
            abstraction: 0.5,
            energyBias: 0.5,
            motion: 0.5,
            noise: 0.5,
            glitch: 0.2
        )
    }

    @Test func addStoresAndTrimsName() throws {
        let store = makeStore()
        let stored = try store.add(sample("  Chill  "))
        #expect(stored.name == "Chill")
        #expect(store.presets.count == 1)
        #expect(store.contains(name: "chill"))
    }

    @Test func emptyNameThrows() {
        let store = makeStore()
        #expect(throws: PresetError.emptyName) {
            try store.add(sample("   "))
        }
        #expect(store.presets.isEmpty)
    }

    @Test func duplicateNameIsRejectedCaseInsensitively() throws {
        let store = makeStore()
        try store.add(sample("Aurora"))
        #expect(throws: PresetError.duplicateName("aurora")) {
            try store.add(sample("aurora"))
        }
        #expect(store.presets.count == 1)
    }

    @Test func deleteRemovesPreset() throws {
        let store = makeStore()
        let p = try store.add(sample("Gone"))
        store.delete(id: p.id)
        #expect(store.presets.isEmpty)
    }

    @Test func slotLookupIsOneBased() throws {
        let store = makeStore()
        let first = try store.add(sample("One"))
        let second = try store.add(sample("Two"))
        #expect(store.preset(atSlot: 1) == first)
        #expect(store.preset(atSlot: 2) == second)
        #expect(store.preset(atSlot: 3) == nil)
        #expect(store.preset(atSlot: 0) == nil)
    }

    @Test func namedLookupIsCaseInsensitive() throws {
        let store = makeStore()
        let p = try store.add(sample("Deep Space"))
        #expect(store.preset(named: "deep space") == p)
        #expect(store.preset(named: "  DEEP SPACE  ") == p)
        #expect(store.preset(named: "nope") == nil)
    }

    @Test func presetsPersistAcrossStoreInstances() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("echolume-tests-\(UUID().uuidString)", isDirectory: true)
        let first = PresetStore(directory: dir)
        try first.add(sample("Persisted"))

        let reopened = PresetStore(directory: dir)
        #expect(reopened.presets.count == 1)
        #expect(reopened.contains(name: "Persisted"))
    }
}
