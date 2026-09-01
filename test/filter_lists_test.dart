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
