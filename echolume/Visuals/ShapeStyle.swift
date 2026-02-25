//
//  ShapeStyle.swift
//  echolume
//
//  Geometry style for visuals. Raw value matches Metal shader switch.
//

import Foundation

enum VisualShapeStyle: String, CaseIterable, Identifiable {
    case blobs
    case circles
    case lines
    case grid
    case particles

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blobs: return "Blobs"
        case .circles: return "Circles"
        case .lines: return "Lines"
        case .grid: return "Grid"
        case .particles: return "Particles"
        }
    }

    /// Index for Metal shader (must match shader switch).
    var shaderIndex: Int {
        switch self {
        case .blobs: return 0
        case .circles: return 1
        case .lines: return 2
        case .grid: return 3
        case .particles: return 4
        }
    }

    static func from(shaderIndex: Int) -> VisualShapeStyle {
        switch shaderIndex {
        case 0: return .blobs
        case 1: return .circles
        case 2: return .lines
        case 3: return .grid
        case 4: return .particles
        default: return .blobs
        }
    }
}
