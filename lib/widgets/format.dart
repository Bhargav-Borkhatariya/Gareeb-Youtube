import 'package:flutter/material.dart';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

String initial(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}
