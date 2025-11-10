//
//  ArticleWebView.swift
//  RichRSS
//
//  Created by Rich Tape on 2025-11-08.
//

import SwiftUI
import WebKit

struct ArticleWebView: UIViewRepresentable {
    let article: Article
    let theme: Theme
    let articleLink: String?
    var onPanChanged: ((CGFloat) -> Void)?
    var onGestureEnded: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> WebViewContainer {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.indicatorStyle = .default
        webView.isOpaque = false

        let container = WebViewContainer(webView: webView)
        container.onPanChanged = onPanChanged
        container.onGestureEnded = onGestureEnded

        return container
    }

    func updateUIView(_ container: WebViewContainer, context: Context) {
        // Only reload HTML if the article has changed
        if container.currentArticleId != article.uniqueId {
            // Try to get cached HTML first
            let htmlContent: String
            if let cachedHTML = ArticleHTMLCache.shared.getCachedHTML(for: article) {
                htmlContent = cachedHTML
            } else {
                // Generate and cache the HTML
                htmlContent = generateHTMLContent()
                ArticleHTMLCache.shared.cacheHTML(htmlContent, for: article)
            }

            container.webView.loadHTMLString(htmlContent, baseURL: nil)
            container.currentArticleId = article.uniqueId
        }

        // Always update the callbacks so they have the latest closures
        container.onPanChanged = onPanChanged
        container.onGestureEnded = onGestureEnded
    }

    private func generateHTMLContent() -> String {
        // Get raw HTML content from the article
        let content = article.content ?? article.summary

        // Remove dangerous script and style tags
        var cleanContent = content
        cleanContent = cleanContent.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleanContent = cleanContent.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Build link HTML if we have an article link
        var linkHTML = ""
        if let link = articleLink {
            linkHTML = """
            <hr>
            <p style="margin-top: 2em; text-align: center;">
                <a href="\(link)" style="font-weight: bold; font-size: 1.1em; color: var(--accent-color); text-decoration: none; border: none;">Read original →</a>
            </p>
            """
        }

        // Load CSS files from bundle
        let themeVariablesCSS = loadCSS(filename: theme.variablesFileName) ?? ""
        let articleCSS = loadCSS(filename: "article") ?? ""

        // Build HTML document with our CSS
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            \(themeVariablesCSS)
            \(articleCSS)
            </style>
        </head>
        <body>
            <h1>\(escapeHTML(article.title))</h1>
            \(cleanContent)
            \(linkHTML)
        </body>
        </html>
        """

        return html
    }

    private func loadCSS(filename: String) -> String? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "css") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - WebViewContainer
class WebViewContainer: UIView {
    let webView: WKWebView
    var onPanChanged: ((CGFloat) -> Void)?
    var onGestureEnded: ((CGFloat) -> Void)?  // Pass final translation value
    var currentArticleId: String?  // Track which article is currently loaded
    private var isHorizontalPan = false
    private var initialLocation: CGPoint = .zero

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Add pan gesture recognizer for swipe detection
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        print("WebViewContainer: Pan gesture recognizer added")
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)

        // Determine direction on first significant move
        if gesture.state == .began {
            initialLocation = gesture.location(in: self)
            isHorizontalPan = false
            return
        }

        if gesture.state == .changed {
            // Determine if this is horizontal or vertical on first meaningful movement
            if !isHorizontalPan && (abs(translation.x) > 10 || abs(translation.y) > 10) {
                let isHorizontal = abs(translation.x) > abs(translation.y)
                isHorizontalPan = isHorizontal

                if isHorizontal {
                    // Horizontal pan - disable vertical scroll
                    webView.scrollView.isScrollEnabled = false
                } else {
                    // Vertical pan - let webView handle it
                    return
                }
            }

            // Report translation if horizontal pan detected
            if isHorizontalPan {
                onPanChanged?(translation.x)
            }
            return
        }

        // On gesture end, re-enable scrolling and report final translation
        if gesture.state == .ended || gesture.state == .cancelled {
            webView.scrollView.isScrollEnabled = true

            // Only report gesture end if it was a horizontal pan
            if isHorizontalPan {
                onGestureEnded?(translation.x)
            }
        }
    }
}

extension WebViewContainer: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
