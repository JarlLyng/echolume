//
//  FeedbackMailTests.swift
//  echolumeTests
//

import Foundation
import Testing
@testable import echolume

struct FeedbackMailTests {

    private func queryItems(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private let sonoma = OperatingSystemVersion(majorVersion: 14, minorVersion: 6, patchVersion: 1)

    @Test func url_isMailtoSupport() throws {
        let url = try #require(FeedbackMail.url(appVersion: "1.3.0", build: "30", osVersion: sonoma))
        #expect(url.scheme == "mailto")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.path == "support@iamjarl.com")
    }

    @Test func subject_namesTheVersion() throws {
        let url = try #require(FeedbackMail.url(appVersion: "1.3.0", build: "30", osVersion: sonoma))
        #expect(queryItems(url)["subject"] == "Echolume 1.3.0 feedback")
    }

    @Test func body_carriesAppAndMacOSVersion() throws {
        let url = try #require(FeedbackMail.url(appVersion: "1.3.0", build: "30", osVersion: sonoma))
        let body = try #require(queryItems(url)["body"])
        #expect(body.contains("Echolume 1.3.0 (30)"))
        #expect(body.contains("macOS 14.6.1"))
    }

    @Test func spacesAndNewlines_arePercentEncoded() throws {
        let url = try #require(FeedbackMail.url(appVersion: "1.3.0", build: "30", osVersion: sonoma))
        #expect(!url.absoluteString.contains(" "))
        #expect(!url.absoluteString.contains("\n"))
    }
}
