//
//  PluginStyle.swift
//  EcholumeAudioTap
//
//  Local style constants for the AUv3 plugin UI. The app-extension target does
//  not link IAMJARLDesignTokens (kept lean), so these mirror the Echolume brand
//  (lime accent on a dark surface) standalone.
//

import SwiftUI

enum PluginStyle {
    /// Echolume accent — lime / neon yellow (#D0FF00).
    static let accent = Color(red: 0.816, green: 1.0, blue: 0.0)
    static let background = Color(red: 0.043, green: 0.043, blue: 0.055)
    static let surface = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.10)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)

    static let radius: CGFloat = 12

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }
}
