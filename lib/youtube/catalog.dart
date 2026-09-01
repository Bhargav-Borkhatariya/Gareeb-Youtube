import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoHit {
  const VideoHit({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.isLive,
    this.channelId,
    this.duration,
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final bool isLive;
  final String? channelId;
  final Duration? duration;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'thumbnailUrl': thumbnailUrl,
        'isLive': isLive,
        'channelId': channelId,
        'durationMs': duration?.inMilliseconds,
      };

  factory VideoHit.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'] as int?;
    return VideoHit(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      isLive: json['isLive'] as bool? ?? false,
      channelId: json['channelId'] as String?,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    );
  }
}

class ChannelHit {
  const ChannelHit({
    required this.id,
    required this.title,
    required this.logoUrl,
  });

  final String id;
  final String title;
  final String logoUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'logoUrl': logoUrl,
      };

  factory ChannelHit.fromJson(Map<String, dynamic> json) {
    return ChannelHit(
      id: json['id'] as String,
      title: json['title'] as String,
      logoUrl: json['logoUrl'] as String? ?? '',
    );
  }
}

class StreamChoice {
  const StreamChoice({
    required this.id,
    required this.label,
    required this.url,
    this.subtitle,
    this.isOriginal = false,
    this.combined = false,
    this.isHls = false,
    this.userAgent = '',
  });

  final String id;
  final String label;
  final Uri url;
  final String? subtitle;
  final bool isOriginal;
  final bool combined;
  final bool isHls;
  final String userAgent;
}

class PlaybackSession {
  PlaybackSession({
    required this.videos,
    required this.audios,
    required this.videoIndex,
    required this.audioIndex,
    required this.userAgent,
  });

  final List<StreamChoice> videos;
  final List<StreamChoice> audios;
  final String userAgent;
  int videoIndex;
  int audioIndex;

  StreamChoice get video => videos[videoIndex];
  StreamChoice? get audio =>
      video.combined || audios.isEmpty ? null : audios[audioIndex];
  String get playUserAgent =>
      video.userAgent.isNotEmpty ? video.userAgent : userAgent;
}

class PlaybackUnavailable implements Exception {
  const PlaybackUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

class FeedShelf {
  const FeedShelf({required this.title, required this.videos});

  final String title;
  final List<VideoHit> videos;
}

/// Talks to YouTube through youtube_explode_dart only.
/// When this fails, watch in NewPipe or Brave — do not add custom bypasses.
class YoutubeCatalog {
  YoutubeCatalog({YoutubeExplode? explode})
      : _yt = explode ?? YoutubeExplode();

  final YoutubeExplode _yt;

  static const fallbackHint =
      'Watch this video in NewPipe or Brave for now. '
      'Then update youtube_explode_dart and rebuild this app. '
      'Do not reverse-engineer YouTube yourself.';

  static const iosUserAgent =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const androidUserAgent =
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

  Future<List<VideoHit>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final directId = VideoId.parseVideoId(trimmed);
    if (directId != null) {
      final video = await _yt.videos.get(directId);
      return [_hitFromVideo(video)];
    }

    final results = await _yt.search.search(trimmed);
    return results.map(_hitFromVideo).toList();
  }

  Future<List<ChannelHit>> searchChannels(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final results = await _yt.search.searchContent(
      trimmed,
      filter: TypeFilters.channel,
    );
    return results.whereType<SearchChannel>().map((channel) {
      final logo = channel.thumbnails.isNotEmpty
          ? channel.thumbnails.last.url.toString()
          : '';
      return ChannelHit(
        id: channel.id.value,
        title: channel.name,
        logoUrl: logo,
      );
    }).toList();
  }

  Future<List<FeedShelf>> homeShelves({
    List<ChannelHit> subscriptions = const [],
  }) async {
    final shelves = <FeedShelf>[];

    if (subscriptions.isNotEmpty) {
      final fromSubs = await _uploadsFromChannels(subscriptions.take(8));
      if (fromSubs.isNotEmpty) {
        shelves.add(FeedShelf(title: 'From your subs', videos: fromSubs));
      }
    }

    const discovery = <String, String>{
      'For you': 'trending',
      'Music': 'music',
      'Gaming': 'gaming',
    };

    final discovered = await Future.wait(
      discovery.entries.map((entry) async {
        try {
          final videos = await search(entry.value);
          return FeedShelf(title: entry.key, videos: videos.take(12).toList());
        } catch (_) {
          return FeedShelf(title: entry.key, videos: const []);
        }
      }),
    );
    shelves.addAll(discovered.where((shelf) => shelf.videos.isNotEmpty));
    return shelves;
  }

  Future<List<VideoHit>> related(String videoId) async {
    final video = await _yt.videos.get(videoId);
    final related = await _yt.videos.getRelatedVideos(video);
    if (related == null) {
      return const [];
    }
    return related.map(_hitFromVideo).toList();
  }

