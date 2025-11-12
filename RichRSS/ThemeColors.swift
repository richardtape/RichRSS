//
//  ThemeColors.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import SwiftUI

extension Theme {
    // MARK: - Colors

    var backgroundColor: Color {
        extractColor(variable: "--bg-color") ?? Color(.systemBackground)
    }

    var secondaryBackgroundColor: Color {
        extractColor(variable: "--bg-color-secondary") ?? Color(.systemGray6)
    }

    var textColor: Color {
        extractColor(variable: "--text-color") ?? Color.black
    }

    var secondaryTextColor: Color {
        extractColor(variable: "--text-color-secondary") ?? Color.gray
    }

    var accentColor: Color {
        extractColor(variable: "--accent-color") ?? Color.blue
    }

    var accentColorLight: Color {
        extractColor(variable: "--accent-color-light") ?? Color.blue.opacity(0.1)
    }

    var borderColor: Color {
        extractColor(variable: "--border-color") ?? Color.gray.opacity(0.2)
    }

    var dividerColor: Color {
        extractColor(variable: "--divider-color") ?? Color.gray.opacity(0.2)
    }

    var codeBackgroundColor: Color {
        extractColor(variable: "--code-bg-color") ?? Color.gray.opacity(0.1)
    }

    var blockquoteBackgroundColor: Color {
        extractColor(variable: "--blockquote-bg-color") ?? Color.blue.opacity(0.1)
    }

    var successColor: Color {
        extractColor(variable: "--success-color") ?? Color.green
    }

    var errorColor: Color {
        extractColor(variable: "--error-color") ?? Color.red
    }

    // MARK: - Typography (Font Sizes in points)

    var fontSizeTitle: CGFloat {
        extractFontSize(variable: "--font-size-title") ?? 28
    }

    var fontSizeTitle2: CGFloat {
        extractFontSize(variable: "--font-size-title2") ?? 22
    }

    var fontSizeHeadline: CGFloat {
        extractFontSize(variable: "--font-size-headline") ?? 18
    }

    var fontSizeBody: CGFloat {
        extractFontSize(variable: "--font-size-body") ?? 16
    }

    var fontSizeSubheadline: CGFloat {
        extractFontSize(variable: "--font-size-subheadline") ?? 15
    }

    var fontSizeCaption: CGFloat {
        extractFontSize(variable: "--font-size-caption") ?? 14
    }

    var fontSizeCaption2: CGFloat {
        extractFontSize(variable: "--font-size-caption2") ?? 13
    }

    // MARK: - Spacing (in points)

    var spacingXS: CGFloat {
        extractSpacing(variable: "--spacing-xs") ?? 4
    }

    var spacingSM: CGFloat {
        extractSpacing(variable: "--spacing-sm") ?? 8
    }

    var spacingMD: CGFloat {
        extractSpacing(variable: "--spacing-md") ?? 12
    }

    var spacingLG: CGFloat {
        extractSpacing(variable: "--spacing-lg") ?? 16
    }

    var spacingXL: CGFloat {
        extractSpacing(variable: "--spacing-xl") ?? 20
    }

    var spacingXXL: CGFloat {
        extractSpacing(variable: "--spacing-xxl") ?? 24
    }

    var listItemVerticalPadding: CGFloat {
        extractSpacing(variable: "--list-item-vertical-padding") ?? 12
    }

    var listItemHorizontalPadding: CGFloat {
        extractSpacing(variable: "--list-item-horizontal-padding") ?? 12
    }

    var listItemSpacing: CGFloat {
        extractSpacing(variable: "--list-item-spacing") ?? 8
    }

    var headerPaddingVertical: CGFloat {
        extractSpacing(variable: "--header-padding-vertical") ?? 12
    }

    var headerPaddingHorizontal: CGFloat {
        extractSpacing(variable: "--header-padding-horizontal") ?? 12
    }

    var metaSpacing: CGFloat {
        extractSpacing(variable: "--meta-spacing") ?? 6
    }

    var borderRadius: CGFloat {
        extractSpacing(variable: "--border-radius") ?? 6
    }

    var borderRadiusLarge: CGFloat {
        extractSpacing(variable: "--border-radius-lg") ?? 8
    }

    var opacitySecondary: Double {
        extractOpacity(variable: "--opacity-secondary") ?? 0.6
    }

    // MARK: - CSS Extraction Helpers

    private func extractColor(variable: String) -> Color? {
        guard let cssContent = loadThemeCSS() else {
            return nil
        }

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

    private func extractFontSize(variable: String) -> CGFloat? {
        guard let cssContent = loadThemeCSS() else { return nil }

        let pattern = variable + "\\s*:\\s*([0-9]+)px"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsString = cssContent as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: cssContent, range: range) else { return nil }

        guard let sizeRange = Range(match.range(at: 1), in: cssContent) else { return nil }
        return CGFloat(Int(cssContent[sizeRange]) ?? 0)
    }

    private func extractSpacing(variable: String) -> CGFloat? {
        guard let cssContent = loadThemeCSS() else { return nil }

        let pattern = variable + "\\s*:\\s*([0-9]+)px"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsString = cssContent as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: cssContent, range: range) else { return nil }

        guard let spacingRange = Range(match.range(at: 1), in: cssContent) else { return nil }
        return CGFloat(Int(cssContent[spacingRange]) ?? 0)
    }

    private func extractOpacity(variable: String) -> Double? {
        guard let cssContent = loadThemeCSS() else { return nil }

        let pattern = variable + "\\s*:\\s*([0-9]\\.[0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsString = cssContent as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: cssContent, range: range) else { return nil }

        guard let opacityRange = Range(match.range(at: 1), in: cssContent) else { return nil }
        return Double(cssContent[opacityRange])
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
