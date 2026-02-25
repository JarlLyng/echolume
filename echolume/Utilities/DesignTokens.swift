//
//  DesignTokens.swift
//  echolume
//
//  IAMJARL Design System — local mapping from tokens.json.
//  Source: https://github.com/JarlLyng/iamjarl-design
//

import SwiftUI

enum DesignTokens {

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    // MARK: - Typography
    enum Typography {
        static let uiFontName: String = "system-ui"
        static let monoFontName: String = "ui-monospace"

        enum Size {
            static let xs: CGFloat = 12
            static let sm: CGFloat = 14
            static let base: CGFloat = 16
            static let lg: CGFloat = 18
            static let xl: CGFloat = 24
            static let xxl: CGFloat = 36
        }

        enum LineHeight {
            static let tight: CGFloat = 20
            static let normal: CGFloat = 24
            static let relaxed: CGFloat = 28
            static let sm: CGFloat = 18
            static let xxl: CGFloat = 43.2
        }

        enum Weight {
            static let regular: Font.Weight = .regular
            static let semibold: Font.Weight = .semibold
            static let bold: Font.Weight = .bold
        }
    }

    // MARK: - Color Tokens
    enum ColorToken {
        static let black = Color(hex: "#000000")
        static let white = Color(hex: "#FFFFFF")

        enum State {
            static let success = Color(hex: "#4CAF50")
            static let onSuccess = Color(hex: "#FFFFFF")
            static let warning = Color(hex: "#FF6B35")
            static let onWarning = Color(hex: "#000000")
            static let error = Color(hex: "#FF3B30")
            static let onError = Color(hex: "#FFFFFF")
        }

        enum Light {
            static let primary = Color(hex: "#00FF7B")
            static let onPrimary = Color(hex: "#000000")
            enum Text {
                static let primary = Color(hex: "#000000")
                static let secondary = Color(rgba: "rgba(0, 0, 0, 0.70)")
                static let tertiary = Color(rgba: "rgba(0, 0, 0, 0.55)")
                static let inverse = Color(hex: "#FFFFFF")
            }
            enum Background {
                static let app = Color(hex: "#FFFFFF")
                static let muted = Color(rgba: "rgba(0, 0, 0, 0.04)")
                static let card = Color(rgba: "rgba(0, 0, 0, 0.04)")
            }
            enum Surface {
                static let `default` = Color(hex: "#FFFFFF")
                static let raised = Color(rgba: "rgba(0, 0, 0, 0.02)")
            }
            enum Border {
                static let subtle = Color(rgba: "rgba(0, 0, 0, 0.10)")
                static let `default` = Color(rgba: "rgba(0, 0, 0, 0.16)")
            }
        }

        enum Dark {
            static let primary = Color(hex: "#D0FF00")
            static let onPrimary = Color(hex: "#000000")
            enum Text {
                static let primary = Color(hex: "#FFFFFF")
                static let secondary = Color(rgba: "rgba(255, 255, 255, 0.75)")
                static let tertiary = Color(rgba: "rgba(255, 255, 255, 0.60)")
                static let inverse = Color(hex: "#000000")
            }
            enum Background {
                static let app = Color(hex: "#000000")
                static let muted = Color(rgba: "rgba(255, 255, 255, 0.05)")
                static let card = Color(rgba: "rgba(255, 255, 255, 0.05)")
            }
            enum Surface {
                static let `default` = Color(hex: "#000000")
                static let raised = Color(rgba: "rgba(255, 255, 255, 0.03)")
            }
            enum Border {
                static let subtle = Color(rgba: "rgba(255, 255, 255, 0.12)")
                static let `default` = Color(rgba: "rgba(255, 255, 255, 0.18)")
            }
        }
    }

    // MARK: - Mode Helpers
    static func pick<T>(_ light: T, _ dark: T, scheme: ColorScheme) -> T {
        scheme == .dark ? dark : light
    }

    static func color(light: Color, dark: Color, scheme: ColorScheme) -> Color {
        pick(light, dark, scheme: scheme)
    }

    enum Common {
        enum OnPrimary {
            static func text(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(
                    light: ColorToken.Light.onPrimary,
                    dark: ColorToken.Dark.onPrimary,
                    scheme: scheme
                )
            }
        }
        static func primary(_ scheme: ColorScheme) -> Color {
            DesignTokens.color(light: ColorToken.Light.primary, dark: ColorToken.Dark.primary, scheme: scheme)
        }
        enum Text {
            static func primary(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Text.primary, dark: ColorToken.Dark.Text.primary, scheme: scheme)
            }
            static func secondary(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Text.secondary, dark: ColorToken.Dark.Text.secondary, scheme: scheme)
            }
            static func tertiary(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Text.tertiary, dark: ColorToken.Dark.Text.tertiary, scheme: scheme)
            }
            static func inverse(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Text.inverse, dark: ColorToken.Dark.Text.inverse, scheme: scheme)
            }
        }
        enum Background {
            static func app(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Background.app, dark: ColorToken.Dark.Background.app, scheme: scheme)
            }
            static func muted(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Background.muted, dark: ColorToken.Dark.Background.muted, scheme: scheme)
            }
            static func card(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Background.card, dark: ColorToken.Dark.Background.card, scheme: scheme)
            }
        }
        enum Border {
            static func subtle(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Border.subtle, dark: ColorToken.Dark.Border.subtle, scheme: scheme)
            }
            static func `default`(_ scheme: ColorScheme) -> Color {
                DesignTokens.color(light: ColorToken.Light.Border.default, dark: ColorToken.Dark.Border.default, scheme: scheme)
            }
        }
    }
}

// MARK: - Color Parsing Helpers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }

    init(rgba: String) {
        let cleaned = rgba
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
        let parts = cleaned.split(separator: ",").map(String.init)
        guard parts.count == 4,
              let r = Double(parts[0]),
              let g = Double(parts[1]),
              let b = Double(parts[2]),
              let a = Double(parts[3]) else {
            self = .clear
            return
        }
        self.init(.sRGB, red: r / 255.0, green: g / 255.0, blue: b / 255.0, opacity: a)
    }
}
