import SwiftUI
import WebKit
import Markdown

/// Full block-level Markdown parsing via Apple's swift-markdown package.
/// Preview HTML is local-only; scripts and remote navigation are disabled.
struct MarkdownPreviewView: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastSource != source else { return }
        context.coordinator.lastSource = source
        let content = HTMLRenderer.render(Document(parsing: source))
        let css = """
        :root { color-scheme: light dark; }
        body { font: 15px -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.55;
               color: #202124; background: #fff; margin: 24px 30px; overflow-wrap: anywhere; }
        h1,h2,h3,h4,h5,h6 { line-height: 1.25; margin: 1.3em 0 .5em; }
        h1 { font-size: 2em; border-bottom: 1px solid #ddd; padding-bottom: .25em; }
        h2 { font-size: 1.55em; border-bottom: 1px solid #ddd; padding-bottom: .2em; }
        h3 { font-size: 1.3em; } h4 { font-size: 1.12em; } h5 { font-size: 1em; } h6 { font-size: .9em; color: #666; }
        p { margin: .65em 0; } li { margin: .25em 0; } ul,ol { padding-left: 1.8em; }
        pre { padding: 12px; overflow-x: auto; border-radius: 6px; background: #f2f3f5; }
        code { font-family: ui-monospace, Menlo, monospace; font-size: .9em; }
        :not(pre)>code { background: #f2f3f5; padding: 2px 4px; border-radius: 3px; }
        blockquote { margin-left: 0; padding-left: 15px; border-left: 3px solid #aaa; color: #666; }
        hr { border: 0; border-top: 1px solid #ccc; margin: 22px 0; }
        table { border-collapse: collapse; width: 100%; } th,td { border: 1px solid #ccc; padding: 6px 10px; }
        a { color: #1769aa; } img { max-width: 100%; }
        @media(prefers-color-scheme: dark) {
          body { background: #1e1e1e; color: #e8e8e8; } h1,h2 { border-color: #555; }
          pre,:not(pre)>code { background: #303035; } blockquote,h6 { color: #aaa; }
          hr,th,td { border-color: #555; } a { color: #78baff; }
        }
        """
        let html = """
        <!doctype html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>\(css)</style></head><body>\(content)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastSource: String?
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url, ["http", "https", "mailto"].contains(url.scheme ?? "") {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}

private enum HTMLRenderer {
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func render(_ node: Markup) -> String {
        let inner = node.children.map { render($0) }.joined()
        switch node {
        case let heading as Heading: return "<h\(heading.level)>\(inner)</h\(heading.level)>"
        case is Paragraph: return "<p>\(inner)</p>"
        case let text as Markdown.Text: return escape(text.string)
        case is Strong: return "<strong>\(inner)</strong>"
        case is Emphasis: return "<em>\(inner)</em>"
        case let code as InlineCode: return "<code>\(escape(code.code))</code>"
        case let block as CodeBlock: return "<pre><code>\(escape(block.code))</code></pre>"
        case is UnorderedList: return "<ul>\(inner)</ul>"
        case is OrderedList: return "<ol>\(inner)</ol>"
        case is ListItem: return "<li>\(inner)</li>"
        case is BlockQuote: return "<blockquote>\(inner)</blockquote>"
        case is ThematicBreak: return "<hr>"
        case let link as Markdown.Link:
            let url = link.destination ?? ""
            let safe = ["http://", "https://", "mailto:"].contains(where: { url.lowercased().hasPrefix($0) }) ? url : "#"
            return """
            <a href="\(escape(safe))">\(inner)</a>
            """
        case let image as Markdown.Image:
            let url = image.source ?? ""
            let safe = ["https://", "http://"].contains(where: { url.lowercased().hasPrefix($0) }) ? url : ""
            return """
            <img src="\(escape(safe))" alt="\(escape(inner))">
            """
        case is SoftBreak: return "\n"
        case is LineBreak: return "<br>"
        default: return inner
        }
    }
}
