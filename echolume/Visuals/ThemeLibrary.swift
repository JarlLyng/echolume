//
//  ThemeLibrary.swift
//  echolume
//

import simd

/// V1 themes from README: Summer, Winter, Dark Ambient, Techno Club, Neon Lines, Monochrome.
enum ThemeLibrary {
    static let themes: [Theme] = [
        Theme(id: 0, name: "Summer", palette: [
            SIMD4<Float>(1.0, 0.95, 0.7, 1), SIMD4<Float>(1.0, 0.6, 0.2, 1),
            SIMD4<Float>(0.95, 0.4, 0.1, 1), SIMD4<Float>(0.3, 0.7, 0.5, 1),
        ], baseSpeed: 0.2, rotationSpeed: 0.1, defaultShapeStyle: .blobs),
        Theme(id: 1, name: "Winter", palette: [
            SIMD4<Float>(0.9, 0.95, 1.0, 1), SIMD4<Float>(0.6, 0.8, 1.0, 1),
            SIMD4<Float>(0.3, 0.5, 0.8, 1), SIMD4<Float>(0.5, 0.7, 0.95, 1),
        ], baseSpeed: 0.35, rotationSpeed: 0.25, defaultShapeStyle: .blobs),
        Theme(id: 2, name: "Dark Ambient", palette: [
            SIMD4<Float>(0.15, 0.12, 0.2, 1), SIMD4<Float>(0.25, 0.2, 0.35, 1),
            SIMD4<Float>(0.1, 0.15, 0.25, 1), SIMD4<Float>(0.2, 0.18, 0.3, 1),
        ], baseSpeed: 0.15, rotationSpeed: 0.08, defaultShapeStyle: .blobs),
        Theme(id: 3, name: "Techno Club", palette: [
            SIMD4<Float>(0, 0, 0, 1), SIMD4<Float>(1, 0, 0.5, 1),
            SIMD4<Float>(0, 1, 1, 1), SIMD4<Float>(1, 1, 1, 1), SIMD4<Float>(0.5, 0, 1, 1),
        ], baseSpeed: 0.6, rotationSpeed: 0.5, defaultShapeStyle: .particles),
        Theme(id: 4, name: "Neon Lines", palette: [
            SIMD4<Float>(0, 1, 0.5, 1), SIMD4<Float>(0, 0.8, 1, 1),
            SIMD4<Float>(0.2, 0.2, 0.3, 1), SIMD4<Float>(0.5, 1, 0.8, 1),
        ], baseSpeed: 0.45, rotationSpeed: 0.3, defaultShapeStyle: .lines),
        Theme(id: 5, name: "Monochrome", palette: [
            SIMD4<Float>(0.1, 0.1, 0.12, 1), SIMD4<Float>(0.5, 0.5, 0.55, 1),
            SIMD4<Float>(0.9, 0.9, 0.95, 1),
        ], baseSpeed: 0.25, rotationSpeed: 0.15, defaultShapeStyle: .circles),
        Theme(id: 6, name: "Sunset", palette: [
            SIMD4<Float>(1.0, 0.85, 0.4, 1), SIMD4<Float>(1.0, 0.5, 0.15, 1),
            SIMD4<Float>(0.85, 0.2, 0.15, 1), SIMD4<Float>(0.95, 0.35, 0.5, 1),
        ], baseSpeed: 0.3, rotationSpeed: 0.15, defaultShapeStyle: .blobs),
        Theme(id: 7, name: "Nebula", palette: [
            SIMD4<Float>(0.85, 0.25, 0.95, 1), SIMD4<Float>(0.5, 0.2, 0.85, 1),
            SIMD4<Float>(0.12, 0.08, 0.3, 1), SIMD4<Float>(0.25, 0.8, 0.95, 1),
        ], baseSpeed: 0.3, rotationSpeed: 0.2, defaultShapeStyle: .blobs),
        Theme(id: 8, name: "Vapor", palette: [
            SIMD4<Float>(1.0, 0.7, 0.9, 1), SIMD4<Float>(0.7, 0.95, 0.98, 1),
            SIMD4<Float>(0.82, 0.78, 1.0, 1), SIMD4<Float>(1.0, 0.97, 0.82, 1),
        ], baseSpeed: 0.3, rotationSpeed: 0.2, defaultShapeStyle: .blobs),
        Theme(id: 9, name: "Acid", palette: [
            SIMD4<Float>(0.8, 1.0, 0.0, 1), SIMD4<Float>(0.5, 1.0, 0.1, 1),
            SIMD4<Float>(0.05, 0.08, 0.0, 1), SIMD4<Float>(0.9, 1.0, 0.6, 1),
        ], baseSpeed: 0.5, rotationSpeed: 0.35, defaultShapeStyle: .lines),
    ]

    static func theme(byIndex index: Int) -> Theme {
        themes[Swift.max(0, Swift.min(index, themes.count - 1))]
    }
}
