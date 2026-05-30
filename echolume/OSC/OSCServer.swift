//
//  OSCServer.swift
//  echolume
//
//  UDP OSC listener built on Network.framework. Receives datagrams, parses
//  them with OSCParser, and delivers messages on the main actor. Mirrors the
//  MidiManager/TwitchChatManager callback shape. Requires the incoming-network
//  sandbox entitlement (ENABLE_INCOMING_NETWORK_CONNECTIONS).
//

import Combine
import Foundation
import Network

@MainActor
final class OSCServer: ObservableObject {
    enum Status: Equatable {
        case off
        case listening(port: UInt16)
        case failed(String)
    }

    @Published private(set) var status: Status = .off
    /// Bumped on every received message — drives an activity indicator.
    @Published private(set) var receiveTick: Int = 0

    /// Delivered on the main actor for each parsed OSC message.
    var onMessage: ((OSCMessage) -> Void)?

    private var listener: NWListener?
    private nonisolated let queue = DispatchQueue(label: "echolume.osc")

    func start(port: UInt16) {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = .failed("Invalid port \(port)")
            return
        }
        do {
            let listener = try NWListener(using: .udp, on: nwPort)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch state {
                    case .ready: self.status = .listening(port: port)
                    case .failed(let error): self.status = .failed(error.localizedDescription)
                    case .cancelled: self.status = .off
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.receive(on: connection)
            }
            listener.start(queue: queue)
        } catch {
            status = .failed(error.localizedDescription)
            Log.error("OSCServer: failed to start on port \(port) — \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        status = .off
    }

    private nonisolated func receive(on connection: NWConnection) {
        connection.start(queue: queue)
        func pump() {
            connection.receiveMessage { [weak self] data, _, _, error in
                if let data, !data.isEmpty {
                    let messages = OSCParser.parse(data)
                    if !messages.isEmpty {
                        DispatchQueue.main.async { self?.deliver(messages) }
                    }
                }
                if error == nil { pump() } else { connection.cancel() }
            }
        }
        pump()
    }

    private func deliver(_ messages: [OSCMessage]) {
        for msg in messages {
            receiveTick &+= 1
            onMessage?(msg)
        }
    }

    deinit {
        listener?.cancel()
    }
}
