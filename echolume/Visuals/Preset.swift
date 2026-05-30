//
//  Preset.swift
//  echolume
//
//  A named snapshot of the full visual state (theme, shape, scene, and the
//  5 performance knobs) so a dialed-in look can be recalled instantly during
//  a live set. Seed is intentionally excluded — it is never persisted and is
//  regenerated on Randomize/Panic, so applying a preset leaves it untouched.
//

import Foundation

// A plain data model. Under the project's `-default-isolation=MainActor`
// build setting it is MainActor-isolated, which is fine: PresetStore encodes
// and decodes it on the main actor. Tests that exercise its Codable/Equatable
// conformance run in a @MainActor context for the same reason.
struct VisualPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var themeIndex: Int
    var shapeStyle: String   // VisualShapeStyle.rawValue
    var scene: String        // SceneType.rawValue
    var abstraction: Float
    var energyBias: Float
    var motion: Float
    var noise: Float
    var glitch: Float

    init(
        id: UUID = UUID(),
        name: String,
        themeIndex: Int,
        shapeStyle: String,
        scene: String,
        abstraction: Float,
        energyBias: Float,
        motion: Float,
        noise: Float,
        glitch: Float
    ) {
        self.id = id
        self.name = name
        self.themeIndex = themeIndex
        self.shapeStyle = shapeStyle
        self.scene = scene
        self.abstraction = abstraction
        self.energyBias = energyBias
        self.motion = motion
        self.noise = noise
        self.glitch = glitch
    }
}
