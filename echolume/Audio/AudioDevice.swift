//
//  AudioDevice.swift
//  echolume
//
//  Read-only device model and enumeration. No property listeners. No system default changes.
//

import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let inputChannelCount: Int

    /// Stereo pair indices: 0 = ch 1–2, 1 = ch 3–4, …
    var channelPairs: [Int] {
        (0 ..< max(0, inputChannelCount / 2)).map { $0 }
    }

    static func channelPairLabel(pairIndex: Int) -> String {
        "\(pairIndex * 2 + 1)–\(pairIndex * 2 + 2)"
    }

    /// Enumerate input-capable devices. No listeners; on-demand only.
    /// - Parameter includeAdvanced: if false, exclude names containing "iPhone" or "Continuity"
    static func enumerate(includeAdvanced: Bool = false) -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var err = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        guard err == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        err = ids.withUnsafeMutableBufferPointer { buf in
            var s = size
            guard let base = buf.baseAddress else { return OSStatus(-1) }
            return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &s, base)
        }
        guard err == noErr else { return [] }

        var result: [AudioDevice] = []
        for deviceID in ids {
            guard let name = getDeviceName(deviceID: deviceID),
                  let chCount = getInputChannelCount(deviceID: deviceID),
                  chCount > 0 else { continue }
            if !includeAdvanced {
                let lower = name.lowercased()
                if lower.contains("iphone") || lower.contains("continuity") { continue }
            }
            result.append(AudioDevice(id: deviceID, name: name, inputChannelCount: chCount))
        }
        return result
    }

    private static func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard err == noErr, let n = name as String? else { return nil }
        return n
    }

    private static func getInputChannelCount(deviceID: AudioDeviceID) -> Int? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard err == noErr, size > 0 else { return nil }
        let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPtr.deallocate() }
        err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPtr)
        guard err == noErr else { return nil }
        let list = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
