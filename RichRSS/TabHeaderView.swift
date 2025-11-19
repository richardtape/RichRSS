//
//  TabHeaderView.swift
//  RichRSS
//
//  Created by Claude on 2025-11-11.
//

import SwiftUI

/// Unified header component for all tabs
/// Provides consistent alignment and spacing across Articles, Feeds, and Settings tabs
struct TabHeaderView: View {
    let title: String
    let trailingContent: (() -> AnyView)?

    init(_ title: String, trailing: (() -> AnyView)? = nil) {
        self.title = title
        self.trailingContent = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .appFont(.largeTitle, weight: .bold)

            Spacer()

            if let trailingContent = trailingContent {
                trailingContent()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        TabHeaderView("All Feeds") {
            AnyView(
                Menu {
                    Button("Option 1") {}
                    Button("Option 2") {}
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.blue)
                }
            )
        }
        Spacer()
    }
}
