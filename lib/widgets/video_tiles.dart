import 'package:flutter/material.dart';

import '../youtube/catalog.dart';
import 'format.dart';

class VideoFeedCard extends StatelessWidget {
  const VideoFeedCard({super.key, required this.video, required this.onTap});

  final VideoHit video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoThumb(
              url: video.thumbnailUrl,
              duration: video.isLive ? null : video.duration,
              live: video.isLive,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2A2A32),
                  child: Text(initial(video.author)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoListTile extends StatelessWidget {
  const VideoListTile({super.key, required this.video, required this.onTap});

  final VideoHit video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: VideoThumb(
        url: video.thumbnailUrl,
        width: 124,
        height: 70,
        radius: 8,
        duration: video.isLive ? null : video.duration,
        live: video.isLive,
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        video.author,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70),
      ),
      onTap: onTap,
    );
  }
}

class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 0,
    this.duration,
    this.live = false,
  });

  final String url;
  final double? width;
  final double? height;
  final double radius;
  final Duration? duration;
  final bool live;

  @override
  Widget build(BuildContext context) {
    Widget image = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF1A1A1A),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFF2A2A32),
              child: Icon(Icons.play_circle_outline),
            ),
          ),
        ),
        if (live || duration != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: live ? const Color(0xFFFF0033) : Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  live ? 'LIVE' : formatDuration(duration!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (width != null && height != null) {
      image = SizedBox(width: width, height: height, child: image);
    }

    if (radius <= 0) {
      return image;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }
}
