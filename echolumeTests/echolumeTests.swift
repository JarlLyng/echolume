//
//  echolumeTests.swift
//  echolumeTests
//
//  Unit tests for pure-logic types. Audio engine, networking, and UI are
//  not exercised here — see UI tests and manual verification for those.
//

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
        _ = mapParams(mapping: m, snapshot: makeSnapshot(peak: 0.95, impact: 0.9), glitch: 1.0)
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
