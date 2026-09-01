import 'package:flutter/material.dart';

import '../store/friend_store.dart';
import '../youtube/catalog.dart';
import 'feed_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.catalog,
    required this.store,
  });

  final YoutubeCatalog catalog;
  final FriendStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          FeedScreen(catalog: widget.catalog, store: widget.store),
          SearchScreen(catalog: widget.catalog, store: widget.store),
          LibraryScreen(catalog: widget.catalog, store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
