//
//  AudioDevice.swift
//  echolume
//

import CoreAudio
import Foundation

/// Represents an audio input device for the Audio Source picker.
struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let inputChannelCount: Int

    /// False for iPhone/iPad proxy/Continuity mics; AUHAL should not be used for these.
    var isSupportedForAUHAL: Bool {
        let lower = name.lowercased()
        return !lower.contains("iphone") && !lower.contains("ipad")
    }

    /// Stereo pair indices: 0 = channels 1–2, 1 = channels 3–4, etc.
    var channelPairs: [Int] {
        (0 ..< (inputChannelCount / 2)).map { $0 }
    }

    /// User-visible label for a pair, e.g. "1–2", "3–4".
    static func channelPairLabel(pairIndex: Int) -> String {
        let low = pairIndex * 2 + 1
        let high = pairIndex * 2 + 2
        return "\(low)–\(high)"
    }
}
