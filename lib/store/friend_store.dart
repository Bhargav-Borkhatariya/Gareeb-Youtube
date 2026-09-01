import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../youtube/catalog.dart';

/// Local friend profiles, plus optional official Google Sign-In.
class FriendStore extends ChangeNotifier {
  FriendStore();

  static const _profilesKey = 'friend_profiles';
  static const _currentKey = 'friend_current';
  static const _webClientKey = 'google_web_client_id';

  SharedPreferences? _prefs;
  final List<String> profiles = [];
  String? currentName;
  String? googleEmail;
  String webClientId = '';
  List<ChannelHit> subscriptions = [];
  List<VideoHit> history = [];

  bool get isLoggedIn => currentName != null && currentName!.isNotEmpty;
  bool get isGoogleUser => googleEmail != null && googleEmail!.isNotEmpty;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    profiles
      ..clear()
      ..addAll(_prefs!.getStringList(_profilesKey) ?? const []);
    webClientId = _prefs!.getString(_webClientKey) ?? '';
    final current = _prefs!.getString(_currentKey);
    currentName = (current != null && profiles.contains(current)) ? current : null;
    _loadCurrentData();
    notifyListeners();
  }

  Future<void> createAndEnter(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }
    if (name.length > 24) {
      throw ArgumentError('Keep the name under 24 characters.');
    }
    if (!profiles.contains(name)) {
      profiles.add(name);
      await _prefs?.setStringList(_profilesKey, profiles);
    }
    await enter(name);
  }

  Future<void> enter(String name) async {
    if (!profiles.contains(name)) {
      throw ArgumentError('Unknown friend profile.');
    }
    currentName = name;
    await _prefs?.setString(_currentKey, name);
    _loadCurrentData();
    notifyListeners();
  }

  Future<void> switchOut() async {
    currentName = null;
    googleEmail = null;
    subscriptions = [];
    history = [];
    await _prefs?.remove(_currentKey);
    notifyListeners();
  }

  Future<void> saveWebClientId(String id) async {
    webClientId = id.trim();
    await _prefs?.setString(_webClientKey, webClientId);
    notifyListeners();
  }

  Future<void> enterGoogle({
    required String email,
    required String displayName,
    required List<ChannelHit> youtubeSubs,
  }) async {
    var name = displayName.trim();
    if (name.isEmpty) {
      name = email.split('@').first;
    }
    if (name.length > 24) {
      name = name.substring(0, 24);
    }
    await createAndEnter(name);
    googleEmail = email;
    await _prefs?.setString(_googleEmailKey(name), email);
    await mergeSubscriptions(youtubeSubs);
  }

  Future<void> mergeSubscriptions(List<ChannelHit> incoming) async {
    final byId = {for (final channel in subscriptions) channel.id: channel};
    for (final channel in incoming) {
      byId[channel.id] = channel;
    }
    subscriptions = byId.values.toList();
    await _saveCurrentData();
    notifyListeners();
  }

  bool isSubscribed(String channelId) {
    return subscriptions.any((channel) => channel.id == channelId);
  }

  Future<void> toggleSubscription(ChannelHit channel) async {
    if (isSubscribed(channel.id)) {
      subscriptions = subscriptions.where((item) => item.id != channel.id).toList();
    } else {
      subscriptions = [channel, ...subscriptions];
    }
    await _saveCurrentData();
    notifyListeners();
  }

  Future<void> addHistory(VideoHit video) async {
    history = [
      video,
      ...history.where((item) => item.id != video.id),
    ].take(80).toList();
    await _saveCurrentData();
    notifyListeners();
  }

  void _loadCurrentData() {
    final name = currentName;
    if (name == null || _prefs == null) {
      subscriptions = [];
      history = [];
      googleEmail = null;
      return;
    }
    googleEmail = _prefs!.getString(_googleEmailKey(name));
    subscriptions = _decodeList(
      _prefs!.getString(_subsKey(name)),
      ChannelHit.fromJson,
    );
    history = _decodeList(
      _prefs!.getString(_histKey(name)),
      VideoHit.fromJson,
    );
  }

  Future<void> _saveCurrentData() async {
    final name = currentName;
    final prefs = _prefs;
    if (name == null || prefs == null) {
      return;
    }
    await prefs.setString(
      _subsKey(name),
      jsonEncode(subscriptions.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _histKey(name),
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _subsKey(String name) => 'subs_$name';
  String _histKey(String name) => 'hist_$name';
  String _googleEmailKey(String name) => 'gemail_$name';
}
