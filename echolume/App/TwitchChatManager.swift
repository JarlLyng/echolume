//
//  TwitchChatManager.swift
//  echolume
//
//  Connects to Twitch IRC via WebSocket (anonymous, read-only).
//  Parses chat commands (!theme, !randomize, etc.) and forwards them via a callback.
//

import Combine
import Foundation

enum TwitchConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum TwitchCommand {
    case theme(String)
    case scene(String)
    case shape(String)
    case randomize
    case glitch
    case abstract(Int)
    case preset(String)
}

@MainActor
final class TwitchChatManager: ObservableObject {
    @Published private(set) var status: TwitchConnectionStatus = .disconnected

    var onCommand: ((TwitchCommand) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var channel: String = ""
    private var retryCount = 0
    private let baseBackoff: TimeInterval = 2
    private let maxBackoff: TimeInterval = 30
    private var lastCommandTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 1.0

    // Liveness. A silently dropped TCP connection (no FIN) never produces a
    // receive failure, so chat can look connected but be dead. Track the last
    // received activity, probe periodically, and force a reconnect if it goes
    // quiet past the idle timeout.
    private var lastActivityTime: Date = .distantPast
    private let keepAliveInterval: TimeInterval = 60
    private let idleTimeout: TimeInterval = 180
    private var livenessTask: Task<Void, Never>?

    func connect(channel: String) {
        disconnect()
        let cleaned = channel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard !cleaned.isEmpty else {
            status = .error("No channel name")
            return
        }
        self.channel = cleaned
        retryCount = 0
        openConnection()
    }

    func disconnect() {
        livenessTask?.cancel()
        livenessTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        status = .disconnected
    }

    // MARK: - Connection

    private func openConnection() {
        guard let url = URL(string: "wss://irc-ws.chat.twitch.tv:443") else { return }
        status = .connecting
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        lastActivityTime = Date()

        let nick = "justinfan\(Int.random(in: 10000...99999))"
        send("CAP REQ :twitch.tv/tags twitch.tv/commands")
        send("NICK \(nick)")
        send("JOIN #\(channel)")

        Log.info("[Twitch] Connecting to #\(channel) as \(nick)")
        receiveLoop()
        startLivenessMonitor()
    }

    private func send(_ text: String) {
        webSocketTask?.send(.string(text)) { error in
            if let error {
                Log.error("[Twitch] Send error: \(error.localizedDescription)")
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor [self] in
                guard self.webSocketTask != nil else { return }
                switch result {
                case .success(let message):
                    self.lastActivityTime = Date()
                    switch message {
                    case .string(let text):
                        for line in text.components(separatedBy: "\r\n") where !line.isEmpty {
                            self.parseLine(line)
                        }
                    default:
                        break
                    }
                    self.receiveLoop()
                case .failure(let error):
                    Log.error("[Twitch] Receive error: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }

    // MARK: - IRC Parsing

    private func parseLine(_ line: String) {
        if line.hasPrefix("PING") {
            send("PONG :tmi.twitch.tv")
            return
        }

        // 366 = end of NAMES list → joined successfully
        if line.contains(" 366 ") {
            status = .connected
            retryCount = 0
            Log.info("[Twitch] Joined #\(channel)")
            return
        }

        // PRIVMSG
        guard let privmsgRange = line.range(of: "PRIVMSG #\(channel) :") else { return }
        let messageBody = String(line[privmsgRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let command = parseCommand(messageBody) {
            handleRateLimitedCommand(command)
        }
    }

    nonisolated static func parseCommand(_ message: String) -> TwitchCommand? {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("!") else { return nil }
        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        guard let keyword = parts.first?.lowercased() else { return nil }
        let arg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        switch keyword {
        case "theme":
            guard let name = arg, !name.isEmpty else { return nil }
            return .theme(name)
        case "scene":
            guard let name = arg, !name.isEmpty else { return nil }
            return .scene(name)
        case "shape":
            guard let name = arg, !name.isEmpty else { return nil }
            return .shape(name)
        case "randomize":
            return .randomize
        case "glitch":
            return .glitch
        case "abstract":
            guard let str = arg, let val = Int(str) else { return nil }
            return .abstract(max(0, min(100, val)))
        case "preset":
            guard let name = arg, !name.isEmpty else { return nil }
            return .preset(name)
        default:
            return nil
        }
    }

    private func parseCommand(_ message: String) -> TwitchCommand? {
        Self.parseCommand(message)
    }

    private func handleRateLimitedCommand(_ command: TwitchCommand) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTime) >= cooldownInterval else { return }
        lastCommandTime = now
        onCommand?(command)
    }

    // MARK: - Reconnection

    private func handleDisconnect() {
        webSocketTask = nil
        livenessTask?.cancel()
        livenessTask = nil
        // Unbounded exponential backoff (capped). A streaming tool should keep
        // trying to reconnect for the whole session rather than give up after a
        // few tries; the user can stop it by toggling the channel off.
        let delay = min(maxBackoff, baseBackoff * pow(2, Double(retryCount)))
        retryCount += 1
        status = .connecting
        Log.info("[Twitch] Reconnecting in \(Int(delay))s (attempt \(retryCount))")
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.status == .connecting else { return }
            self.openConnection()
        }
    }

    /// Periodically probe the connection. A live server answers our PING with a
    /// PONG (which resets `lastActivityTime`); a silently dropped socket won't,
    /// so once we've heard nothing for `idleTimeout` we force a reconnect.
    private func startLivenessMonitor() {
        livenessTask?.cancel()
        let interval = keepAliveInterval
        let timeout = idleTimeout
        livenessTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard let self, !Task.isCancelled, self.webSocketTask != nil else { return }
                if Date().timeIntervalSince(self.lastActivityTime) > timeout {
                    Log.warn("[Twitch] No activity for over \(Int(timeout))s — forcing reconnect")
                    self.retryCount = 0
                    self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                    self.handleDisconnect()
                    return
                }
                self.send("PING :tmi.twitch.tv")
            }
        }
    }
}
