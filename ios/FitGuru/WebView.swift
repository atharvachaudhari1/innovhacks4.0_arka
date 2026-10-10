import SwiftUI
import WebKit
import AVFoundation

struct WebView: UIViewRepresentable {
    @Binding var reloadTrigger: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // Register native bridge handler
        configuration.userContentController.add(context.coordinator, name: "nativeBridge")

        // Inject native-ios early at document start
        let userScript = WKUserScript(
            source: "document.documentElement.classList.add('native-ios'); document.addEventListener('DOMContentLoaded', () => { document.body.classList.remove('frame-mode'); document.body.classList.add('native-ios'); });",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false

        // Append custom user agent
        let currentUA = webView.customUserAgent ?? ""
        webView.customUserAgent = currentUA + " FitGuru-iOS/1.0"

        context.coordinator.loadContent(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if reloadTrigger {
            context.coordinator.loadContent(in: uiView)
            DispatchQueue.main.async {
                self.reloadTrigger = false
            }
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeBridge")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func loadContent(in webView: WKWebView) {
            // First check for bundled Web folder
            if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
                let webFolderURL = indexURL.deletingLastPathComponent()
                _ = webView.loadFileURL(indexURL, allowingReadAccessTo: webFolderURL)
                return
            }
            
            // Check flat resource index.html
            if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") {
                let resourceURL = Bundle.main.resourceURL ?? indexURL.deletingLastPathComponent()
                _ = webView.loadFileURL(indexURL, allowingReadAccessTo: resourceURL)
                return
            }

            // Fallback to local server if running
            if let serverURL = URL(string: "http://localhost:3000") {
                let request = URLRequest(url: serverURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
                _ = webView.load(request)
            }
        }

        // Handle iOS 15+ media capture permission (Camera / Mic for MediaPipe)
        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        private let speechSynthesizer = AVSpeechSynthesizer()

        // Native Bridge: Haptics & Messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "nativeBridge",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            if action == "haptic" {
                let hapticType = body["type"] as? String ?? "impact"
                DispatchQueue.main.async {
                    switch hapticType {
                    case "success":
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    case "warning":
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                    default:
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
            } else if action == "speak" {
                let text = body["text"] as? String ?? ""
                guard !text.isEmpty else { return }
                DispatchQueue.main.async {
                    self.speechSynthesizer.stopSpeaking(at: .immediate)
                    let utterance = AVSpeechUtterance(string: text)
                    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                    utterance.rate = 0.50
                    self.speechSynthesizer.speak(utterance)
                }
            } else if action == "log" {
                let msg = body["message"] as? String ?? ""
                print("[WebLog] \(msg)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView didFail: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView didFailProvisionalNavigation: \(error.localizedDescription)")
            // Fallback to localhost if bundle failed
            if let serverURL = URL(string: "http://localhost:3000") {
                webView.load(URLRequest(url: serverURL))
            }
        }
    }
}