  Future<ChannelHit> channel(String channelId) async {
    final info = await _yt.channels.get(channelId);
    return ChannelHit(
      id: info.id.value,
      title: info.title,
      logoUrl: info.logoUrl,
    );
  }

  Future<List<VideoHit>> channelUploads(String channelId, {int limit = 30}) async {
    final uploads = await _yt.channels.getUploadsFromPage(channelId);
    return uploads.take(limit).map(_hitFromVideo).toList();
  }

  Future<PlaybackSession> playback(String videoId) async {
    // Pull from more than one client, then merge. If iOS HLS fails on a phone,
    // Android muxed-only used to leave the picker stuck on 360p.
    final videos = <StreamChoice>[];
    final audios = <StreamChoice>[];
    Object? lastError;

    Future<void> pull(YoutubeApiClient client, String userAgent) async {
      final manifest = await _yt.videos.streams.getManifest(
        videoId,
        ytClients: [client],
      );
      for (final choice in _videoChoices(manifest, userAgent: userAgent)) {
        final exists = videos.any(
          (item) =>
              item.label == choice.label &&
              item.isHls == choice.isHls &&
              item.combined == choice.combined,
        );
        if (!exists) {
          videos.add(choice);
        }
      }
      final nextAudio = _audioChoices(manifest);
      if (audios.isEmpty) {
        audios.addAll(nextAudio);
      } else if (audios.every((item) => !item.isHls) &&
          nextAudio.any((item) => item.isHls)) {
        audios
          ..clear()
          ..addAll(nextAudio);
      }
    }

    for (final attempt in [
      (YoutubeApiClient.ios, iosUserAgent),
      (YoutubeApiClient.androidSdkless, androidUserAgent),
      (YoutubeApiClient.androidVr, androidUserAgent),
    ]) {
      try {
        await pull(attempt.$1, attempt.$2);
      } catch (e) {
        lastError = e;
      }
    }

    if (videos.isEmpty) {
      throw PlaybackUnavailable(
        lastError == null
            ? 'No playable streams. YouTube may have changed something.\n\n$fallbackHint'
            : '$lastError\n\n$fallbackHint',
      );
    }

    videos.sort((a, b) {
      if (a.isHls != b.isHls) {
        return a.isHls ? -1 : 1;
      }
      if (a.combined != b.combined) {
        return a.combined ? 1 : -1;
      }
      return _heightOf(b.label).compareTo(_heightOf(a.label));
    });

    return PlaybackSession(
      videos: videos,
      audios: audios,
      videoIndex: _defaultVideoIndex(videos),
      audioIndex: _defaultAudioIndex(audios),
      userAgent: videos.any((item) => item.isHls)
          ? iosUserAgent
          : androidUserAgent,
    );
  }

  void close() => _yt.close();

  Future<List<VideoHit>> _uploadsFromChannels(Iterable<ChannelHit> channels) async {
    final batches = await Future.wait(
      channels.map((channel) async {
        try {
          final videos = await channelUploads(channel.id, limit: 8);
          return videos;
        } catch (_) {
          return const <VideoHit>[];
        }
      }),
    );
    final seen = <String>{};
    final mixed = <VideoHit>[];
    var index = 0;
    var added = true;
    while (added && mixed.length < 24) {
      added = false;
      for (final batch in batches) {
        if (index < batch.length && seen.add(batch[index].id)) {
          mixed.add(batch[index]);
          added = true;
        }
      }
      index++;
    }
    return mixed;
  }

  VideoHit _hitFromVideo(Video video) {
    return VideoHit(
      id: video.id.value,
      title: video.title,
      author: video.author,
      thumbnailUrl: 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg',
      isLive: video.isLive,
      channelId: video.channelId.value,
      duration: video.duration,
    );
  }

  List<StreamChoice> _videoChoices(
    StreamManifest manifest, {
    required String userAgent,
  }) {
    final choices = <StreamChoice>[];
    final seen = <String>{};

    void add(
      String label,
      Uri url, {
      String? subtitle,
      bool combined = false,
      bool isHls = false,
    }) {
      if (!seen.add('$label-$combined-$isHls')) {
        return;
      }
      choices.add(
        StreamChoice(
          id: label,
          label: label,
          url: url,
          subtitle: subtitle,
          combined: combined,
          isHls: isHls,
          userAgent: userAgent,
        ),
      );
    }

    final bestHls = <int, HlsVideoStreamInfo>{};
    for (final stream in manifest.hls.whereType<HlsVideoStreamInfo>()) {
      final height = stream.videoResolution.height;
      if (height <= 0 || height > 2160) {
        continue;
      }
      final current = bestHls[height];
      if (current == null || _hlsVideoRank(stream) > _hlsVideoRank(current)) {
        bestHls[height] = stream;
      }
    }
    final heights = bestHls.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final height in heights) {
      add('${height}p', bestHls[height]!.url, subtitle: 'HLS', isHls: true);
    }

