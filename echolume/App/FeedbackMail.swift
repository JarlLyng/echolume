//
//  FeedbackMail.swift
//  echolume
//
//  Help → Send Feedback…: a prefilled email to support, so someone with a
//  problem has a private route and not only a public review (#206). The app
//  collects no usage data, so what users choose to tell us is how we learn.
//

import AppKit
import Foundation

enum FeedbackMail {
    nonisolated static var address: String { "support@iamjarl.com" }
    nonisolated static var supportPage: URL? { URL(string: "https://echolume.iamjarl.com/support.html") }

    /// The `mailto:` URL for a feedback email. Subject and body are only a
    /// starting point: the user sees and can edit all of it in their mail app
    /// before anything is sent.
    nonisolated static func url(appVersion: String, build: String, osVersion: OperatingSystemVersion) -> URL? {
        let os = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Echolume \(appVersion) feedback"),
            URLQueryItem(name: "body", value: "\n\n\n---\nEcholume \(appVersion) (\(build))\nmacOS \(os)\n")
        ]
        return components.url
    }

    /// Opens the user's mail app with the feedback email filled in.
    static func compose() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        guard let url = url(appVersion: version, build: build,
                            osVersion: ProcessInfo.processInfo.operatingSystemVersion) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the support page in the default browser.
    static func openSupportPage() {
        guard let url = supportPage else { return }
        NSWorkspace.shared.open(url)
    }
}
