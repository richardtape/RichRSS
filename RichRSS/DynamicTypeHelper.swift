//
//  DynamicTypeHelper.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-19.
//

import SwiftUI
import UIKit

/// Helper class for managing Dynamic Type scaling across the app
/// Converts iOS's UIContentSizeCategory to scale factors for consistent sizing
class DynamicTypeHelper {

    /// Get the current Dynamic Type scale factor based on user's iOS text size preference
    /// Combined with optional in-app multiplier
    /// - Parameter inAppMultiplier: Optional app-specific multiplier (default: 1.0). Use nil to read from AppStorage.
    /// - Returns: Scale factor from 0.82 (smallest) to 3.12+ (largest accessibility size) × in-app multiplier
    static func getCurrentScaleFactor(inAppMultiplier: CGFloat? = nil) -> CGFloat {
        let contentSize = UIApplication.shared.preferredContentSizeCategory
        let systemScale = scaleFactor(for: contentSize)

        // Apply in-app multiplier if provided, otherwise read from storage
        let multiplier = inAppMultiplier ?? getInAppFontSizeMultiplier()
        return systemScale * multiplier
    }

    /// Get the in-app font size multiplier from UserDefaults
    /// - Returns: Multiplier value (0.85, 1.0, 1.15, or 1.3)
    private static func getInAppFontSizeMultiplier() -> CGFloat {
        return UserDefaults.standard.double(forKey: "inAppFontSizeMultiplier") == 0
            ? 1.0 // Default if not set
            : UserDefaults.standard.double(forKey: "inAppFontSizeMultiplier")
    }

    /// Convert a UIContentSizeCategory to a numeric scale factor
    /// - Parameter category: The content size category to convert
    /// - Returns: Scale factor relative to the default "Large" size (1.0)
    static func scaleFactor(for category: UIContentSizeCategory) -> CGFloat {
        switch category {
        // Standard sizes
        case .extraSmall: return 0.82
        case .small: return 0.88
        case .medium: return 0.94
        case .large: return 1.0  // Default
        case .extraLarge: return 1.12
        case .extraExtraLarge: return 1.24
        case .extraExtraExtraLarge: return 1.35

        // Accessibility sizes
        case .accessibilityMedium: return 1.60
        case .accessibilityLarge: return 1.90
        case .accessibilityExtraLarge: return 2.35
        case .accessibilityExtraExtraLarge: return 2.75
        case .accessibilityExtraExtraExtraLarge: return 3.12

        default: return 1.0
        }
    }

    /// Generate CSS that applies Dynamic Type scaling to font size variables
    /// - Parameter scaleFactor: The scale factor to apply
    /// - Returns: CSS string that overrides font-size variables with scaled values
    static func generateFontScaleCSS(scaleFactor: CGFloat) -> String {
        return """
        :root {
            --dynamic-type-scale: \(scaleFactor);

            /* Apply Dynamic Type scale to all font sizes */
            --font-size-title: calc(31px * var(--dynamic-type-scale));
            --font-size-title2: calc(24px * var(--dynamic-type-scale));
            --font-size-headline: calc(20px * var(--dynamic-type-scale));
            --font-size-body: calc(18px * var(--dynamic-type-scale));
            --font-size-subheadline: calc(17px * var(--dynamic-type-scale));
            --font-size-caption: calc(15px * var(--dynamic-type-scale));
            --font-size-caption2: calc(14px * var(--dynamic-type-scale));
        }
        """
    }

    /// Get a unique identifier for the current content size category
    /// Useful for cache invalidation when text size changes
    /// - Returns: String identifier for the current size category
    static func getCurrentSizeCategoryIdentifier() -> String {
        return UIApplication.shared.preferredContentSizeCategory.rawValue
    }
}

/// SwiftUI Environment key for tracking Dynamic Type scale factor
struct DynamicTypeScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var dynamicTypeScale: CGFloat {
        get { self[DynamicTypeScaleKey.self] }
        set { self[DynamicTypeScaleKey.self] = newValue }
    }
}

/// View modifier that observes Dynamic Type changes and updates the environment
struct DynamicTypeScaleModifier: ViewModifier {
    @State private var scaleFactor: CGFloat = DynamicTypeHelper.getCurrentScaleFactor()
    @AppStorage("inAppFontSizeMultiplier") private var inAppFontSizeMultiplier: Double = 1.0

    func body(content: Content) -> some View {
        content
            .environment(\.dynamicTypeScale, scaleFactor)
            .onReceive(NotificationCenter.default.publisher(
                for: UIContentSizeCategory.didChangeNotification
            )) { _ in
                // System Dynamic Type changed
                scaleFactor = DynamicTypeHelper.getCurrentScaleFactor()
            }
            .onChange(of: inAppFontSizeMultiplier) { _, _ in
                // In-app multiplier changed
                scaleFactor = DynamicTypeHelper.getCurrentScaleFactor()
            }
            .onAppear {
                // Ensure we have the latest scale on first appearance
                scaleFactor = DynamicTypeHelper.getCurrentScaleFactor()
            }
    }
}

extension View {
    /// Apply Dynamic Type scale tracking to this view and its descendants
    /// This makes the current scale factor available via @Environment(\.dynamicTypeScale)
    func trackDynamicTypeScale() -> some View {
        self.modifier(DynamicTypeScaleModifier())
    }
}
