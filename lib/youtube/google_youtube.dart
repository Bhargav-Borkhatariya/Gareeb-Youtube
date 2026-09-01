import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/youtube/v3.dart';

import 'catalog.dart';

class GoogleYoutubeSession {
  const GoogleYoutubeSession({
    required this.email,
    required this.displayName,
    required this.subscriptions,
  });

  final String email;
  final String displayName;
  final List<ChannelHit> subscriptions;
}

/// Official Google Sign-In (Android account picker) + YouTube Data API.
/// This is not a password form. It is not Brave (browser) or ReVanced (patched YouTube app).
class GoogleYoutubeLogin {
  GoogleYoutubeLogin._();

  static const packageName = 'dev.personal.gareeb_youtube';
  static const debugSha1 = '74:2B:66:17:37:D8:83:09:73:B6:E2:C8:52:43:99:51:08:27:DE:9F';
  static const debugSha256 =
      '1E:8D:59:40:63:46:3F:04:FF:3D:3D:8E:8B:36:7D:6E:1B:86:38:18:C6:C5:3F:2F:16:C8:1C:E7:1B:79:A6:66';

  static const _scopes = [YouTubeApi.youtubeReadonlyScope];

  static String? _initializedClientId;

  static Future<void> _ensureInitialized(String webClientId) async {
    final id = webClientId.trim();
    if (id.isEmpty) {
      throw StateError(
        'Paste your Google Cloud Web client ID first (one-time setup below).',
      );
    }
    if (_initializedClientId == id) {
      return;
    }
    await GoogleSignIn.instance.initialize(serverClientId: id);
    _initializedClientId = id;
  }

  static Future<GoogleYoutubeSession> signIn({required String webClientId}) async {
    await _ensureInitialized(webClientId);
    final account = await GoogleSignIn.instance.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes(_scopes);
    final client = authorization.authClient(scopes: _scopes);
    try {
      final api = YouTubeApi(client);
      final subscriptions = await _allSubscriptions(api);
      return GoogleYoutubeSession(
        email: account.email,
        displayName: (account.displayName?.trim().isNotEmpty ?? false)
            ? account.displayName!.trim()
            : account.email.split('@').first,
        subscriptions: subscriptions,
      );
    } finally {
      client.close();
    }
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  static Future<List<ChannelHit>> _allSubscriptions(YouTubeApi api) async {
    final channels = <ChannelHit>[];
    String? pageToken;
    do {
      final page = await api.subscriptions.list(
        ['snippet'],
        mine: true,
        maxResults: 50,
        pageToken: pageToken,
      );
      for (final item in page.items ?? const <Subscription>[]) {
        final snippet = item.snippet;
        final id = snippet?.resourceId?.channelId;
        if (id == null || id.isEmpty) {
          continue;
        }
        final thumbs = snippet?.thumbnails;
        final logo = thumbs?.medium?.url ??
            thumbs?.high?.url ??
            thumbs?.default_?.url ??
            '';
        channels.add(
          ChannelHit(
            id: id,
            title: snippet?.title ?? 'Channel',
            logoUrl: logo,
          ),
        );
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && channels.length < 250);
    return channels;
  }
}
