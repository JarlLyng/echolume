//
//  MidiMessage.swift
//  echolume
//
//  Pure parsing of MIDI 1.0 channel-voice bytes into the two message types we
//  care about (CC + note-on). Kept free of CoreMIDI so it can be unit-tested
//  without hardware — MidiManager funnels raw bytes here.
//

import Foundation

enum MidiMessage: Equatable {
    case controlChange(channel: UInt8, cc: UInt8, value: UInt8)
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)

    /// Parse a 3-byte MIDI 1.0 channel-voice message. Returns nil for messages
    /// we don't act on (note-off, note-on with velocity 0, and everything else).
    static func parse(status: UInt8, _ data1: UInt8, _ data2: UInt8) -> MidiMessage? {
        let type = status & 0xF0
        let channel = status & 0x0F
        switch type {
        case 0xB0:
            return .controlChange(channel: channel, cc: data1 & 0x7F, value: data2 & 0x7F)
        case 0x90:
            let velocity = data2 & 0x7F
            // Note-on with velocity 0 is conventionally a note-off — ignore.
            return velocity > 0 ? .noteOn(channel: channel, note: data1 & 0x7F, velocity: velocity) : nil
        default:
            return nil
        }
    }
}

/// Map a 7-bit MIDI value (0...127) to a normalized 0...1 knob value.
func midiValueToUnit(_ value: UInt8) -> Float {
    Float(min(value, 127)) / 127.0
}
