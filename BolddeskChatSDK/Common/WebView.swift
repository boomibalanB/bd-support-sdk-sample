import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    
    let html: String
    @Binding var contentHeight: CGFloat
    var shouldAddIcon: Bool
    var onIconTap: ((CGPoint) -> Void)?
    
    @Environment(\.colorScheme) var colorScheme
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "iconTapped")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        
        let themeCSS = generateThemeCSS()
        
        let infoIconScript = shouldAddIcon ? generateIconScript() : ""
        
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                \(themeCSS)
            </style>
        </head>
        <body>
        
        <div id="content">
        \(html)
        </div>
        
        \(infoIconScript)
        
        </body>
        </html>
        """
        
        uiView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
    
    // MARK: - Theme CSS
    
    private func generateThemeCSS() -> String {
        
        let theme = ThemeManager.shared.currentTheme
        
        switch theme {
            
        case .light:
            return baseCSS(
                textColor: "#000000",
                backgroundColor: "transparent"
            )
            
        case .dark:
            return baseCSS(
                textColor: "#FFFFFF",
                backgroundColor: "transparent"
            )
            
        case .system:
            return """
            \(baseCSS(
                textColor: colorScheme == .dark ? "#FFFFFF" : "#000000",
                backgroundColor: "transparent"
            ))
            
            @media (prefers-color-scheme: dark) {
                body {
                    color: #FFFFFF;
                }
            }
            """
        }
    }
    
    private func baseCSS(textColor: String,
                         backgroundColor: String) -> String {
        """
        body {
            margin: 0;
            padding: 0;
            background: \(backgroundColor);
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            color: \(textColor);
            -webkit-tap-highlight-color: transparent;
        }
        
        #content {
            pointer-events: none;
            -webkit-user-select: none;
            user-select: none;
        }
        
        .info-icon {
            pointer-events: auto;
            display: inline;
            margin-left: 4px;
            font-size: 1em;
            font-weight: 700;
            color: \(textColor);
            cursor: pointer;
        
            -webkit-tap-highlight-color: transparent;
            -webkit-user-select: none;
            user-select: none;
        }
        
        * {
            -webkit-touch-callout: none;
        }
        """
    }
    
    // MARK: - Icon Script
    
    private func generateIconScript() -> String {
        """
        <script>
        function createIcon() {
            const infoIcon = document.createElement("span");
            infoIcon.className = "info-icon";
            infoIcon.innerHTML = "&#9432;";
        
            infoIcon.addEventListener("click", function(event) {
                event.preventDefault();
                event.stopPropagation();
        
                const rect = infoIcon.getBoundingClientRect();
        
                window.webkit.messageHandlers.iconTapped.postMessage({
                    x: rect.left,
                    y: rect.top
                });
            });
        
            return infoIcon;
        }
        
        function addInfoIcon() {
            const container = document.getElementById("content");
        
            if (container.querySelector(".info-icon")) return;
        
            const topLevelElements = Array.from(container.children)
                .filter(el => el.textContent.trim() !== "");
        
            if (topLevelElements.length === 0) return;
        
            const lastTopElement = topLevelElements[topLevelElements.length - 1];
        
            const codeBlock = lastTopElement.querySelector("pre, code");
            if (codeBlock) {
                codeBlock.appendChild(createIcon());
                return;
            }
        
            const link = lastTopElement.querySelector("a");
            if (link) {
                link.insertAdjacentElement("afterend", createIcon());
                return;
            }
        
            lastTopElement.appendChild(createIcon());
        }
        
        document.addEventListener("DOMContentLoaded", addInfoIcon);
        </script>
        """
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                    if let number = result as? NSNumber {
                        DispatchQueue.main.async {
                            self.parent.contentHeight = CGFloat(truncating: number)
                        }
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            
            guard message.name == "iconTapped",
                  let body = message.body as? [String: Any],
                  let x = body["x"] as? NSNumber,
                  let y = body["y"] as? NSNumber,
                  let webView = message.webView else { return }
            
            let webPoint = CGPoint(
                x: CGFloat(truncating: x),
                y: CGFloat(truncating: y)
            )
            
            DispatchQueue.main.async {
                let screenPoint = webView.convert(webPoint, to: nil)
                self.parent.onIconTap?(screenPoint)
            }
        }
    }
}
