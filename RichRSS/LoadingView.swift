//
//  LoadingView.swift
//  RichRSS
//
//  Created by Claude on 2025-11-13.
//

import SwiftUI

/// A splash/loading screen shown during app startup
struct LoadingView: View {
    let theme: Theme
    let statusMessage: String

    var body: some View {
        ZStack {
            // Background
            theme.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App Icon / Logo
                VStack(spacing: 12) {
                    Image(systemName: "newspaper.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(theme.accentColor)

                    Text("RichRSS")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.textColor)
                }

                Spacer()

                // Loading spinner and message
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(theme.accentColor)
                        .scaleEffect(1.2, anchor: .center)

                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    LoadingView(
        theme: Theme(style: .light),
        statusMessage: "Refreshing feeds..."
    )
}

#Preview {
    LoadingView(
        theme: Theme(style: .dark),
        statusMessage: "Loading articles..."
    )
}
