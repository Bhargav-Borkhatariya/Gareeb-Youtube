import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../store/friend_store.dart';
import '../widgets/format.dart';
import '../widgets/player_gestures.dart';
import '../widgets/video_tiles.dart';
import '../youtube/catalog.dart';
import 'channel_screen.dart';

class StreamPlayerScreen extends StatefulWidget {
  const StreamPlayerScreen({
    super.key,
    required this.catalog,
    required this.store,
    required this.video,
  });

  final YoutubeCatalog catalog;
  final FriendStore store;
  final VideoHit video;

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _loading = true;
  bool _switching = false;
  String? _error;
  PlaybackSession? _session;
  List<VideoHit> _related = const [];
  ChannelHit? _channel;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    widget.store.addHistory(widget.video);
    _start();
    _loadExtras();
  }

  Future<void> _start() async {
    try {
      final session = await widget.catalog.playback(widget.video.id);
      if (!mounted) {
        return;
      }
      _session = session;
      await _openCurrent();
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _openCurrent({Duration? resume}) async {
    final session = _session;
    if (session == null) {
      return;
    }
    final headers = <String, String>{
      'User-Agent': session.playUserAgent,
      'Referer': 'https://www.youtube.com/',
      'Origin': 'https://www.youtube.com',
    };

    var url = session.video.url.toString();
    final audio = session.audio;
    final hlsPair = session.video.isHls && (audio?.isHls ?? false);

    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty(
        'audio-file',
        hlsPair ? '' : (audio?.url.toString() ?? ''),
      );
    }

    if (hlsPair && audio != null) {
      url = await _hlsMasterUrl(url, audio.url.toString());
    }

    await _player.open(Media(url, httpHeaders: headers));
    if (resume != null && resume > Duration.zero) {
      await _player.seek(resume);
    }
  }

  Future<String> _hlsMasterUrl(String videoPlaylist, String audioPlaylist) async {
    final file = File(
      '${Directory.systemTemp.path}/gareeb_${videoPlaylist.hashCode}.m3u8',
    );
    await file.writeAsString(
      '#EXTM3U\n'
      '#EXT-X-INDEPENDENT-SEGMENTS\n'
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Audio",'
      'DEFAULT=YES,AUTOSELECT=YES,URI="$audioPlaylist"\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=5000000,AUDIO="audio"\n'
      '$videoPlaylist\n',
    );
    return file.uri.toString();
  }

  Future<void> _switchStream({int? videoIndex, int? audioIndex}) async {
    final session = _session;
    if (session == null || _switching) {
      return;
    }
    setState(() => _switching = true);
    final resume = _player.state.position;
    try {
      if (videoIndex != null) {
        session.videoIndex = videoIndex;
      }
      if (audioIndex != null) {
        session.audioIndex = audioIndex;
      }
      await _openCurrent(resume: resume);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _switching = false);
      }
    }
  }

  Future<void> _loadExtras() async {
    try {
      final related = await widget.catalog.related(widget.video.id);
      ChannelHit? channel;
      final channelId = widget.video.channelId;
      if (channelId != null && channelId.isNotEmpty) {
        try {
          channel = await widget.catalog.channel(channelId);
        } catch (_) {
          channel = ChannelHit(
            id: channelId,
            title: widget.video.author,
            logoUrl: '',
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _related = related;
        _channel = channel;
      });
    } catch (_) {}
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('403') ||
        text.contains('PlaybackUnavailable') ||
        text.contains('no available streams') ||
        text.contains('does not contain any playable')) {
      return 'Could not play this video. YouTube may have changed something.\n\n'
          '${YoutubeCatalog.fallbackHint}';
    }
    return '$text\n\n${YoutubeCatalog.fallbackHint}';
  }

  void _openRelated(VideoHit video) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => StreamPlayerScreen(
          catalog: widget.catalog,
          store: widget.store,
          video: video,
        ),
      ),
    );
  }

  Future<void> _pickQuality() async {
    final session = _session;
    if (session == null || session.videos.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _ChoiceSheet(
          title: 'Quality',
          choices: session.videos,
          selectedIndex: session.videoIndex,
        );
      },
    );
    if (selected != null) {
      await _switchStream(videoIndex: selected);
    }
  }

  Future<void> _pickAudio() async {
    final session = _session;
    if (session == null || session.audio == null || session.audios.length < 2) {
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _ChoiceSheet(
          title: 'Audio track',
          choices: session.audios,
          selectedIndex: session.audioIndex,
        );
      },
    );
    if (selected != null) {
      await _switchStream(audioIndex: selected);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final channel = _channel;
        final subscribed =
            channel != null && widget.store.isSubscribed(channel.id);
        return Scaffold(
          body: Column(
            children: [
              ColoredBox(
                color: Colors.black,
                child: SafeArea(
                  bottom: false,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _playerArea(),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        widget.video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        [
                          widget.video.author,
                          if (widget.video.duration != null)
                            formatDuration(widget.video.duration!),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                      ),
                    ),
                    if (session != null)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.hd_outlined, size: 18),
                              label: Text(session.video.label),
                              onPressed: _pickQuality,
                            ),
                            if (session.audio != null) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(Icons.audiotrack, size: 18),
                                label: Text(
                                  session.audio!.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: session.audios.length > 1
                                    ? _pickAudio
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (channel != null)
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                        leading: CircleAvatar(
                          backgroundImage: channel.logoUrl.isEmpty
                              ? null
                              : NetworkImage(channel.logoUrl),
                          child: channel.logoUrl.isEmpty
                              ? Text(initial(channel.title))
                              : null,
                        ),
                        title: Text(channel.title),
                        subtitle: const Text('Open channel'),
                        trailing: FilledButton.tonal(
                          onPressed: () =>
                              widget.store.toggleSubscription(channel),
                          child: Text(subscribed ? 'Subscribed' : 'Subscribe'),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChannelScreen(
                                catalog: widget.catalog,
                                store: widget.store,
                                channel: channel,
                              ),
                            ),
                          );
                        },
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_related.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Up next',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final video in _related)
                        VideoFeedCard(
                          video: video,
                          onTap: () => _openRelated(video),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _playerArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return const Center(
        child: Icon(Icons.error_outline, size: 48, color: Colors.white54),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PlayerGestureLayer(
          player: _player,
          child: Video(controller: _controller),
        ),
        StreamBuilder<bool>(
          stream: _player.stream.buffering,
          initialData: _player.state.buffering,
          builder: (context, snapshot) {
            if (snapshot.data != true || _switching) {
              return const SizedBox.shrink();
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
        if (_switching)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    required this.selectedIndex,
  });

  final String title;
  final List<StreamChoice> choices;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: choices.length,
              itemBuilder: (context, index) {
                final choice = choices[index];
                return ListTile(
                  selected: index == selectedIndex,
                  title: Text(choice.label),
                  subtitle:
                      choice.subtitle == null ? null : Text(choice.subtitle!),
                  trailing: index == selectedIndex
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
