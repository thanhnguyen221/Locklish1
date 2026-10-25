import SwiftUI
import WebKit

// MARK: - YouTubePlayerView
/// WKWebView wrapper around YouTube's mobile watch page.
///
/// YouTube's /embed/ (IFrame API) player refuses to run inside app webviews
/// ("Video player configuration error", error 152/153), so instead we load the
/// regular watch page — which plays everywhere — hide its header chrome, and
/// hook the underlying <video> element to stream playback time and play state
/// back to SwiftUI for subtitle sync.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @Binding var seekRequest: Double?
    var onEmbedError: ((Int) -> Void)? = nil
    var onPlayerReady: (() -> Void)? = nil
    var onVideoAspectRatio: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "timeUpdate")
        contentController.add(context.coordinator, name: "stateChange")
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "playerError")
        contentController.add(context.coordinator, name: "videoSize")

        contentController.addUserScript(
            WKUserScript(source: Self.chromeHidingScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        contentController.addUserScript(
            WKUserScript(source: Self.videoHookScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        loadVideo(videoId: videoId, into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.currentVideoId != videoId {
            context.coordinator.currentVideoId = videoId
            loadVideo(videoId: videoId, into: uiView)
        }

        if let targetTime = seekRequest {
            uiView.evaluateJavaScript(Self.seekScript(time: targetTime))
            DispatchQueue.main.async {
                self.seekRequest = nil
            }
        }
    }

    private func loadVideo(videoId: String, into webView: WKWebView) {
        let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        webView.load(URLRequest(url: url))
    }

    // MARK: - Injected JavaScript

    /// Hides ALL of YouTube's chrome — header, player controls (progress bar, CC,
    /// settings, fullscreen), built-in captions and overlays — leaving only the clean
    /// video picture on the black canvas. The app renders its own transcript below.
    /// The <video> element is pinned to fill the player container with object-fit
    /// "contain": it can never be distorted (worst case it letterboxes), which fixes
    /// the squeezed-frame issue on videos whose ratio differs from 16:9.
    /// Also hides YouTube's built-in captions since we display our own transcript.
    private static let chromeHidingScript = """
    (function() {
        var style = document.createElement('style');
        style.textContent = [
            '#masthead, #masthead-container, #header, ytm-alert-banner,',
            '.mobile-topbar-header, #related, ytm-comments-header,',
            'ytm-slim-video-metadata-renderer, .slim-video-metadata-title,',
            'ytm-single-column-watch-next-results, .ytp-title,',
            '.ytp-title-text, .ytp-title-channel,',
            /* Full player chrome: controls, progress bar, CC & settings buttons */
            '.ytp-chrome-bottom, .ytp-chrome-top, .ytp-gradient-bottom,',
            '.ytp-gradient-top, .ytp-button.ytp-subtitles-button,',
            '.ytp-settings-button, .ytp-fullscreen-button, .ytp-size-button,',
            '.ytp-multicam-button, .ytp-remote-button, .ytp-paid-content-overlay,',
            /* YouTube's own caption rendering */
            '.ytp-caption-window-container, .caption-window,',
            '#ytp-caption-window-container, .caption-visual-line,',
            '.ytp-caption-segment, .caption-visual-line-container',
            '{ display: none !important; }',
            'html, body { margin: 0 !important; padding: 0 !important; width: 100% !important; height: 100% !important; overflow: hidden !important; background: #000 !important; }',
            '#movie_player, .html5-video-player {',
            '  width: 100vw !important; height: 100vh !important;',
            '  max-height: none !important; top: 0 !important; left: 0 !important;',
            '  overflow: hidden !important;',
            '}',
            /* Never distort the picture: the native container is already sized to
               the true video aspect, so "contain" renders it pixel-perfect. */
            'video.html5-main-video, .html5-video-player video {',
            '  width: 100% !important; height: 100% !important;',
            '  object-fit: contain !important; top: 0 !important; left: 0 !important;',
            '}'
        ].join(' ');
        document.documentElement.appendChild(style);
        setTimeout(function() { window.scrollTo(0, 0); }, 600);
        setTimeout(function() { window.scrollTo(0, 0); }, 2000);
    })();
    """

    /// The <video> element is created by YouTube's own JS after page load,
    /// so poll for it and attach listeners as soon as it appears. While the
    /// video plays, sample `currentTime` from the browser animation loop. The
    /// native `timeupdate` event is typically only about 4 Hz, which is too
    /// coarse for word-by-word subtitle tracking.
    private static let videoHookScript = """
    (function() {
        var post = function(name, body) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
                window.webkit.messageHandlers[name].postMessage(body);
            }
        };
        var attachedVideo = null;
        var frameRequest = null;
        var lastSentTime = -1;
        var lastSentAt = 0;
        var sampleTime = function(force) {
            if (!attachedVideo) return;
            var now = performance.now();
            var time = attachedVideo.currentTime || 0;
            // ~6 samples/sec: the Swift side extrapolates between samples
            // (projectedTime), so a higher rate only burns main-thread cycles
            // and causes SwiftUI churn. Seeks & state changes force through.
            if (force || Math.abs(time - lastSentTime) >= 0.15 || now - lastSentAt >= 170) {
                lastSentTime = time;
                lastSentAt = now;
                post('timeUpdate', time);
            }
        };
        var trackFrame = function() {
            sampleTime(false);
            if (attachedVideo && !attachedVideo.paused && !attachedVideo.ended) {
                frameRequest = requestAnimationFrame(trackFrame);
            } else {
                frameRequest = null;
            }
        };
        var startFrameTracking = function() {
            if (frameRequest === null) frameRequest = requestAnimationFrame(trackFrame);
        };
        var postVideoSize = function() {
            if (!attachedVideo || !attachedVideo.videoWidth || !attachedVideo.videoHeight) return;
            post('videoSize', {
                width: attachedVideo.videoWidth,
                height: attachedVideo.videoHeight
            });
        };
        var disableYouTubeCaptions = function() {
            // NEVER use toggleSubtitles(): toggling a disabled caption track would
            // turn YouTube's captions ON, polluting the video with duplicate text.
            var player = document.getElementById('movie_player');
            if (player && player.setOption) {
                try {
                    player.setOption('captions', 'track', {});
                } catch(e) {}
            }
            // Disable all text tracks on the video element
            if (attachedVideo && attachedVideo.textTracks) {
                for (var i = 0; i < attachedVideo.textTracks.length; i++) {
                    attachedVideo.textTracks[i].mode = 'hidden';
                }
            }
        };
        setInterval(function() {
            var v = document.querySelector('video.html5-main-video') || document.querySelector('video');
            if (!v || v === attachedVideo) return;
            if (frameRequest !== null) cancelAnimationFrame(frameRequest);
            attachedVideo = v;
            post('playerReady', 1);
            sampleTime(true);
            post('stateChange', !v.paused);
            postVideoSize();
            disableYouTubeCaptions();
            v.addEventListener('timeupdate', function() { sampleTime(false); });
            v.addEventListener('seeked', function() { sampleTime(true); });
            v.addEventListener('loadedmetadata', postVideoSize);
            v.addEventListener('playing', function() { post('stateChange', true); sampleTime(true); startFrameTracking(); disableYouTubeCaptions(); });
            v.addEventListener('play', function() { post('stateChange', true); startFrameTracking(); });
            v.addEventListener('pause', function() { sampleTime(true); post('stateChange', false); });
            v.addEventListener('ended', function() { sampleTime(true); post('stateChange', false); });
            v.addEventListener('error', function() { post('playerError', 5); });
            if (!v.paused) startFrameTracking();
        }, 300);
    })();
    """

    private static func seekScript(time: Double) -> String {
        """
        (function() {
            var p = document.getElementById('movie_player');
            if (p && p.seekTo) { p.seekTo(\(time), true); return; }
            var v = document.querySelector('video');
            if (v) { v.currentTime = \(time); }
        })();
        """
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: YouTubePlayerView
        weak var webView: WKWebView?
        var currentVideoId: String = ""

        init(_ parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoId = parent.videoId
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "timeUpdate":
                // JavaScript numbers cross the WebKit bridge as NSNumber.
                // Reading the value explicitly avoids optional Bool/number
                // bridging issues and accepts integer timestamps too.
                if let number = message.body as? NSNumber {
                    let time = number.doubleValue
                    DispatchQueue.main.async {
                        // No animation here: the view model projects the time
                        // continuously between ticks, which keeps the karaoke
                        // underline locked to the audio.
                        self.parent.currentTime = time
                    }
                }
            case "stateChange":
                if let number = message.body as? NSNumber {
                    let isPlaying = number.boolValue
                    DispatchQueue.main.async {
                        self.parent.isPlaying = isPlaying
                    }
                }
            case "playerReady":
                DispatchQueue.main.async {
                    self.parent.onPlayerReady?()
                }
            case "videoSize":
                if let size = message.body as? [String: Any],
                   let width = (size["width"] as? NSNumber)?.doubleValue,
                   let height = (size["height"] as? NSNumber)?.doubleValue,
                   width > 0, height > 0 {
                    DispatchQueue.main.async {
                        self.parent.onVideoAspectRatio?(CGFloat(width / height))
                    }
                }
            case "playerError":
                if let code = message.body as? Int {
                    DispatchQueue.main.async {
                        self.parent.onEmbedError?(code)
                    }
                }
            default:
                break
            }
        }

        // MARK: WKNavigationDelegate (in-app playback guard)
        /// Keep the player locked to the video being studied: the watch page
        /// for the current videoId is allowed, but any other main-frame jump
        /// (related videos, "Watch on YouTube", channel links) is cancelled.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard navigationAction.targetFrame?.isMainFrame == true,
                  let url = navigationAction.request.url
            else { return .allow }

            let host = url.host?.lowercased() ?? ""

            if host.contains("consent.") || host.hasSuffix("accounts.google.com") {
                return .allow
            }

            if host.hasSuffix("youtube.com") || host.hasSuffix("youtu.be") || host.hasSuffix("youtube-nocookie.com") {
                let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let requestedId = query?.first(where: { $0.name == "v" })?.value
                let isCurrentVideo = url.path == "/watch" && requestedId == currentVideoId
                return isCurrentVideo ? .allow : .cancel
            }
            return .allow
        }
    }
}
