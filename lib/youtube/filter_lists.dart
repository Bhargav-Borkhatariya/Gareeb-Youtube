import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Live EasyList / uBlock rules, refreshed like Brave Shields.
class AdFilters {
  const AdFilters({
    required this.hosts,
    required this.needles,
    required this.selectors,
    required this.jsonKeys,
  });

  final Set<String> hosts;
  final Set<String> needles;
  final Set<String> selectors;
  final Set<String> jsonKeys;

  static const builtinHosts = {
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googletagservices.com',
    'adservice.google.com',
    'ad.youtube.com',
  };

  static const builtinNeedles = {
    '/pagead/',
    '/ptracking',
    'api/stats/ads',
    'api/stats/atr',
    'get_midroll',
    'player/ad',
    '/adview',
    'pcs/activeview',
    'pcs/view',
    'pagead2.',
  };

  static const builtinSelectors = {
    'ytm-promo-panel-renderer',
    'ytm-app-promo-renderer',
    'ytd-open-in-app-button',
    '.ytm-open-in-app',
    '.open-app-button',
    'ytd-ad-slot-renderer',
    'ytm-promoted-sparkles-web-renderer',
    'ytm-promoted-video-renderer',
    '.masthead-ad',
    '#player-ads',
    'ytd-banner-promo-renderer',
    'ytm-companion-slot',
    'ytm-ad-slot-renderer',
    '.ytp-ad-player-overlay',
    '.ytp-ad-player-overlay-layout',
    '.ytp-ad-image-overlay',
    '.ytp-ad-overlay-slot',
    '.ytp-ad-text-overlay',
    '.ytp-ad-message-container',
    '.ytp-ad-preview-container',
  };

  static const builtinJsonKeys = {
    'adPlacements',
    'playerAds',
    'adSlots',
    'adBreakHeartbeatParams',
    'adBreaks',
  };

  static const _neverBlockHosts = {
    'youtube.com',
    'youtu.be',
    'youtubekids.com',
    'youtube-nocookie.com',
    'googlevideo.com',
    'ytimg.com',
    'ggpht.com',
    'googleusercontent.com',
    'gstatic.com',
    'googleapis.com',
    'google.com',
    'gvt1.com',
  };

  factory AdFilters.builtin() => AdFilters(
        hosts: {...builtinHosts},
        needles: {...builtinNeedles},
        selectors: {...builtinSelectors},
        jsonKeys: {...builtinJsonKeys},
      );

  AdFilters merge(AdFilters other) {
    return AdFilters(
      hosts: {...hosts, ...other.hosts},
      needles: {...needles, ...other.needles},
      selectors: builtinSelectors,
      jsonKeys: builtinJsonKeys,
    );
  }

  bool matches(String url) {
    final value = url.toLowerCase();
    if (_isCoreYoutubeUrl(value)) {
      return builtinNeedles.any(value.contains);
    }
    if (hosts.any((host) => value.contains(host))) return true;
    if (needles.any(value.contains)) return true;
    return value.contains('googlevideo.com') &&
        (value.contains('oad=') ||
            value.contains('&oad') ||
            value.contains('ctier=l'));
  }

