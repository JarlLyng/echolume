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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .radial: return "Radial"
        case .flow: return "Flow"
        case .grid: return "Grid"
        }
    }

    /// Index for Metal shader (must match shader switch).
    var shaderIndex: Int {
        switch self {
        case .radial: return 0
        case .flow: return 1
        case .grid: return 2
        }
    }

    static func from(shaderIndex: Int) -> SceneType {
        switch shaderIndex {
        case 0: return .radial
        case 1: return .flow
        case 2: return .grid
        default: return .radial
        }
    }
}
