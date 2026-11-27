import 'package:flutter_test/flutter_test.dart';
import 'package:smartfind/models/item_model.dart';
import 'package:smartfind/services/matching_service.dart';

ItemModel _item({
  required String status,
  required String title,
  required String description,
  String location = 'Central Library Building',
  double lat = 35.132769,
  double lng = 129.056107,
  String pickup = '',
  DateTime? when,
  String reporter = 'u1',
}) {
  final date = when ?? DateTime(2026, 11, 3, 14);
  return ItemModel(
    id: '$status-$title',
    title: title,
    description: description,
    category: 'bags',
    status: status,
    location: location,
    latitude: lat,
    longitude: lng,
    reporterId: reporter,
    reporterName: 'Someone',
    contactInfo: 'someone@ks.ac.kr',
    imageUrl: '',
    createdAt: date,
    updatedAt: date,
    eventDate: date,
    pickupLocation: pickup,
  );
}

void main() {
  final matching = MatchingService.instance;

  final lostBackpack = _item(
    status: 'lost',
    reporter: 'owner',
    title: 'Black Backpack',
    description:
        'Black Nike backpack with a laptop inside and a blue keychain on '
        'the zipper. Left on the second-floor reading desk.',
  );

  ItemModel foundBackpack({String reporter = 'finder'}) =>
      _item(
        status: 'found',
        reporter: reporter,
        title: 'Black Nike Backpack',
        description:
            'Found a black Nike backpack with a blue keychain on a desk on '
            'the second floor of the library. Handed in at the front desk.',
      );

  test('the match threshold is 70 percent', () {
    expect(MatchingService.matchThreshold, 70);
  });

  test('two people describing the same backpack are matched', () {
    final ranked = matching.rank(
      lostBackpack,
      [foundBackpack()],
      minScore: MatchingService.matchThreshold,
    );
    expect(ranked.length, 1);
    expect(ranked.first.score, greaterThanOrEqualTo(70));
    expect(ranked.first.isMatch, isTrue);
    expect(ranked.first.reasons, contains('similar title'));
  });

  test('an unrelated report in another building stays below the threshold', () {
    final umbrella = _item(
      status: 'found',
      reporter: 'finder',
      title: 'Green umbrella',
      description: 'Found a green folding umbrella near the cafeteria.',
      location: 'Gymnasium',
      lat: 35.1366,
      lng: 129.0612,
    );
    final ranked = matching.rank(lostBackpack, [umbrella]);
    expect(ranked.length, 1);
    expect(ranked.first.score, lessThan(70));
    expect(
      matching.rank(
        lostBackpack,
        [umbrella],
        minScore: MatchingService.matchThreshold,
      ),
      isEmpty,
    );
  });

  test('only opposite kinds, from other people, still open, are compared', () {
    final sameKind = _item(
      status: 'lost',
      reporter: 'someone-else',
      title: 'Black Nike Backpack',
      description: 'Lost a black Nike backpack with a blue keychain.',
    );
    final ownReport = foundBackpack(reporter: 'owner');
    final closed = _item(
      status: 'found',
      reporter: 'finder',
      title: 'Black Nike Backpack',
      description: 'Found a black Nike backpack with a blue keychain.',
    ).copyWith(reunited: true);

    expect(matching.rank(lostBackpack, [sameKind]), isEmpty);
    expect(matching.rank(lostBackpack, [ownReport]), isEmpty);
    expect(matching.rank(lostBackpack, [closed]), isEmpty);
  });

  test('results are sorted best first and the limit is honoured', () {
    final good = foundBackpack();
    final weaker = _item(
      status: 'found',
      reporter: 'finder-2',
      title: 'Backpack',
      description: 'A backpack was left at the library.',
    );
    final far = _item(
      status: 'found',
      reporter: 'finder-3',
      title: 'Black Backpack',
      description: 'Black backpack found far away.',
      location: 'Gymnasium',
      lat: 35.1366,
      lng: 129.0612,
    );
    final ranked = matching.rank(lostBackpack, [far, weaker, good]);
    expect(ranked.length, 3);
    expect(ranked.first.item.reporterId, 'finder');
    for (var i = 1; i < ranked.length; i++) {
      expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
    }
    expect(matching.rank(lostBackpack, [far, weaker, good], limit: 2).length, 2);
  });

  test('the same pair always gets the same notification id', () {
    expect(
      MatchingService.notificationIdFor('u1', 'a', 'b'),
      MatchingService.notificationIdFor('u1', 'b', 'a'),
    );
    expect(
      MatchingService.notificationIdFor('u1', 'a', 'b') ==
          MatchingService.notificationIdFor('u2', 'a', 'b'),
      isFalse,
    );
  });
}
