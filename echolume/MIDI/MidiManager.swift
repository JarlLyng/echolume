//
//  MidiManager.swift
//  echolume
//
//  Thin CoreMIDI layer: creates a client + input port, connects every MIDI
//  source, and funnels incoming MIDI 1.0 channel-voice messages through the
//  pure MidiMessage parser to `onMessage` (on the main actor). Device-list
//  changes refresh the input names. All semantic logic lives elsewhere.
//

import Combine
import CoreMIDI
import Foundation

@MainActor
final class MidiManager: ObservableObject {
    /// Display names of detected MIDI sources (for the settings UI).
    @Published private(set) var inputNames: [String] = []
    /// Bumped on every received message — drives a small activity indicator.
    @Published private(set) var receiveTick: Int = 0

    /// Delivered on the main actor for each actionable MIDI message.
    var onMessage: ((MidiMessage) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSources = Set<MIDIEndpointRef>()
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        let notifyBlock: MIDINotifyBlock = { _ in
            DispatchQueue.main.async { [weak self] in self?.refreshAndConnect() }
        }
        var status = MIDIClientCreateWithBlock("echolume" as CFString, &client, notifyBlock)
        guard status == noErr else {
            Log.error("MidiManager: MIDIClientCreateWithBlock failed (\(status))")
            started = false
            return
        }

        let receiveBlock: MIDIReceiveBlock = { [weak self] eventListPtr, _ in
            // Runs on a CoreMIDI thread. Parse here (pure), deliver on main.
            let eventList = eventListPtr.pointee
            withUnsafePointer(to: eventList.packet) { firstPacket in
                var packetPtr = firstPacket
                for _ in 0 ..< eventList.numPackets {
                    let packet = packetPtr.pointee
                    let wordCount = Int(packet.wordCount)
                    withUnsafePointer(to: packet.words) { wordsTuple in
                        wordsTuple.withMemoryRebound(to: UInt32.self, capacity: 64) { words in
                            for i in 0 ..< min(wordCount, 64) {
                                let word = words[i]
                                // Message Type 0x2 == MIDI 1.0 channel voice (one word).
                                guard (word >> 28) & 0xF == 0x2 else { continue }
                                let statusByte = UInt8((word >> 16) & 0xFF)
                                let d1 = UInt8((word >> 8) & 0xFF)
                                let d2 = UInt8(word & 0xFF)
                                if let msg = MidiMessage.parse(status: statusByte, d1, d2) {
                                    DispatchQueue.main.async { self?.deliver(msg) }
                                }
                            }
                        }
                    }
                    packetPtr = UnsafePointer(MIDIEventPacketNext(packetPtr))
                }
            }
        }
        status = MIDIInputPortCreateWithProtocol(client, "echolume.in" as CFString, ._1_0, &inputPort, receiveBlock)
        guard status == noErr else {
            Log.error("MidiManager: MIDIInputPortCreateWithProtocol failed (\(status))")
            return
        }

        refreshAndConnect()
        Log.info("MidiManager: started; \(inputNames.count) input(s)")
    }

    private func deliver(_ msg: MidiMessage) {
        receiveTick &+= 1
        onMessage?(msg)
    }

    /// Enumerate sources, connect any not yet connected, and refresh names.
    private func refreshAndConnect() {
        var names: [String] = []
        let count = MIDIGetNumberOfSources()
        for i in 0 ..< count {
            let source = MIDIGetSource(i)
            guard source != 0 else { continue }
            names.append(Self.displayName(of: source))
            if !connectedSources.contains(source) {
                let status = MIDIPortConnectSource(inputPort, source, nil)
                if status == noErr {
                    connectedSources.insert(source)
                } else {
                    Log.warn("MidiManager: connect source failed (\(status))")
                }
            }
        }
        inputNames = names
    }

    private static func displayName(of endpoint: MIDIEndpointRef) -> String {
        var param: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        if status == noErr, let cf = param?.takeRetainedValue() {
            return cf as String
        }
        return "MIDI Input"
    }

    deinit {
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
