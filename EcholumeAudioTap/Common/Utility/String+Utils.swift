//
//  String+Utils.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import Foundation

extension String {
    var range: NSRange {
        NSRange(location: 0, length: count)
    }

    func isAlphanumeric() -> Bool {
        if self.isEmpty { return false }
        // swiftlint:disable:next force_try (static, known-valid pattern)
        let regex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_-]*$", options: .caseInsensitive)
        guard regex.firstMatch(in: self, options: [], range: range) != nil else {
            return false
        }
        return true
    }
}
