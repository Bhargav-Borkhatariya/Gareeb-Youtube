import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../store/friend_store.dart';
import '../youtube/catalog.dart';
import 'stream_player_screen.dart';

/// YouTube's own player (same idea as Brave): 4K/adaptive from youtube.com.
/// Home/search stay native. Ad hosts are blocked; skip-ad is clicked in the page.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.catalog,
    required this.store,
    required this.video,
  });

  final YoutubeCatalog catalog;
  final FriendStore store;
  final VideoHit video;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  InAppWebViewController? _web;
  var _loading = true;
  late final List<ContentBlocker> _blockers;

  static const _chromeUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  static const _skipAdsJs = '''
(function() {
  if (window.__gareebSkip) return;
  window.__gareebSkip = true;
  setInterval(function() {
    var nodes = document.querySelectorAll(
      '.ytp-ad-skip-button, .ytp-skip-ad-button, .ytp-ad-skip-button-modern, '
      '.ytp-ad-overlay-close-button, .ytp-ad-overlay-close-container'
    );
    for (var i = 0; i < nodes.length; i++) { try { nodes[i].click(); } catch (e) {} }
    var player = document.querySelector('.ad-showing video, .ad-showing .html5-main-video');
    if (player) {
      try { player.currentTime = player.duration || 0; } catch (e) {}
    }
  }, 400);
})();
''';

  @override
  void initState() {
    super.initState();
    widget.store.addHistory(widget.video);
    _blockers = _contentBlockers();
  }

  List<ContentBlocker> _contentBlockers() {
    const filters = [
      r'.*.doubleclick.net/.*',
      r'.*.googlesyndication.com/.*',
      r'.*.googleadservices.com/.*',
      r'.*.googleads.g.doubleclick.net/.*',
      r'.*.adservice.google..*/.*',
      r'.*.pagead2.googlesyndication.com/.*',
      r'.*.youtube.com/pagead/.*',
      r'.*.youtube.com/ptracking.*',
      r'.*.youtube.com/api/stats/ads.*',
      r'.*.youtube.com/get_midroll.*',
      r'.*.youtube.com/youtubei/v1/player/ad.*',
      r'.*.ad.youtube.com/.*',
    ];
    final blockers = <ContentBlocker>[
      for (final filter in filters)
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: filter),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: '.*'),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector:
              '.ytp-ad-module, .video-ads, ytd-ad-slot-renderer, ytm-promoted-sparkles-web-renderer, .masthead-ad, #player-ads, ytd-banner-promo-renderer, .ytp-ad-overlay-container',
        ),
      ),
    ];
    return blockers;
  }

  bool _isAdRequest(String url) {
    final value = url.toLowerCase();
    const needles = [
      'doubleclick.net',
      'googlesyndication.com',
      'googleadservices.com',
      'pagead2.',
      '/pagead/',
      '/ptracking',
      'api/stats/ads',
      'get_midroll',
      'player/ad',
      'ad.youtube.com',
    ];
    return needles.any(value.contains);
  }

  Uri _watchUrl(String videoId) {
    return Uri.https('m.youtube.com', '/watch', {'v': videoId});
  }

  Future<void> _injectSkip() async {
    await _web?.evaluateJavascript(source: _skipAdsJs);
  }

  Future<bool> _onBack() async {
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
      return false;
    }
    return true;
  }

  void _openStreamPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreamPlayerScreen(
          catalog: widget.catalog,
          store: widget.store,
          video: widget.video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _onBack() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            widget.video.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: 'Quality is in YouTube’s player menu (gear). '
                  '4K if the video has it.',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Tap the video → gear → Quality. '
                      'YouTube’s player can go to 1080p/4K. That is how Brave does it.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.hd_outlined),
            ),
            IconButton(
              tooltip: 'Old stream player',
              onPressed: _openStreamPlayer,
              icon: const Icon(Icons.play_circle_outline),
            ),
          ],
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_watchUrl(widget.video.id).toString()),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllowFullscreen: true,
                useShouldInterceptRequest: true,
                supportZoom: false,
                userAgent: _chromeUa,
                preferredContentMode: UserPreferredContentMode.MOBILE,
                transparentBackground: true,
                useHybridComposition: true,
                contentBlockers: _blockers,
              ),
              shouldInterceptRequest: (controller, request) async {
                if (_isAdRequest(request.url.toString())) {
                  return WebResourceResponse(
                    contentType: 'text/plain',
                    statusCode: 403,
                    reasonPhrase: 'Blocked',
                    data: Uint8List(0),
                  );
                }
                return null;
              },
              onWebViewCreated: (controller) => _web = controller,
              onLoadStart: (controller, url) {
                setState(() => _loading = true);
              },
              onLoadStop: (controller, url) async {
                await _injectSkip();
                if (mounted) {
                  setState(() => _loading = false);
                }
                final id = VideoId.parseVideoId(url?.toString() ?? '');
                if (id != null && id != widget.video.id) {
                  widget.store.addHistory(
                    VideoHit(
                      id: id,
                      title: widget.video.title,
                      author: widget.video.author,
                      thumbnailUrl:
                          'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                      isLive: false,
                    ),
                  );
                }
              },
              onTitleChanged: (controller, title) async {
                await _injectSkip();
              },
            ),
            if (_loading)
              const ColoredBox(
                color: Color(0xCC000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
