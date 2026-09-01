import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store/friend_store.dart';
import '../widgets/format.dart';
import '../youtube/google_youtube.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final FriendStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _webClientId = TextEditingController();
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    _webClientId.text = widget.store.webClientId;
  }

  @override
  void dispose() {
    _name.dispose();
    _webClientId.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    try {
      await widget.store.createAndEnter(_name.text);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _google() async {
    final clientId = _webClientId.text.trim();
    if (!_looksLikeWebClientId(clientId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That Web client ID is incomplete. On the computer, open '
            'Credentials → your Web client → copy the full Client ID. '
            'It looks like 123456789-xxxx.apps.googleusercontent.com',
          ),
        ),
      );
      return;
    }
    setState(() => _googleBusy = true);
    try {
      await widget.store.saveWebClientId(clientId);
      final session = await GoogleYoutubeLogin.signIn(
        webClientId: widget.store.webClientId,
      );
      await widget.store.enterGoogle(
        email: session.email,
        displayName: session.displayName,
        youtubeSubs: session.subscriptions,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_googleError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
      }
    }
  }

  String _googleError(Object error) {
    final text = error.toString();
    if (text.contains('28444') ||
        text.contains('not set up correctly') ||
        text.contains('clientConfigurationError') ||
        text.contains('serverClientId') ||
        text.contains('10:') ||
        text.contains('DEVELOPER_ERROR')) {
      return 'Google Cloud is not set up correctly. On a computer: create BOTH '
          'an Android OAuth client (package + SHA-1 from this screen) AND a Web '
          'OAuth client, then paste the full Web Client ID (long, starts with numbers).';
    }
    if (text.contains('access_denied') ||
        text.contains('Access blocked') ||
        text.contains('verification process')) {
      return 'Add your Gmail as a Test user in Google Cloud '
          '(OAuth consent screen → Test users). Keep the app in Testing. '
          'Do not publish it.';
    }
    if (text.contains('canceled') || text.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.store.profiles;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFFFF2D55),
              child: Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Gareeb YouTube',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Friends-only. Google sign-in uses the Android account picker — '
              'same kind of login as other apps, still no YouTube ads.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _googleBusy ? null : _google,
              icon: _googleBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_googleBusy ? 'Signing in…' : 'Sign in with Google'),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('One-time Google Cloud setup'),
              subtitle: const Text('Required before Google login works'),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '1. On a computer, open console.cloud.google.com\n'
                    '2. Create a project (or pick one)\n'
                    '3. Enable YouTube Data API v3\n'
                    '4. OAuth consent screen: External, Testing\n'
                    '5. Test users → Add the Gmail you watch YouTube with\n'
                    '6. Create OAuth client: Android\n'
                    '     package: ${GoogleYoutubeLogin.packageName}\n'
                    '     SHA-1: ${GoogleYoutubeLogin.debugSha1}\n'
                    '7. Create OAuth client: Web application\n'
                    '8. Paste the full Web client ID below\n'
                    'If Google says Access blocked / 403, step 5 is missing.',
                  ),
                ),
                ListTile(
                  title: const Text('Copy SHA-1'),
                  subtitle: const Text(GoogleYoutubeLogin.debugSha1),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(text: GoogleYoutubeLogin.debugSha1),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    controller: _webClientId,
                    decoration: const InputDecoration(
                      labelText: 'Web client ID',
                      hintText: '123456789-xxxx.apps.googleusercontent.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (profiles.isNotEmpty) ...[
              Text("Who's on the couch?", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final name in profiles)
                    ActionChip(
                      avatar: CircleAvatar(child: Text(initial(name))),
                      label: Text(name),
                      onPressed: () => widget.store.enter(name),
                    ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
              decoration: const InputDecoration(
                labelText: 'Or enter as a guest name',
                hintText: 'e.g. Ajax',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _create,
              child: const Text('Enter without Google'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _looksLikeWebClientId(String value) {
  return RegExp(
    r'^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$',
  ).hasMatch(value);
}
