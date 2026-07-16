//
//  PluginOSCSender.swift
//  EcholumeAudioTap
//
//  Sends the kernel's analysed bands + host BPM to Echolume over loopback
//  UDP OSC from a ~60 Hz dispatch timer, keeping every syscall off the
//  realtime render thread (#51). The render thread only writes plain floats;
//  this class polls them via the kernel getters (benign single-float races).
//

import Darwin
import Foundation

final class PluginOSCSender {
    private let queue = DispatchQueue(label: "echolume.plugin.osc", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var socketFD: Int32 = -1
    private var destination = sockaddr_in()

    /// Reads the latest analysis values. Called on the timer queue; must not
    /// touch the render thread (the kernel getters are plain float reads).
    private let readValues: () -> (level: Float, low: Float, mid: Float, high: Float, bpm: Float)

    init(readValues: @escaping () -> (level: Float, low: Float, mid: Float, high: Float, bpm: Float)) {
        self.readValues = readValues
    }

    deinit {
        stop()
    }

    func start() {
        queue.sync {
            guard timer == nil else { return }
            openSocket()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(5))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            if socketFD >= 0 {
                close(socketFD)
                socketFD = -1
            }
        }
    }

    // MARK: - Internals (timer queue only)

    private func openSocket() {
        guard socketFD < 0 else { return }
        socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { return }
        // Non-blocking: a full send buffer drops the packet instead of waiting.
        _ = fcntl(socketFD, F_SETFL, O_NONBLOCK)
        destination = sockaddr_in()
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = in_port_t(UInt16(9000).bigEndian)
        destination.sin_addr.s_addr = inet_addr("127.0.0.1")
    }

    private func tick() {
        guard socketFD >= 0 else { return }
        let v = readValues()
        sendOSCFloat("/echolume/audio/level", v.level)
        sendOSCFloat("/echolume/audio/low", v.low)
        sendOSCFloat("/echolume/audio/mid", v.mid)
        sendOSCFloat("/echolume/audio/high", v.high)
        if v.bpm > 0 { sendOSCFloat("/echolume/audio/bpm", v.bpm) }
    }

    /// One OSC float message: padded address, ",f" type tag, big-endian float32.
    private func sendOSCFloat(_ address: String, _ value: Float) {
        var packet = [UInt8]()
        packet.reserveCapacity(64)
        packet.append(contentsOf: Array(address.utf8))
        packet.append(0)
        while packet.count % 4 != 0 { packet.append(0) }
        packet.append(contentsOf: [UInt8(ascii: ","), UInt8(ascii: "f"), 0, 0])
        withUnsafeBytes(of: value.bitPattern.bigEndian) { packet.append(contentsOf: $0) }

        var dst = destination
        packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &dst) { dstPtr in
                dstPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    _ = sendto(socketFD, raw.baseAddress, raw.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
