//
//  MidiBinding.swift
//  echolume
//
//  Model for MIDI Learn bindings. Knob targets bind to CC numbers; action
//  targets bind to note numbers. Mappings are global (not per-controller).
//

import Foundation

/// A control that a MIDI message can drive. The five knobs bind to CC; the
/// action triggers bind to notes.
enum MidiTarget: String, Codable, CaseIterable, Equatable {
    case abstraction
    case energyBias
    case motion
    case noise
    case glitch
    case randomize
    case panic
    case nextTheme
    case previousTheme
    case tapTempo

    /// Knob targets bind to CC messages; the rest are note-triggered actions.
    var isKnob: Bool {
        switch self {
        case .abstraction, .energyBias, .motion, .noise, .glitch:
            return true
        case .randomize, .panic, .nextTheme, .previousTheme, .tapTempo:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .abstraction: return "Abstraction"
        case .energyBias: return "Energy Bias"
        case .motion: return "Motion"
        case .noise: return "Noise"
        case .glitch: return "Glitch"
        case .randomize: return "Randomize"
        case .panic: return "Panic Reset"
        case .nextTheme: return "Next Theme"
        case .previousTheme: return "Previous Theme"
        case .tapTempo: return "Tap Tempo"
        }
    }

    /// The note-triggered actions, in display order.
    static var actions: [MidiTarget] { [.randomize, .panic, .nextTheme, .previousTheme, .tapTempo] }
}

struct MidiBinding: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case cc, note }

    var kind: Kind
    var number: UInt8   // CC number or note number (0...127)
    var target: MidiTarget

    var id: String { "\(kind.rawValue)-\(number)-\(target.rawValue)" }
}
