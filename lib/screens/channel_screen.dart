import 'package:flutter/material.dart';

import '../store/friend_store.dart';
import '../widgets/video_tiles.dart';
import '../youtube/catalog.dart';
import 'player_screen.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({
    super.key,
    required this.catalog,
    required this.store,
    required this.channel,
  });

  final YoutubeCatalog catalog;
  final FriendStore store;
  final ChannelHit channel;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  late Future<List<VideoHit>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.catalog.channelUploads(widget.channel.id);
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
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final subscribed = widget.store.isSubscribed(widget.channel.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.channel.title),
            actions: [
              TextButton(
                onPressed: () => widget.store.toggleSubscription(widget.channel),
                child: Text(subscribed ? 'Subscribed' : 'Subscribe'),
              ),
            ],
          ),
          body: FutureBuilder<List<VideoHit>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load this channel.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final videos = snapshot.data ?? const [];
              if (videos.isEmpty) {
                return const Center(child: Text('No uploads found.'));
              }
              return ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return VideoFeedCard(video: video, onTap: () => _open(video));
                },
              );
            },
          ),
        );
      },
    );
  }
}
