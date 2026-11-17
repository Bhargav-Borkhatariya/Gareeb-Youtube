import 'package:flutter_test/flutter_test.dart';
import 'package:gareeb_youtube/youtube/filter_lists.dart';

void main() {
  test('parses uBlock-style YouTube network and cosmetic rules', () {
    const list = '''
! comment
||doubleclick.net^
||youtube.com/pagead/
||youtube.com/ptracking\$xhr
||googlevideo.com/videoplayback
youtube.com##.ytp-ad-player-overlay
m.youtube.com##+js(json-prune, playerResponse.adPlacements playerAds adSlots)
@@||youtube.com/pagead/unbreak
''';
    final filters = AdFilters.parse(list);
    expect(filters.hosts, contains('doubleclick.net'));
    expect(filters.needles, contains('/pagead/'));
    expect(filters.needles, isNot(contains('/watch')));
    expect(
      AdFilters.builtin().merge(filters).matches('https://m.youtube.com/watch?v=abc'),
      isFalse,
    );
    expect(
      AdFilters.builtin().merge(filters).matches('https://m.youtube.com/results?search_query=hi'),
      isFalse,
    );
    expect(filters.needles, isNot(contains('/videoplayback')));
    expect(filters.selectors, contains('.ytp-ad-player-overlay'));
    expect(filters.jsonKeys, containsAll(['adPlacements', 'playerAds', 'adSlots']));
  });

  test('never blocks YouTube\'s own player assets', () {
    final filters = AdFilters.builtin();
    // The player build id is hex, so it can start with "ad".
    expect(
      filters.matches(
        'https://m.youtube.com/s/player/ad8d59ae/player-plasma-es6-en_GB.vflset/base.js',
      ),
      isFalse,
    );
    expect(
      filters.matches('https://m.youtube.com/s/player/ad8d59ae/mweb.css'),
      isFalse,
    );
    // A fetched rule must not be able to turn a stub path into a needle that
    // swallows the player either.
    final loose = AdFilters.builtin().merge(AdFilters.parse('||youtube.com/ad\n'));
    expect(
      loose.matches(
        'https://m.youtube.com/s/player/ad8d59ae/player-plasma-es6-en_GB.vflset/base.js',
      ),
      isFalse,
    );
  });

  test('builtin engine still blocks known ad hosts', () {
    final filters = AdFilters.builtin();
    expect(filters.matches('https://googleads.g.doubleclick.net/pagead/id'), isTrue);
    expect(filters.matches('https://m.youtube.com/watch?v=abc'), isFalse);
    expect(filters.matches('https://m.youtube.com/results?search_query=hi'), isFalse);
    expect(
      filters.matches('https://rr1---sn-abc.googlevideo.com/videoplayback?oad=1'),
      isTrue,
    );
  });
}
