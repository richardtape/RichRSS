//
//  ThemeColors.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import SwiftUI

extension Theme {
    // Extract all colors from CSS theme file

    var backgroundColor: Color {
        extractColor(variable: "--bg-color") ?? Color(.systemBackground)
    }

    var textColor: Color {
        extractColor(variable: "--text-color") ?? Color.black
    }

    var accentColor: Color {
        extractColor(variable: "--accent-color") ?? Color.blue
    }

    var secondaryTextColor: Color {
        extractColor(variable: "--text-secondary") ?? Color.gray
    }

    var borderColor: Color {
        extractColor(variable: "--border-color") ?? Color.gray.opacity(0.2)
    }

    var codeBackgroundColor: Color {
        extractColor(variable: "--code-bg") ?? Color.gray.opacity(0.1)
    }

    var blockquoteBackgroundColor: Color {
        extractColor(variable: "--blockquote-bg") ?? Color.blue.opacity(0.1)
    }

    private func extractColor(variable: String) -> Color? {
        guard let cssContent = loadThemeCSS() else {
            return nil
        }

        // Find the variable in CSS and extract hex value
        let pattern = "\(variable)\\s*:\\s*(#[0-9A-Fa-f]{6})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = cssContent as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: cssContent, range: range) else {
            return nil
        }

        guard let hexRange = Range(match.range(at: 1), in: cssContent) else {
            return nil
        }

        let hexString = String(cssContent[hexRange])
        return Color(hex: hexString)
    }

    private func loadThemeCSS() -> String? {
        let filename = style.cssFileName
        guard let url = Bundle.main.url(forResource: filename, withExtension: "css") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        var rgb: UInt32 = 0
        if let hexValue = UInt32(hex, radix: 16) {
            rgb = hexValue
        }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
