import 'package:flutter/material.dart';

import '../store/friend_store.dart';
import '../widgets/video_tiles.dart';
import '../youtube/catalog.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.catalog, required this.store});

  final YoutubeCatalog catalog;
  final FriendStore store;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<VideoHit> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.catalog.search(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'Nothing matched. Try a different rabbit hole.';
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Search failed. Try NewPipe / Brave.\n\n$e';
      });
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Find a video or paste a link',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type anything. We’ll skip the ads — you bring the snacks.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return VideoFeedCard(video: video, onTap: () => _open(video));
      },
    );
  }
}
