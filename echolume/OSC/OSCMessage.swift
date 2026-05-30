//
//  OSCMessage.swift
//  echolume
//
//  Minimal OSC 1.0 parsing — just enough to drive Echolume from TouchDesigner,
//  Resolume, or any OSC controller. Pure (no sockets) so it is unit-testable.
//  Supports float / int32 / string / no-arg (bang) types and #bundle unwrapping.
//

import Foundation

enum OSCArgument: Equatable {
    case float(Float)
    case int(Int32)
    case string(String)
    case bang   // trigger: empty type tag, or T / I
}

struct OSCMessage: Equatable {
    var address: String
    var arguments: [OSCArgument]
}

enum OSCParser {
    /// Parse a UDP datagram into zero or more OSC messages (a bundle yields many).
    static func parse(_ data: Data) -> [OSCMessage] {
        let bytes = [UInt8](data)
        var messages: [OSCMessage] = []
        parsePacket(bytes, into: &messages)
        return messages
    }

    private static func parsePacket(_ bytes: [UInt8], into messages: inout [OSCMessage]) {
        guard let first = bytes.first else { return }
        if first == UInt8(ascii: "#") {
            parseBundle(bytes, into: &messages)
        } else if first == UInt8(ascii: "/") {
            if let msg = parseMessage(bytes) { messages.append(msg) }
        }
    }

    private static func parseBundle(_ bytes: [UInt8], into messages: inout [OSCMessage]) {
        // "#bundle\0" (8) + timetag (8) + repeated [int32 size][element bytes].
        var i = 16
        guard bytes.count >= i else { return }
        while i + 4 <= bytes.count {
            guard let size = readInt32(bytes, at: i) else { return }
            i += 4
            let len = Int(size)
            guard len > 0, i + len <= bytes.count else { return }
            let element = Array(bytes[i ..< i + len])
            parsePacket(element, into: &messages)
            i += len
        }
    }

    private static func parseMessage(_ bytes: [UInt8]) -> OSCMessage? {
        var offset = 0
        guard let address = readOSCString(bytes, at: &offset) else { return nil }
        // Type tag string (starts with ','). Absent → treat as a no-arg trigger
        // (tolerant: some senders omit the type tag for trigger messages).
        guard offset < bytes.count, let tags = readOSCString(bytes, at: &offset), tags.hasPrefix(",") else {
            return OSCMessage(address: address, arguments: [.bang])
        }
        var args: [OSCArgument] = []
        for tag in tags.dropFirst() {
            switch tag {
            case "f":
                guard let v = readInt32(bytes, at: offset) else { return nil }
                offset += 4
                args.append(.float(Float(bitPattern: UInt32(bitPattern: v))))
            case "i":
                guard let v = readInt32(bytes, at: offset) else { return nil }
                offset += 4
                args.append(.int(v))
            case "s":
                guard let s = readOSCString(bytes, at: &offset) else { return nil }
                args.append(.string(s))
            case "T", "F", "I", "N":
                args.append(.bang)
            default:
                return nil   // unsupported type
            }
        }
        if args.isEmpty { args = [.bang] }   // type-tag-only trigger
        return OSCMessage(address: address, arguments: args)
    }

    // MARK: - Primitives

    /// Read a null-terminated, 4-byte-aligned OSC string, advancing `offset`.
    private static func readOSCString(_ bytes: [UInt8], at offset: inout Int) -> String? {
        guard offset < bytes.count else { return nil }
        var end = offset
        while end < bytes.count, bytes[end] != 0 { end += 1 }
        guard end < bytes.count else { return nil }   // must be null-terminated
        let str = String(decoding: bytes[offset ..< end], as: UTF8.self)
        // Advance past the null and pad to the next 4-byte boundary.
        let rawLen = end - offset + 1
        let padded = (rawLen + 3) & ~3
        offset += padded
        return str
    }

    private static func readInt32(_ bytes: [UInt8], at offset: Int) -> Int32? {
        guard offset + 4 <= bytes.count else { return nil }
        let b = bytes
        let u = (UInt32(b[offset]) << 24) | (UInt32(b[offset + 1]) << 16)
            | (UInt32(b[offset + 2]) << 8) | UInt32(b[offset + 3])
        return Int32(bitPattern: u)
    }
}
