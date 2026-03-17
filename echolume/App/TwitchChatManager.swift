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
}

@MainActor
final class TwitchChatManager: ObservableObject {
    @Published private(set) var status: TwitchConnectionStatus = .disconnected

    var onCommand: ((TwitchCommand) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var channel: String = ""
    private var retryCount = 0
    private let maxRetries = 3
    private var lastCommandTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 1.0

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

        let nick = "justinfan\(Int.random(in: 10000...99999))"
        send("CAP REQ :twitch.tv/tags twitch.tv/commands")
        send("NICK \(nick)")
        send("JOIN #\(channel)")

        Log.info("[Twitch] Connecting to #\(channel) as \(nick)")
        receiveLoop()
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

    static func parseCommand(_ message: String) -> TwitchCommand? {
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
        guard retryCount < maxRetries else {
            status = .error("Connection lost")
            Log.warn("[Twitch] Max retries reached")
            return
        }
        retryCount += 1
        status = .connecting
        Log.info("[Twitch] Reconnecting (attempt \(retryCount)/\(maxRetries))")
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard self.status == .connecting else { return }
            self.openConnection()
        }
    }
}
