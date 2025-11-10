//
//  Theme.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import SwiftUI

enum ThemeStyle {
    case light
    case dark
    case sepia

    var name: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        }
    }

    var cssFileName: String {
        switch self {
        case .light: return "variables-light"
        case .dark: return "variables-dark"
        case .sepia: return "variables-sepia"
        }
    }
}

struct Theme {
    let style: ThemeStyle

    // Computed filename for loading theme CSS
    var variablesFileName: String {
        return style.cssFileName
    }
}