    for (final stream in manifest.hls.whereType<HlsMuxedStreamInfo>()) {
      final height = stream.videoResolution.height;
      if (height <= 0 || height > 2160) {
        continue;
      }
      add(
        '${height}p',
        stream.url,
        subtitle: 'HLS',
        combined: true,
        isHls: true,
      );
    }

    for (final stream in manifest.videoOnly.where((item) => !item.isThrottled)) {
      final height = stream.videoResolution.height;
      if (height <= 0 || height > 2160) {
        continue;
      }
      add(stream.qualityLabel, stream.url, subtitle: stream.container.name);
    }

    for (final stream in manifest.muxed.sortByVideoQuality()) {
      add(
        stream.qualityLabel,
        stream.url,
        subtitle: 'Single file',
        combined: true,
      );
    }

    return choices;
  }

  int _hlsVideoRank(HlsVideoStreamInfo stream) {
    final codec = stream.videoCodec.toLowerCase();
    final avc = codec.contains('avc') ? 2 : (codec.contains('vp9') ? 1 : 0);
    return avc * 1000 + stream.framerate.framesPerSecond.round();
  }

  List<StreamChoice> _audioChoices(StreamManifest manifest) {
    final hlsAudio = manifest.hls.whereType<HlsAudioStreamInfo>().toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    if (hlsAudio.isNotEmpty) {
      return [
        for (var i = 0; i < hlsAudio.length; i++)
          StreamChoice(
            id: 'hls-audio-${hlsAudio[i].tag}',
            label: i == 0 ? 'Original audio' : 'Audio ${i + 1}',
            url: hlsAudio[i].url,
            subtitle: 'HLS',
            isOriginal: i == 0,
            isHls: true,
          ),
      ];
    }

    final byId = <String, AudioOnlyStreamInfo>{};
    for (final stream in _preferPlayableAudio(manifest.audioOnly)) {
      final key = stream.audioTrack?.id ??
          stream.audioTrack?.displayName ??
          'track-${stream.tag}';
      final existing = byId[key];
      if (existing == null || stream.bitrate.compareTo(existing.bitrate) > 0) {
        byId[key] = stream;
      }
    }
    return byId.values.map((stream) {
      final track = stream.audioTrack;
      final isOriginal = track?.audioIsDefault ?? false;
      final name = track?.displayName.trim();
      final label = (name == null || name.isEmpty) ? 'Audio' : name;
      return StreamChoice(
        id: track?.id ?? '${stream.tag}',
        label: isOriginal ? '$label (original)' : label,
        url: stream.url,
        subtitle: isOriginal ? 'Default original track' : null,
        isOriginal: isOriginal,
      );
    }).toList()
      ..sort((a, b) {
        if (a.isOriginal != b.isOriginal) {
          return a.isOriginal ? -1 : 1;
        }
        return a.label.compareTo(b.label);
      });
  }

  int _defaultVideoIndex(List<StreamChoice> videos) {
    const preferred = [2160, 1440, 1080, 720, 480, 360];
    for (final height in preferred) {
      final hls = videos.indexWhere(
        (item) => item.isHls && _heightOf(item.label) == height,
      );
      if (hls >= 0) {
        return hls;
      }
    }
    for (final height in preferred) {
      final idx = videos.indexWhere(
        (item) => !item.combined && _heightOf(item.label) == height,
      );
      if (idx >= 0) {
        return idx;
      }
    }
    final hls = videos.indexWhere((item) => item.isHls);
    if (hls >= 0) {
      return hls;
    }
    final muxed = videos.indexWhere((item) => item.combined);
    if (muxed >= 0) {
      return muxed;
    }
    return 0;
  }

  int _defaultAudioIndex(List<StreamChoice> audios) {
    if (audios.isEmpty) {
      return 0;
    }
    final original = audios.indexWhere((item) => item.isOriginal);
    return original >= 0 ? original : 0;
  }

  int _heightOf(String label) {
    final named = RegExp(r'(\d{3,4})p').firstMatch(label);
    if (named != null) {
      return int.parse(named.group(1)!);
    }
    final dim = RegExp(r'\d+x(\d+)').firstMatch(label);
    if (dim != null) {
      return int.parse(dim.group(1)!);
    }
    return int.tryParse(label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  List<AudioOnlyStreamInfo> _preferPlayableAudio(
    Iterable<AudioOnlyStreamInfo> streams,
  ) {
    final unthrottled = streams.where((s) => !s.isThrottled).toList();
    return unthrottled.isNotEmpty ? unthrottled : streams.toList();
  }
}
