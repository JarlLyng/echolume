//
//  OSCAction.swift
//  echolume
//
//  Maps the fixed /echolume/... OSC namespace onto app actions. Pure (no
//  AppModel) so the routing is unit-testable; AppModel applies the result.
//

import Foundation

enum OSCAction: Equatable {
    case abstraction(Float)
    case energyBias(Float)
    case motion(Float)
    case noise(Float)
    case glitch(Float)
    case theme(Int)
    case scene(Int)
    case shape(Int)
    case randomize
    case panic
    case nextTheme
    case prevTheme
    case tapTempo
    case presetSlot(Int)
    case presetName(String)

    init?(message: OSCMessage) {
        switch message.address {
        case "/echolume/knob/abstraction": guard let v = message.float01 else { return nil }; self = .abstraction(v)
        case "/echolume/knob/energybias":  guard let v = message.float01 else { return nil }; self = .energyBias(v)
        case "/echolume/knob/motion":      guard let v = message.float01 else { return nil }; self = .motion(v)
        case "/echolume/knob/noise":       guard let v = message.float01 else { return nil }; self = .noise(v)
        case "/echolume/knob/glitch":      guard let v = message.float01 else { return nil }; self = .glitch(v)
        case "/echolume/theme":            guard let i = message.int else { return nil }; self = .theme(i)
        case "/echolume/scene":            guard let i = message.int else { return nil }; self = .scene(i)
        case "/echolume/shape":            guard let i = message.int else { return nil }; self = .shape(i)
        case "/echolume/randomize":        self = .randomize
        case "/echolume/panic":            self = .panic
        case "/echolume/nexttheme":        self = .nextTheme
        case "/echolume/prevtheme":        self = .prevTheme
        case "/echolume/tempo/tap":        self = .tapTempo
        case "/echolume/preset":
            // String arg → recall by name; numeric arg → 1-based slot.
            if let s = message.string { self = .presetName(s) } else if let i = message.int { self = .presetSlot(i) } else { return nil }
        default:
            return nil
        }
    }
}

private extension OSCMessage {
    /// First argument as a 0...1 float (accepts float or int).
    var float01: Float? {
        guard let raw = floatValue else { return nil }
        return max(0, min(1, raw))
    }

    var floatValue: Float? {
        switch arguments.first {
        case .float(let f): return f
        case .int(let i): return Float(i)
        default: return nil
        }
    }

    var int: Int? {
        switch arguments.first {
        case .int(let i): return Int(i)
        case .float(let f): return Int(f.rounded())
        default: return nil
        }
    }

    var string: String? {
        if case .string(let s) = arguments.first { return s }
        return nil
    }
}
