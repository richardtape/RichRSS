//
//  PullToRefreshView.swift
//  RichRSS
//
//  Created by Claude on 2025-11-11.
//

import SwiftUI

/// Custom pull-to-refresh indicator that displays above a scrollable list
/// Provides visual feedback as user drags and haptic feedback when threshold is crossed
struct PullToRefreshHeader: View {
    let pullDistance: CGFloat  // How far user has pulled (0 at top, increases as they drag down)
    let isRefreshing: Bool
    let threshold: CGFloat     // Distance needed to trigger refresh (typically 80)

    var rotationAngle: Double {
        // Icon rotates from 0° to 180° as user pulls from 0 to threshold
        // Then spins continuously during refresh
        isRefreshing ? 360 : min(180, (pullDistance / threshold) * 180)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Animated arrow icon
            Image(systemName: "arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(rotationAngle))
                .animation(
                    isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .easeOut(duration: 0.3),
                    value: pullDistance
                )
                .opacity(pullDistance > 10 ? 1 : 0.3)

            // Status text
            if isRefreshing {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(.blue)
                        .scaleEffect(0.8)
                    Text("Refreshing...")
                        .appFont(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(pullDistance > threshold ? "Release to refresh" : "Pull to refresh")
                    .appFont(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(pullDistance > 10 ? 1 : 0)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

/// Wrapper that adds pull-to-refresh to a ScrollView
/// Usage:
/// ```
/// PullToRefreshContainer(onRefresh: {
///     // fetch articles
/// }) {
///     // your scrollable content here
/// }
/// ```
struct PullToRefreshContainer<Content: View>: View {
    let onRefresh: () async -> Void
    let content: () -> Content

    @State private var isRefreshing = false
    @State private var pullDistance: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var lastHapticTriggerDistance: CGFloat = 0

    let refreshThreshold: CGFloat = 60

    var body: some View {
        ZStack(alignment: .top) {
            // Pull-to-refresh header (above the scroll content)
            PullToRefreshHeader(
                pullDistance: pullDistance,
                isRefreshing: isRefreshing,
                threshold: refreshThreshold
            )
            .zIndex(1)

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Invisible tracker at top to measure pull distance
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                    }
                    .frame(height: 0)

                    content()
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                let newPullDistance = max(0, -offset)
                pullDistance = newPullDistance

                // Haptic feedback when crossing threshold (only once per pull)
                if pullDistance > refreshThreshold && !hasTriggeredHaptic && !isRefreshing {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    hasTriggeredHaptic = true
                } else if pullDistance <= refreshThreshold {
                    hasTriggeredHaptic = false
                }

                // Auto-trigger refresh when threshold crossed
                if pullDistance > refreshThreshold && !isRefreshing && !hasTriggeredHaptic {
                    Task {
                        await performRefresh()
                    }
                }
            }
        }
    }

    private func performRefresh() async {
        isRefreshing = true

        // Execute the refresh closure
        await onRefresh()

        // Animate reset
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                pullDistance = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isRefreshing = false
            }
        }
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    PullToRefreshContainer(
        onRefresh: {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    ) {
        VStack(spacing: 12) {
            ForEach(0..<10, id: \.self) { i in
                Text("Item \(i)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
