//
//  Log.swift
//  echolume
//
//  Lightweight logging helper for audio/render lifecycle and errors.
//

import Foundation
import os

private let log = Logger(subsystem: "com.iamjarl.echolume", category: "app")

enum Log {
    static func debug(_ message: String) {
        log.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        log.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        log.error("\(message, privacy: .public)")
    }
}
