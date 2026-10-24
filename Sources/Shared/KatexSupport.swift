import Foundation

/// KaTeX'i belgeye gömer. Yazı tipleri `katex.css` içinde base64'tür;
/// önizleme ağ olmadan formül çizer. Dosyalar yoksa LaTeX kaynağı görünür kalır.
enum KatexSupport {

    struct Injection {
        var css: String
        var script: String
        static let empty = Injection(css: "", script: "")
    }

    private static let cached: (css: String, js: String)? = load()

    static func injection(forHTML html: String) -> Injection {
        guard html.contains("mp-math"), let assets = cached else { return .empty }
        let script = """
        <script>\(assets.js)</script>
        <script>
        function mpRenderMath() {
          if (!window.katex) return;
          var nodes = document.querySelectorAll(".mp-math");
          for (var i = 0; i < nodes.length; i++) {
            var el = nodes[i];
            var tex = el.getAttribute("data-tex");
            if (!tex) continue;
            try {
              katex.render(tex, el, {
                displayMode: el.getAttribute("data-display") === "true",
                throwOnError: false
              });
            } catch (e) {}
          }
        }
        document.addEventListener("DOMContentLoaded", mpRenderMath);
        mpRenderMath();
        </script>
        """
        return Injection(css: assets.css, script: script)
    }

    private static func load() -> (css: String, js: String)? {
        let bundles = [Bundle(for: KatexBundleToken.self), Bundle.main]
        func find(_ name: String, _ ext: String) -> URL? {
            for bundle in bundles {
                if let url = bundle.url(forResource: name, withExtension: ext) { return url }
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "KaTeX") { return url }
            }
            return nil
        }
        guard let cssURL = find("katex", "css"),
              let jsURL = find("katex.min", "js"),
              var css = try? String(contentsOf: cssURL, encoding: .utf8),
              var js = try? String(contentsOf: jsURL, encoding: .utf8) else { return nil }
        css = css.replacingOccurrences(of: "</style", with: "<\\/style", options: .caseInsensitive)
        js = js.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
        return (css, js)
    }
}

private final class KatexBundleToken {}

enum HTMLPatch {
    struct Parts {
        var shell: String
        var body: String
    }

    static func parts(of html: String) -> Parts? {
        let start = "<!--MP_CONTENT-->"
        let end = "<!--/MP_CONTENT-->"
        guard let s = html.range(of: start), let e = html.range(of: end), s.upperBound <= e.lowerBound else {
            return nil
        }
        let shell = String(html[..<s.lowerBound]) + String(html[e.upperBound...])
        let body = String(html[s.upperBound..<e.lowerBound])
        return Parts(shell: shell, body: body)
    }

    static func script(replacingBody body: String) -> String? {
        guard let data = try? JSONEncoder().encode(body),
              let literal = String(data: data, encoding: .utf8) else { return nil }
        return """
        (function(){
          var y = window.scrollY;
          var node = document.getElementById('content');
          if (!node) return;
          node.innerHTML = \(literal);
          window.scrollTo(0, y);
          if (window.mpRenderMath) window.mpRenderMath();
        })();
        """
    }
}
