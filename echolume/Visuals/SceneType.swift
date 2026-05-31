//
//  SceneType.swift
//  echolume
//
//  Scene defines geometry + motion logic. Raw value matches Metal shader switch.
//

import Foundation

enum SceneType: String, CaseIterable, Identifiable {
    case radial
    case flow
    case grid
    case spiral
    case tunnel
    case kaleidoscope
    case plasma

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .radial: return "Radial"
        case .flow: return "Flow"
        case .grid: return "Grid"
        case .spiral: return "Spiral"
        case .tunnel: return "Tunnel"
        case .kaleidoscope: return "Kaleidoscope"
        case .plasma: return "Plasma"
        }
    }

    /// Index for Metal shader (must match shader switch).
    var shaderIndex: Int {
        switch self {
        case .radial: return 0
        case .flow: return 1
        case .grid: return 2
        case .spiral: return 3
        case .tunnel: return 4
        case .kaleidoscope: return 5
        case .plasma: return 6
        }
    }

    static func from(shaderIndex: Int) -> SceneType {
        allCases.first { $0.shaderIndex == shaderIndex } ?? .radial
    }
}
