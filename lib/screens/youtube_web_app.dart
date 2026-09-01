import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../youtube/filter_lists.dart';

/// Full YouTube website in-app. Blocks ads and “Open in app” / Play Store jumps.
class YoutubeWebApp extends StatefulWidget {
  const YoutubeWebApp({super.key});

  @override
  State<YoutubeWebApp> createState() => _YoutubeWebAppState();
}

class _YoutubeWebAppState extends State<YoutubeWebApp> {
  InAppWebViewController? _web;
  var _booting = true;
  var _everLoaded = false;
  late final List<ContentBlocker> _blockers;
  late final List<UserScript> _scripts;
  late final PullToRefreshController _pullToRefresh;

  static const _home = 'https://m.youtube.com/';
  static const _gold = Color(0xFFE2B15A);
  static const _ink = Color(0xFF0C0B09);

  static const _chromeUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  static const _hideSelector =
      'ytm-promo-panel-renderer, ytm-app-promo-renderer, ytd-open-in-app-button, '
      '.ytm-open-in-app, .open-app-button, ytd-ad-slot-renderer, '
      'ytm-promoted-sparkles-web-renderer, ytm-promoted-video-renderer, '
      '.masthead-ad, #player-ads, ytd-banner-promo-renderer, ytm-companion-slot, '
      'ytm-ad-slot-renderer, .ytp-ad-player-overlay, '
      '.ytp-ad-image-overlay, .ytp-ad-overlay-slot, .ytp-ad-text-overlay, '
      '.ytp-ad-message-container, .ytp-ad-preview-container';

  static const _adHideCss = '''
$_hideSelector { display: none !important; }
.html5-video-player.ad-showing .html5-video-container,
.html5-video-player.ad-showing video {
  opacity: 0 !important;
}
.html5-video-player.ad-showing {
  background: #000 !important;
}
.ytp-settings-button, .ytp-settings-menu, .ytp-popup, .ytp-panel,
.ytp-overflow-panel, .ytp-fullscreen-button {
  pointer-events: auto !important;
  visibility: visible !important;
}
''';

  static const _adPruneJs = r'''
(function() {
  if (window.__gareebPrune) return;
  window.__gareebPrune = true;

  var origParse = JSON.parse;
  var origFetch = window.fetch;
  var xhrOpen = XMLHttpRequest.prototype.open;
  var xhrSend = XMLHttpRequest.prototype.send;
  var textDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'responseText');
  var respDesc = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'response');
  window.__gareebAdKeys = ['adPlacements', 'playerAds', 'adSlots'];

  function stripAdKeys(text) {
    if (!text || typeof text !== 'string') return text;
    var keys = window.__gareebAdKeys || [];
    var out = text;
    for (var i = 0; i < keys.length; i++) {
      var token = '"' + keys[i] + '"';
      if (out.indexOf(token) !== -1) out = out.split(token).join('"no_ads"');
    }
    return out;
  }

  function pruneAds(node) {
    if (!node || typeof node !== 'object') return;
    var keys = window.__gareebAdKeys || [];
    if ('adPlacements' in node) delete node.adPlacements;
    if ('playerAds' in node) delete node.playerAds;
    if ('adSlots' in node) delete node.adSlots;
    if (node.playerResponse) pruneAds(node.playerResponse);
    for (var k = 0; k < keys.length; k++) {
      if (keys[k] in node) delete node[keys[k]];
    }
  }

  function isPlayerApi(url) {
    url = String(url || '');
    return url.indexOf('/youtubei/v1/player') !== -1
      || url.indexOf('/youtubei/v1/get_watch') !== -1;
  }

  function urlFrom(input) {
    try {
      if (typeof input === 'string') return input;
      if (input && input.url) return String(input.url);
    } catch (e) {}
    return '';
  }

  try {
    var value;
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
      configurable: true,
      enumerable: true,
      get: function() { return value; },
      set: function(next) {
        pruneAds(next);
        value = next;
      }
    });
  } catch (e) {}

  if (typeof origFetch === 'function') {
    window.fetch = function(input) {
      var reqUrl = urlFrom(input);
      return origFetch.apply(this, arguments).then(function(res) {
        var url = res && res.url ? res.url : reqUrl;
        if (!isPlayerApi(url)) return res;
        return res.clone().text().then(function(text) {
          text = stripAdKeys(text);
          try {
            var data = origParse(text);
            pruneAds(data);
            return new Response(JSON.stringify(data), {
              status: res.status,
              statusText: res.statusText,
              headers: res.headers
            });
          } catch (e) {
            return res;
          }
        });
      });
    };
  }

  XMLHttpRequest.prototype.open = function(method, url) {
    this.__gareebUrl = url;
    return xhrOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    var xhr = this;
    if (isPlayerApi(xhr.__gareebUrl) && textDesc && textDesc.get) {
      xhr.addEventListener('readystatechange', function() {
        if (xhr.readyState !== 4) return;
        try {
          var raw = textDesc.get.call(xhr);
          if (typeof raw !== 'string') return;
          var data = origParse(stripAdKeys(raw));
          pruneAds(data);
          var out = JSON.stringify(data);
          Object.defineProperty(xhr, 'responseText', { configurable: true, get: function() { return out; } });
          Object.defineProperty(xhr, 'response', { configurable: true, get: function() { return out; } });
        } catch (e) {}
      });
    }
    return xhrSend.apply(this, arguments);
  };

  try { pruneAds(window.ytInitialPlayerResponse); } catch (e) {}
})();
''';

