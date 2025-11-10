//
//  ThemeEnvironment.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-09.
//

import SwiftUI

struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(style: .light)
}

extension EnvironmentValues {
    var appTheme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func withTheme(_ theme: Theme) -> some View {
        environment(\.appTheme, theme)
    }
}
