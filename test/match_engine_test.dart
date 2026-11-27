import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartfind/matching/match_engine.dart';

/// Runs the cases in test/fixtures/match_cases.json - the same file is used by
/// the JavaScript twin of the engine in server/test, so both stay in step.
MatchProfile _profile(Map<String, dynamic> j) {
  final parts = (j['date'] as String).split('-').map(int.parse).toList();
  return MatchProfile(
    id: j['id'] as String,
    reporterId: j['reporterId'] as String,
    status: j['status'] as String,
    category: j['category'] as String,
    title: j['title'] as String,
    description: j['description'] as String,
    location: j['location'] as String,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    eventDate: DateTime(parts[0], parts[1], parts[2], 12),
  );
}

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/match_cases.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (fixtures['cases'] as List).cast<Map<String, dynamic>>();

  group('shared match cases', () {
    for (final c in cases) {
      test(c['name'] as String, () {
        final a = _profile(c['a'] as Map<String, dynamic>);
        final b = _profile(c['b'] as Map<String, dynamic>);
        final candidate = MatchEngine.isCandidate(a, b);
        if (c['expectCandidate'] == false) {
          expect(candidate, isFalse);
          return;
        }
        expect(candidate, isTrue);
        final s = MatchEngine.score(a, b);
        expect(
          s.ruleScore >= MatchEngine.threshold,
          c['expectMatch'] as bool,
          reason: 'score ${s.ruleScore}',
        );
      });
    }
  });

  group('tokens', () {
    test('digits must match exactly (13 is not 14)', () {
      final x = MatchEngine.tokenize('iPhone 13');
      final y = MatchEngine.tokenize('iPhone 14');
      expect(MatchEngine.softSimilarity(x, y), lessThan(0.8));
      expect(
        MatchEngine.softSimilarity(x, MatchEngine.tokenize('iphone 13')),
        greaterThan(0.99),
      );
    });

    test('korean particles are stripped and synonyms unify', () {
      expect(MatchEngine.tokenize('지갑을').keys.join(','), 'wallet');
      expect(MatchEngine.tokenize('핸드폰').containsKey('phone'), isTrue);
      final iphone = MatchEngine.tokenize('아이폰 13');
      expect(iphone.containsKey('iphone'), isTrue);
      expect(iphone.containsKey('phone'), isTrue);
    });

    test('typos still match', () {
      final x = MatchEngine.tokenize('charger');
      final y = MatchEngine.tokenize('chargerr');
      expect(MatchEngine.softSimilarity(x, y), greaterThan(0.6));
    });
  });

  group('scoring helpers', () {
    test('blend stays inside 0..100', () {
      expect(MatchEngine.blend(60, 100), 78);
      expect(MatchEngine.blend(60, 500), MatchEngine.blend(60, 100));
      expect(MatchEngine.blend(60, -5), MatchEngine.blend(60, 0));
    });

    test('found before lost scores low, found soon after scores 1', () {
      final lost = DateTime(2026, 3, 10);
      expect(MatchEngine.dateSimilarity(lost, DateTime(2026, 3, 11)), 1);
      expect(MatchEngine.dateSimilarity(lost, DateTime(2026, 3, 1)), 0.15);
      expect(MatchEngine.dateSimilarity(lost, DateTime(2026, 4, 20)), 0);
    });

    test('distance bands', () {
      expect(MatchEngine.locationSimilarity('a', 'A', 5000), 1);
      expect(MatchEngine.locationSimilarity('a', 'b', 30), 0.95);
      expect(MatchEngine.locationSimilarity('a', 'b', 150), 0.6);
      expect(MatchEngine.locationSimilarity('a', 'b', 5000), 0);
    });
  });
}
