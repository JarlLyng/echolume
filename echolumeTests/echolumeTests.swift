//
//  echolumeTests.swift
//  echolumeTests
//
//  Unit tests for pure-logic types. Audio engine, networking, and UI are
//  not exercised here — see UI tests and manual verification for those.
//

import Testing
@testable import echolume

// MARK: - TwitchChatManager.parseCommand

struct TwitchCommandParsingTests {

    // MARK: theme / scene / shape

    @Test func theme_withName_returnsTheme() {
        let command = TwitchChatManager.parseCommand("!theme aurora")
        guard case .theme(let name) = command else {
            Issue.record("Expected .theme, got \(String(describing: command))")
            return
        }
        #expect(name == "aurora")
    }

    @Test func theme_withoutArg_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!theme") == nil)
        #expect(TwitchChatManager.parseCommand("!theme   ") == nil)
    }

    @Test func scene_withName_returnsScene() {
        let command = TwitchChatManager.parseCommand("!scene radial")
        guard case .scene(let name) = command else {
            Issue.record("Expected .scene")
            return
        }
        #expect(name == "radial")
    }

    @Test func shape_withName_returnsShape() {
        let command = TwitchChatManager.parseCommand("!shape dots")
        guard case .shape(let name) = command else {
            Issue.record("Expected .shape")
            return
        }
        #expect(name == "dots")
    }

    // MARK: trigger commands

    @Test func randomize_returnsRandomize() {
        guard case .randomize = TwitchChatManager.parseCommand("!randomize") else {
            Issue.record("Expected .randomize")
            return
        }
    }

    @Test func glitch_returnsGlitch() {
        guard case .glitch = TwitchChatManager.parseCommand("!glitch") else {
            Issue.record("Expected .glitch")
            return
        }
    }

    // MARK: abstract (numeric arg)

    @Test func abstract_withValidNumber_returnsAbstract() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract 75") else {
            Issue.record("Expected .abstract")
            return
        }
        #expect(value == 75)
    }

    @Test func abstract_clampsAboveRange() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract 9999") else {
            Issue.record("Expected .abstract clamped")
            return
        }
        #expect(value == 100)
    }

    @Test func abstract_clampsBelowRange() {
        guard case .abstract(let value) = TwitchChatManager.parseCommand("!abstract -50") else {
            Issue.record("Expected .abstract clamped")
            return
        }
        #expect(value == 0)
    }

    @Test func abstract_withInvalidArg_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!abstract abc") == nil)
        #expect(TwitchChatManager.parseCommand("!abstract") == nil)
    }

    // MARK: rejection

    @Test func messageWithoutBang_returnsNil() {
        #expect(TwitchChatManager.parseCommand("theme aurora") == nil)
        #expect(TwitchChatManager.parseCommand("hello") == nil)
        #expect(TwitchChatManager.parseCommand("") == nil)
    }

    @Test func unknownCommand_returnsNil() {
        #expect(TwitchChatManager.parseCommand("!ban someone") == nil)
        #expect(TwitchChatManager.parseCommand("!hello") == nil)
    }

    // MARK: case + whitespace

    @Test func commandIsCaseInsensitive() {
        guard case .theme(let name) = TwitchChatManager.parseCommand("!THEME aurora") else {
            Issue.record("Expected .theme")
            return
        }
        #expect(name == "aurora")
    }

    @Test func leadingWhitespaceIsTolerated() {
        guard case .randomize = TwitchChatManager.parseCommand("  !randomize") else {
            Issue.record("Expected .randomize")
            return
        }
    }

    @Test func trailingWhitespaceIsStripped() {
        guard case .theme(let name) = TwitchChatManager.parseCommand("!theme aurora   ") else {
            Issue.record("Expected .theme")
            return
        }
        #expect(name == "aurora")
    }
}

// MARK: - TwitchConnectionStatus equality

struct TwitchConnectionStatusTests {

    @Test func errorStatusEqualityRespectsMessage() {
        #expect(TwitchConnectionStatus.error("a") == TwitchConnectionStatus.error("a"))
        #expect(TwitchConnectionStatus.error("a") != TwitchConnectionStatus.error("b"))
    }

    @Test func differentCasesAreNotEqual() {
        #expect(TwitchConnectionStatus.connected != TwitchConnectionStatus.disconnected)
        #expect(TwitchConnectionStatus.connecting != TwitchConnectionStatus.connected)
    }
}