  static const _polishJs = r'''
(function() {
  if (window.__gareebWeb) return;
  window.__gareebWeb = true;

  try {
    window.addEventListener('beforeinstallprompt', function(e) {
      e.preventDefault();
    });
  } catch (e) {}

  var appUrl = /^(intent:|market:|vnd\.youtube|youtube:|googleyoutube:|android-app:)/i;
  var store = /play\.google\.com\/store\/apps/i;
  var origOpen = window.open;
  window.open = function(url) {
    var s = String(url || '');
    if (appUrl.test(s) || store.test(s)) return null;
    return origOpen.apply(this, arguments);
  };

  function isOpenAppText(text) {
    text = (' ' + (text || '') + ' ').toLowerCase();
    return text.indexOf(' open app ') !== -1
      || text.indexOf(' open in app ') !== -1
      || text.indexOf(' open in youtube app ') !== -1
      || text.indexOf(' use the app ') !== -1
      || text.indexOf(' try the app ') !== -1
      || text.indexOf(' get the app ') !== -1
      || text.indexOf(' install app ') !== -1
      || text.indexOf(' install youtube ') !== -1;
  }

  function hideOpenApp() {
    document.querySelectorAll(
      'ytm-promo-panel-renderer, ytm-app-promo-renderer, ytd-open-in-app-button, .ytm-open-in-app'
    ).forEach(function(el) { el.remove(); });
    document.querySelectorAll('a, button, yt-button-shape').forEach(function(el) {
      var label = (el.getAttribute('aria-label') || '') + ' ' + (el.innerText || '');
      if (!isOpenAppText(label)) return;
      var row = el.closest(
        'ytm-menu-item, ytm-setting-item, ytd-compact-link-renderer, '
        + 'ytm-promo-panel-renderer, ytm-app-promo-renderer'
      );
      if (row) row.remove();
    });
  }

  function skipAds() {
    var player = document.querySelector('.html5-video-player.ad-showing');
    if (!player) return;
    player.querySelectorAll(
      '.ytp-ad-skip-button, .ytp-skip-ad-button, .ytp-ad-skip-button-modern, '
      + '.ytp-ad-overlay-close-button'
    ).forEach(function(el) { try { el.click(); } catch (e) {} });
    var ad = player.querySelector('video');
    if (ad) {
      try {
        ad.muted = true;
        ad.volume = 0;
        ad.playbackRate = 16;
        if (ad.duration && isFinite(ad.duration)) ad.currentTime = ad.duration;
      } catch (e) {}
    }
  }

  hideOpenApp();
  skipAds();
  setInterval(hideOpenApp, 2000);
  setInterval(skipAds, 500);
})();
''';

