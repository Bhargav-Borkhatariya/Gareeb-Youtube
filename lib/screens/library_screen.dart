import 'package:flutter/material.dart';

import '../store/friend_store.dart';
import '../widgets/format.dart';
import '../widgets/video_tiles.dart';
import '../youtube/catalog.dart';
import '../youtube/google_youtube.dart';
import 'channel_screen.dart';
import 'player_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.catalog, required this.store});

  final YoutubeCatalog catalog;
  final FriendStore store;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _channelQuery = TextEditingController();
  bool _searching = false;
  List<ChannelHit> _channelHits = const [];

  @override
  void dispose() {
    _channelQuery.dispose();
    super.dispose();
  }

  Future<void> _findChannels() async {
    final query = _channelQuery.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() => _searching = true);
    try {
      final hits = await widget.catalog.searchChannels(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _channelHits = hits;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openVideo(VideoHit video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          catalog: widget.catalog,
          store: widget.store,
          video: video,
        ),
      ),
    );
  }

  void _openChannel(ChannelHit channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelScreen(
          catalog: widget.catalog,
          store: widget.store,
          channel: channel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final subs = widget.store.subscriptions;
        final history = widget.store.history;
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.store.currentName}\'s library'),
            actions: [
              TextButton(
                onPressed: () async {
                  await GoogleYoutubeLogin.signOut();
                  await widget.store.switchOut();
                },
                child: const Text('Switch'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (widget.store.isGoogleUser)
                ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: Text(widget.store.googleEmail ?? 'Google'),
                  subtitle: const Text('YouTube subscriptions imported'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        final session = await GoogleYoutubeLogin.signIn(
                          webClientId: widget.store.webClientId,
                        );
                        await widget.store.mergeSubscriptions(
                          session.subscriptions,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Imported ${session.subscriptions.length} subscriptions',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                    child: const Text('Refresh'),
                  ),
                )
              else
                const ListTile(
                  leading: Icon(Icons.login),
                  title: Text('Not signed in with Google'),
                  subtitle: Text('Switch profile to use Sign in with Google'),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _channelQuery,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _findChannels(),
                  decoration: InputDecoration(
                    hintText: 'Find a channel to subscribe',
                    prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: IconButton(
                      onPressed: _searching ? null : _findChannels,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_searching) const LinearProgressIndicator(),
              if (_channelHits.isNotEmpty)
                ..._channelHits.map(
                  (channel) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: channel.logoUrl.isEmpty
                          ? null
                          : NetworkImage(channel.logoUrl),
                      child: channel.logoUrl.isEmpty
                          ? Text(initial(channel.title))
                          : null,
                    ),
                    title: Text(channel.title),
                    trailing: TextButton(
                      onPressed: () => widget.store.toggleSubscription(channel),
                      child: Text(
                        widget.store.isSubscribed(channel.id)
                            ? 'Subscribed'
                            : 'Subscribe',
                      ),
                    ),
                    onTap: () => _openChannel(channel),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Subscriptions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (subs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No subscriptions yet. Find a channel above, or tap Subscribe on a video.',
                  ),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: subs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final channel = subs[index];
                      return InkWell(
                        onTap: () => _openChannel(channel),
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: channel.logoUrl.isEmpty
                                    ? null
                                    : NetworkImage(channel.logoUrl),
                                child: channel.logoUrl.isEmpty
                                    ? Text(initial(channel.title))
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                channel.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Watch history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nothing here yet. Play a video and it will land in this pile.'),
                )
              else
                ...history.map(
                  (video) => VideoListTile(
                    video: video,
                    onTap: () => _openVideo(video),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
