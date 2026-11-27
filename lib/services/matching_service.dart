import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../matching/match_engine.dart';
import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import 'push_api.dart';

/// A candidate pair with its score.
class ScoredMatch {
  const ScoredMatch({required this.item, required this.breakdown});

  /// The OTHER report (the one that is compared with the report in question).
  final ItemModel item;
  final MatchBreakdown breakdown;

  /// 0..100.
  int get score => breakdown.ruleScore;
  bool get isMatch => score >= MatchEngine.threshold;
  List<String> get reasons => breakdown.reasons;
}

/// Finds reports that probably describe the same object and tells both people.
///
/// The scoring itself is [MatchEngine] (title, description, category, location,
/// date; 70 % threshold; works without any server). When a Worker is
/// configured (`MATCH_API_URL`) it is asked to double-check with an AI model
/// and to send real push notifications; if it cannot be reached the phone does
/// the whole job itself.
class MatchingService {
  MatchingService._();
  static final MatchingService instance = MatchingService._();

  static int get matchThreshold => MatchEngine.threshold;

  /// Opposite-kind, still-open reports from [pool] ranked by similarity to
  /// [item] (best first). Pure - no network.
  List<ScoredMatch> rank(
    ItemModel item,
    Iterable<ItemModel> pool, {
    int minScore = 0,
    int limit = 20,
  }) {
    final mine = item.toMatchProfile();
    final out = <ScoredMatch>[];
    for (final other in pool) {
      if (!MatchEngine.isCandidate(mine, other.toMatchProfile())) continue;
      final b = MatchEngine.score(mine, other.toMatchProfile());
      if (b.ruleScore < minScore) continue;
      out.add(ScoredMatch(item: other, breakdown: b));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Called after a new item was saved. [feed] is the list the app already has
  /// (saves a query); otherwise the newest open reports are read.
  Future<List<ScoredMatch>> findMatchesForNewItem(
    ItemModel newItem, {
    List<ItemModel>? feed,
  }) async {
    final opposite = newItem.status == 'lost' ? 'found' : 'lost';
    final pool = feed ?? await FirestoreService.instance.recentOpenItems(status: opposite);
    final ranked = rank(newItem, pool);

    // Nothing is even close: neither the rules nor the AI can reach 70.
    final plausible = ranked.where((m) => m.score >= MatchData.aiMinRuleScore).toList();
    if (plausible.isEmpty) return const [];

    if (AppConfig.pushApiConfigured && AppConfig.pushAvailable) {
      final answer = await PushApi.instance.requestMatch(
        newItem.id,
        candidateIds: plausible.take(8).map((m) => m.item.id).toList(),
      );
      if (answer != null) {
        final byId = {for (final m in ranked) m.item.id: m};
        return [
          for (final j in answer.matches)
            ?byId[j['itemId']],
        ];
      }
      debugPrint('[matching] server unreachable - matching on the phone');
    }

    final matches = ranked.where((m) => m.isMatch).take(MatchData.maxNotificationsPerItem).toList();
    for (final m in matches) {
      await _notifyBoth(newItem, m);
    }
    return matches;
  }

  /// Same pair + same person always gives the same notification id, so
  /// running the matching twice never produces duplicates.
  static String notificationIdFor(String uid, String itemA, String itemB) {
    final ids = [itemA, itemB]..sort();
    return 'm_${uid}_${ids[0]}_${ids[1]}';
  }

  Future<void> _notifyBoth(ItemModel mine, ScoredMatch m) async {
    final other = m.item;
    final pct = m.score;

    NotificationModel build({
      required String uid,
      required ItemModel own,
      required ItemModel counterpart,
      required String openItemId,
    }) {
      return NotificationModel(
        id: notificationIdFor(uid, mine.id, other.id),
        userId: uid,
        type: NotificationType.matchFound,
        title: 'Possible match found ($pct%)',
        body:
            'A ${counterpart.statusEnum.label.toLowerCase()} report, '
            '"${_shorten(counterpart.title, 48)}", looks like your '
            '${own.statusEnum.label.toLowerCase()} report '
            '"${_shorten(own.title, 48)}". Open it to compare the details.',
        createdAt: DateTime.now(),
        isRead: false,
        itemId: openItemId,
        itemStatus: counterpart.status,
        otherItemId: own.id,
        score: pct,
      );
    }

    final notes = [
      build(uid: other.reporterId, own: other, counterpart: mine, openItemId: mine.id),
      build(uid: mine.reporterId, own: mine, counterpart: other, openItemId: other.id),
    ];
    for (final n in notes) {
      try {
        await FirestoreService.instance.createNotification(n, id: n.id);
      } on FirebaseException catch (e) {
        // permission-denied = this pair was announced before. Anything else
        // must not break posting the report either.
        debugPrint('[matching] notification skipped: ${e.code}');
      }
    }
  }

  static String _shorten(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = t.runes.toList();
    return runes.length <= max ? t : '${String.fromCharCodes(runes.take(max - 1))}…';
  }
}