  static bool _isCoreYoutubeUrl(String value) {
    if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
      return false;
    }
    const keep = [
      '/watch',
      '/results',
      '/feed',
      '/channel',
      '/shorts',
      '/live',
      '/playlist',
      '/youtubei/',
      '/embed/',
      '/@',
      '/c/',
      '/user/',
      '/account',
      '/get_video_info',
      '/iframe_api',
    ];
    return keep.any(value.contains);
  }

  String get cosmeticCss {
    final hide = selectors.join(', ');
    return '''
$hide { display: none !important; }
.html5-video-player.ad-showing .html5-video-container,
.html5-video-player.ad-showing video {
  opacity: 0 !important;
}
.html5-video-player.ad-showing {
  background: #000 !important;
}
''';
  }

  String get keysJs =>
      'window.__gareebAdKeys=${jsonEncode(jsonKeys.toList())};';

  Map<String, dynamic> toJson() => {
        'hosts': hosts.toList(),
        'needles': needles.toList(),
        'selectors': selectors.toList(),
        'jsonKeys': jsonKeys.toList(),
      };

  factory AdFilters.fromJson(Map<String, dynamic> json) {
    Set<String> read(String key) => {
          for (final item in json[key] as List? ?? const []) item.toString(),
        };
    return AdFilters(
      hosts: read('hosts'),
      needles: read('needles'),
      selectors: read('selectors'),
      jsonKeys: read('jsonKeys'),
    );
  }

  /// Keep YouTube / Google ad rules only so EasyList does not balloon RAM.
  static bool isUsefulLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('youtube') ||
        lower.contains('googlevideo') ||
        lower.contains('doubleclick') ||
        lower.contains('googlesyndication') ||
        lower.contains('googleadservices') ||
        lower.contains('googletagservices') ||
        lower.contains('adservice.google') ||
        lower.contains('pagead') ||
        lower.contains('2mdn.net');
  }

  static AdFilters parse(String text) {
    final hosts = <String>{};
    final needles = <String>{};
    final selectors = <String>{};
    final jsonKeys = <String>{};

    for (var raw in const LineSplitter().convert(text)) {
      raw = raw.trim();
      if (raw.isEmpty || raw.startsWith('!') || raw.startsWith('[')) continue;
      if (raw.startsWith('@@')) continue;
      if (!isUsefulLine(raw)) continue;

      if (raw.contains('##+js(') || raw.contains('#@#+js(')) {
        _collectScriptletKeys(raw, jsonKeys);
        continue;
      }

      final cosmeticAt = raw.indexOf('##');
      if (cosmeticAt > 0 && !raw.startsWith('|')) {
        final domains = raw.substring(0, cosmeticAt).toLowerCase();
        if (domains.contains('youtube')) {
          final selector = raw.substring(cosmeticAt + 2).trim();
          if (selector.isNotEmpty &&
              !selector.startsWith('+js') &&
              selector.length < 180) {
            selectors.add(selector);
          }
        }
        continue;
      }

      if (!raw.startsWith('||')) continue;
      var rule = raw.substring(2);
      final optionAt = rule.indexOf(r'$');
      if (optionAt != -1) {
        final options = rule.substring(optionAt + 1).toLowerCase();
        rule = rule.substring(0, optionAt);
        if (options.contains('redirect') ||
            options.contains('csp') ||
            options.contains('removeparam')) {
          continue;
        }
      }
      rule = rule.replaceAll('^', '').replaceAll('*', '');
      if (rule.isEmpty || rule.contains('?')) continue;

      final slash = rule.indexOf('/');
      if (slash == -1) {
        final host = rule.toLowerCase();
        if (host.contains('.') && !_isProtectedHost(host)) {
          hosts.add(host);
        }
        continue;
      }

      final host = rule.substring(0, slash).toLowerCase();
      final path = rule.substring(slash).toLowerCase();
      if (host.contains('googlevideo')) {
        if (path.contains('oad') ||
            path.contains('initplayback') ||
            path.contains('ctier')) {
          needles.add(path);
        }
        continue;
      }
      if (_isProtectedHost(host)) {
        if (path == '/api/stats' || path == '/api/stats/') continue;
        if (_isCoreYoutubeUrl('youtube.com$path')) continue;
        if (path.length > 2) needles.add(path);
        continue;
      }
      if (host.contains('.')) hosts.add(host);
      if (path.length > 2) needles.add(path);
    }

    return AdFilters(
      hosts: hosts,
      needles: needles,
      selectors: selectors,
      jsonKeys: jsonKeys,
    );
  }

  static bool _isProtectedHost(String host) {
    return _neverBlockHosts.any((item) => host == item || host.endsWith('.$item'));
  }

  static void _collectScriptletKeys(String line, Set<String> jsonKeys) {
    for (final match in RegExp(r'[A-Za-z][A-Za-z0-9]*').allMatches(line)) {
      final word = match.group(0)!;
      if (word.length < 4) continue;
      final startsAd = word.startsWith('ad') && word[2] == word[2].toUpperCase();
      final endsAds = word.endsWith('Ads');
      if (startsAd || endsAds) jsonKeys.add(word);
    }
  }
}

class FilterListStore {
  FilterListStore._();
  static final FilterListStore instance = FilterListStore._();

  static const _cacheKey = 'gareeb_adfilters_v2';
  static const _fetchedKey = 'gareeb_adfilters_fetched_v2';
  static const _maxAge = Duration(hours: 12);

  static const _sources = [
    (
      'https://ublockorigin.github.io/uAssets/filters/filters.txt',
      'https://cdn.jsdelivr.net/gh/uBlockOrigin/uAssets@master/filters/filters.txt',
    ),
    (
      'https://ublockorigin.github.io/uAssets/filters/filters-2025.txt',
      'https://cdn.jsdelivr.net/gh/uBlockOrigin/uAssets@master/filters/filters-2025.txt',
    ),
    (
      'https://ublockorigin.github.io/uAssets/filters/filters-2026.txt',
      'https://cdn.jsdelivr.net/gh/uBlockOrigin/uAssets@master/filters/filters-2026.txt',
    ),
    (
      'https://easylist.to/easylist/easylist.txt',
      'https://easylist-downloads.adblockplus.org/easylist.txt',
    ),
    (
      'https://easylist.to/easylist/easyprivacy.txt',
      'https://easylist-downloads.adblockplus.org/easyprivacy.txt',
    ),
  ];

  AdFilters current = AdFilters.builtin();

  Future<AdFilters> load() async {
    current = AdFilters.builtin();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        current = AdFilters.builtin().merge(
          AdFilters.fromJson(jsonDecode(cached) as Map<String, dynamic>),
        );
      }
      final fetchedMs = prefs.getInt(_fetchedKey) ?? 0;
      final stale = DateTime.now().millisecondsSinceEpoch - fetchedMs >
          _maxAge.inMilliseconds;
      if (cached == null || stale) {
        await refresh();
      }
    } catch (_) {
      current = AdFilters.builtin();
    }
    return current;
  }

  Future<AdFilters> refresh() async {
    var merged = AdFilters.builtin();
    var gotAny = false;
    for (final source in _sources) {
      final text = await _download(source.$1) ?? await _download(source.$2);
      if (text == null || text.length < 200) continue;
      merged = merged.merge(AdFilters.parse(text));
      gotAny = true;
    }
    if (gotAny) {
      current = merged;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(merged.toJson()));
        await prefs.setInt(_fetchedKey, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    }
    return current;
  }

  Future<String?> _download(String url) async {
    final client = HttpClient();
    try {
      client.userAgent = 'GareebYoutube/1.8 (personal filter refresh)';
      client.connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return null;
      return await response.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