  @override
  void initState() {
    super.initState();
    _blockers = _contentBlockers();
    _pullToRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: _gold,
        backgroundColor: _ink,
      ),
      onRefresh: () async {
        await _web?.reload();
      },
    );
    _scripts = [
      UserScript(
        source: _adPruneJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
      UserScript(
        source:
            '(function(){var s=document.createElement("style");s.id="gareeb-ad-css";'
            's.textContent=${jsonEncode(_adHideCss)};'
            'document.documentElement.appendChild(s);})();',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
      UserScript(
        source: _polishJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
    ];
    unawaited(_bootFilters());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _ink,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  List<ContentBlocker> _contentBlockers() {
    const filters = [
      r'.*.doubleclick.net/.*',
      r'.*.googlesyndication.com/.*',
      r'.*.googleadservices.com/.*',
      r'.*.googleads.g.doubleclick.net/.*',
      r'.*.adservice.google..*/.*',
      r'.*.pagead2.googlesyndication.com/.*',
      r'.*.googletagservices.com/.*',
      r'.*.youtube.com/pagead/.*',
      r'.*.youtube.com/ptracking.*',
      r'.*.youtube.com/api/stats/ads.*',
      r'.*.ad.youtube.com/.*',
      r'.*.play.google.com/store/apps/.*',
    ];
    return [
      for (final filter in filters)
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: filter),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
    ];
  }

  bool _isAdRequest(String url) {
    return FilterListStore.instance.current.matches(url);
  }

  bool _isAppHandoff(String url) {
    final value = url.toLowerCase();
    return value.startsWith('intent:') ||
        value.startsWith('market:') ||
        value.startsWith('vnd.youtube') ||
        value.startsWith('youtube:') ||
        value.startsWith('googleyoutube:') ||
        value.startsWith('android-app:') ||
        value.contains('play.google.com/store/apps') ||
        value.contains('id=com.google.android.youtube');
  }

  Future<void> _bootFilters() async {
    await FilterListStore.instance.load();
  }

  Future<void> _polish() async {
    await _web?.evaluateJavascript(source: _adPruneJs);
    await _web?.injectCSSCode(source: _adHideCss);
    await _web?.evaluateJavascript(source: _polishJs);
  }

  Future<bool> _handleBack() async {
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _handleBack() && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _ink,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_home)),
                initialUserScripts: UnmodifiableListView(_scripts),
                pullToRefreshController: _pullToRefresh,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  allowBackgroundAudioPlaying: true,
                  useShouldInterceptRequest: true,
                  useShouldOverrideUrlLoading: true,
                  supportZoom: false,
                  userAgent: _chromeUa,
                  preferredContentMode: UserPreferredContentMode.MOBILE,
                  useHybridComposition: true,
                  thirdPartyCookiesEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  allowsBackForwardNavigationGestures: true,
                  contentBlockers: _blockers,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                ),
                shouldOverrideUrlLoading: (controller, action) async {
                  final url = action.request.url?.toString() ?? '';
                  if (_isAppHandoff(url)) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                shouldInterceptRequest: (controller, request) async {
                  final url = request.url.toString();
                  if (_isAdRequest(url) || _isAppHandoff(url)) {
                    return WebResourceResponse(
                      contentType: 'text/plain',
                      statusCode: 403,
                      reasonPhrase: 'Blocked',
                      data: Uint8List(0),
                    );
                  }
                  return null;
                },
                onCreateWindow: (controller, action) async {
                  final url = action.request.url?.toString() ?? '';
                  if (_isAppHandoff(url)) return false;
                  if (url.startsWith('http')) {
                    await controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(url)),
                    );
                  }
                  return false;
                },
                onWebViewCreated: (controller) => _web = controller,
                onEnterFullscreen: (_) {
                  unawaited(
                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.immersiveSticky,
                    ),
                  );
                },
                onExitFullscreen: (_) {
                  unawaited(
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
                  );
                },
                onLoadStart: (controller, url) {
                  if (!_everLoaded && mounted) {
                    setState(() => _booting = true);
                  }
                },
                onLoadStop: (controller, url) async {
                  _everLoaded = true;
                  await _polish();
                  await _pullToRefresh.endRefreshing();
                  if (mounted) setState(() => _booting = false);
                },
              ),
              if (_booting) const _BootSplash(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0C0B09),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(28)),
              child: Image(
                image: AssetImage('assets/icon/app_icon.png'),
                width: 112,
                height: 112,
              ),
            ),
            SizedBox(height: 22),
            Text(
              'Gareeb YouTube',
              style: TextStyle(
                color: Color(0xFFE2B15A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cheap seats. Good picture.',
              style: TextStyle(
                color: Color(0xFFB9A27A),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Color(0xFFE2B15A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
