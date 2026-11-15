//
//  CrashReporting.swift
//  echolume
//
//  Anonymous crash + diagnostics via Sentry, under the portfolio's privacy
//  recipe (issue #233). No identifier leaves the device: one shared user
//  "anonymous", and the per-install identifiers Sentry adds by default
//  (contexts.device.id and contexts.app.device_app_hash) are stripped in
//  beforeSend. No PII, screenshots or view hierarchy. Sessions stay off until an
//  envelope test proves they carry no per-install ID (#233, rule 6). This runs
//  in the app target only, never in the EcholumeAudioTap audio unit, so nothing
//  touches the real-time audio thread.
//

import Foundation
import Sentry

enum CrashReporting {
    /// Starts Sentry if a DSN is configured. Call once, as early as possible.
    /// With no DSN (CI, local Debug without one) it does nothing.
    static func start() {
        guard let dsn = resolvedDSN(), !dsn.isEmpty else {
            #if DEBUG
            print("[CrashReporting] No SENTRY_DSN set; Sentry is disabled.")
            #endif
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = currentEnvironment()

            // Nothing that identifies or watches.
            options.sendDefaultPii = false          // Sentry's onboarding turns this on; we don't.
            // Screenshots and view hierarchy are iOS/tvOS/visionOS-only in
            // sentry-cocoa and never capture on macOS, so there is nothing to
            // switch off here (the recipe's "no watching" holds by platform).
            options.enableAutoSessionTracking = false   // off until the envelope test (#233 rule 6)
            options.enableMetricKit = true              // hangs, launch and other diagnostics

            // One shared user on every install, set before any event.
            options.initialScope = { scope in
                scope.setUser(Self.anonymousUser())
                return scope
            }

            // Last line of defense: strip the default per-install identifiers and
            // force the shared user. On Apple, transactions also pass through here.
            options.beforeSend = { event in
                Self.scrubIdentifiers(event)
                Self.redactPaths(event)
                return event
            }
        }
    }

    private static func anonymousUser() -> User {
        let user = User()
        user.userId = "anonymous"
        return user
    }

    /// Removes Sentry's default per-install identifiers and pins the shared user.
    private static func scrubIdentifiers(_ event: Event) {
        if var context = event.context {
            if var app = context["app"] {
                app["device_app_hash"] = nil
                context["app"] = app
            }
            if var device = context["device"] {
                device["id"] = nil
                context["device"] = device
            }
            event.context = context
        }
        event.user = anonymousUser()
    }

    /// Replaces the account name in any `/Users/<name>/…` path with
    /// `/Users/<redacted>`, keeping the rest of the path so a crash stays
    /// readable. The home directory shows up in stack-frame packages and in
    /// debug-image file paths whenever the app runs from somewhere under it
    /// (a direct build, `~/Applications`, `~/Downloads`), and the account name
    /// is an identifier, so it must not leave the device.
    static func redactUserPaths(_ path: String) -> String {
        path.replacingOccurrences(
            of: "/Users/[^/]+",
            with: "/Users/<redacted>",
            options: .regularExpression
        )
    }

    /// Runs `redactUserPaths` over every stack-frame package (exception and
    /// thread stacktraces) and every debug-image code file on the event.
    private static func redactPaths(_ event: Event) {
        for exception in event.exceptions ?? [] {
            for frame in exception.stacktrace?.frames ?? [] {
                if let package = frame.package {
                    frame.package = redactUserPaths(package)
                }
            }
        }
        for thread in event.threads ?? [] {
            for frame in thread.stacktrace?.frames ?? [] {
                if let package = frame.package {
                    frame.package = redactUserPaths(package)
                }
            }
        }
        for image in event.debugMeta ?? [] {
            if let codeFile = image.codeFile {
                image.codeFile = redactUserPaths(codeFile)
            }
        }
    }

    /// DSN from the environment, else the Info.plist key `SentryDSN` (= `$(SENTRY_DSN)`).
    private static func resolvedDSN() -> String? {
        if let env = ProcessInfo.processInfo.environment["SENTRY_DSN"], !env.isEmpty {
            return env
        }
        return Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String
    }

    /// `production` only for App Store builds, so TestFlight and dev runs are not
    /// read as real crashes.
    private static func currentEnvironment() -> String {
        #if DEBUG
        return "debug"
        #else
        switch Bundle.main.appStoreReceiptURL?.lastPathComponent {
        case "receipt": return "production"        // Mac App Store
        case "sandboxReceipt": return "testflight"
        default: return "development"              // direct / unsigned Release build
        }
        #endif
    }
}
