import 'package:flutter/material.dart';

import '../store/friend_store.dart';
import '../widgets/video_tiles.dart';
import '../youtube/catalog.dart';
import 'player_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.catalog, required this.store});

  final YoutubeCatalog catalog;
  final FriendStore store;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<FeedShelf>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.catalog.homeShelves(subscriptions: widget.store.subscriptions);
  }

  Future<void> _reload() async {
    final next = widget.catalog.homeShelves(
      subscriptions: widget.store.subscriptions,
    );
    setState(() => _future = next);
    await next;
  }

  void _open(VideoHit video) {
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

  @override
  Widget build(BuildContext context) {
    final name = widget.store.currentName ?? 'friend';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFFFF0033)),
            SizedBox(width: 8),
            Text(
              'Gareeb',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch profile',
            onPressed: widget.store.switchOut,
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF2A2A32),
              child: Text(
                name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<FeedShelf>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Centered(
              text:
                  'Could not load Home.\n\n${snapshot.error}\n\n${YoutubeCatalog.fallbackHint}',
              onRetry: _reload,
            );
          }
          final shelves = snapshot.data ?? const [];
          if (shelves.isEmpty) {
            return _Centered(
              text: 'Nothing on Home yet. Search a video to start.',
              onRetry: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: shelves.length,
              itemBuilder: (context, index) {
                final shelf = shelves[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        shelf.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final video in shelf.videos)
                      VideoFeedCard(
                        video: video,
                        onTap: () => _open(video),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
