import 'dart:math' as math;

part 'match_data.g.dart';

/// The fields of a report that matter for matching. Deliberately free of
/// Flutter / Firebase types so the exact same logic can be unit-tested on the
/// plain Dart VM and mirrored 1:1 in the Cloudflare Worker (`server/`).
class MatchProfile {
  const MatchProfile({
    required this.id,
    required this.reporterId,
    required this.status,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.eventDate,
    this.reunited = false,
    this.imageUrl = '',
  });

  final String id;
  final String reporterId;

  /// `lost` or `found`.
  final String status;
  final String category;
  final String title;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime eventDate;
  final bool reunited;
  final String imageUrl;
}

/// Why two reports were (not) considered the same object. All sub-scores are
/// 0..1; [ruleScore] is 0..100.
class MatchBreakdown {
  const MatchBreakdown({
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.date,
    required this.ruleScore,
    required this.distanceMeters,
  });

  final double title;
  final double description;
  final double category;
  final double location;
  final double date;

  /// Weighted total, 0..100, rounded to a whole number.
  final int ruleScore;
  final double distanceMeters;

  /// Short, human readable reasons, strongest first (shown to the user).
  List<String> get reasons {
    final r = <(double, String)>[
      (title, 'similar title'),
      (description, 'similar description'),
      (category, 'same category'),
      (location, 'close location'),
      (date, 'close in time'),
    ];
    r.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in r) if (e.$1 >= 0.6) e.$2];
  }
}

/// Decides whether a lost report and a found report describe the same object.
///
/// Signals (weights in `shared/match_data.json`):
///  * title            28 %   word overlap with synonyms (EN/KR), colours, typos
///  * description      22 %   same, on title + description together
///  * category         15 %   equal, or "related" (e.g. electronics/accessories)
///  * location         25 %   same building, else distance on campus
///  * date             10 %   found on/after lost, decaying over three weeks
///
/// A pair is a match from [MatchData.threshold] (70) upwards. No network, no
/// API key: this part always works. The optional AI step (Worker) can only
/// move the score by [MatchData.aiBlend] of its weight.
class MatchEngine {
  MatchEngine._();

  static int get threshold => MatchData.threshold;

  /// Can these two reports be a pair at all? (opposite kinds, both open,
  /// different people)
  static bool isCandidate(MatchProfile a, MatchProfile b) {
    if (a.id == b.id) return false;
    if (a.reunited || b.reunited) return false;
    if (a.reporterId == b.reporterId) return false;
    final kinds = {a.status, b.status};
    return kinds.length == 2 && kinds.contains('lost') && kinds.contains('found');
  }

  /// Scores [a] against [b] (order does not matter).
  static MatchBreakdown score(MatchProfile a, MatchProfile b) {
    final ignoreA = _locationWords(a.location);
    final ignoreB = _locationWords(b.location);

    final titleA = tokenize(a.title, ignore: ignoreA);
    final titleB = tokenize(b.title, ignore: ignoreB);
    final fullA = tokenize('${a.title} ${a.description}', ignore: ignoreA);
    final fullB = tokenize('${b.title} ${b.description}', ignore: ignoreB);

    final title = softSimilarity(titleA, titleB);
    final description = softSimilarity(fullA, fullB);
    final category = categorySimilarity(a.category, b.category);

    final dist = distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);
    final location = locationSimilarity(a.location, b.location, dist);

    final lost = a.status == 'lost' ? a : b;
    final found = a.status == 'lost' ? b : a;
    final date = dateSimilarity(lost.eventDate, found.eventDate);

    final total =
        MatchData.wTitle * title +
        MatchData.wDescription * description +
        MatchData.wCategory * category +
        MatchData.wLocation * location +
        MatchData.wDate * date;

    return MatchBreakdown(
      title: title,
      description: description,
      category: category,
      location: location,
      date: date,
      ruleScore: (total * 100).round(),
      distanceMeters: dist,
    );
  }

  /// Blends the rule score with an AI judgement (both 0..100).
  static int blend(int ruleScore, int aiScore) {
    final ai = aiScore.clamp(0, 100);
    return ((1 - MatchData.aiBlend) * ruleScore + MatchData.aiBlend * ai).round();
  }

  // --------------------------------------------------------------------- text

  static final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final RegExp _boundary = RegExp(
    r'(?<=\p{L})(?=\p{N})|(?<=\p{N})(?=\p{L})',
    unicode: true,
  );
  static final RegExp _hangul = RegExp(r'\p{Script=Hangul}', unicode: true);
  static final RegExp _digits = RegExp(r'^\d+$');
  static final RegExp _spaces = RegExp(r'\s+');

  static double _weightOf(String token) {
    if (MatchData.colors.contains(token)) return MatchData.tokenColor;
    if (MatchData.generic.contains(token)) return MatchData.tokenGeneric;
    if (_digits.hasMatch(token)) return MatchData.tokenNumber;
    return MatchData.tokenDefault;
  }

  static Set<String> _locationWords(String location) =>
      tokenize(location).keys.where((k) => !MatchData.aliasToCanon.containsKey(k)).toSet();

  /// Splits [text] into weighted, canonical tokens (insertion ordered).
  static Map<String, double> tokenize(String text, {Set<String> ignore = const {}}) {
    final out = <String, double>{};
    void put(String token) {
      final w = _weightOf(token);
      final old = out[token];
      if (old == null || w > old) out[token] = w;
    }

    final cleaned = text
        .toLowerCase()
        .replaceAll(_nonWord, ' ')
        .replaceAll(_boundary, ' ');
    for (final raw in cleaned.split(_spaces)) {
      if (raw.isEmpty) continue;
      var token = raw;
      if (_hangul.hasMatch(token)) token = _stripKoreanSuffix(token);
      if (MatchData.stopwords.contains(token) || MatchData.stopwords.contains(raw)) {
        continue;
      }
      var canon = MatchData.aliasToCanon[token];
      if (canon == null) {
        if (token.runes.length < 2) continue;
        canon = token;
      }
      if (ignore.contains(canon)) continue;
      put(canon);
      final extra = MatchData.expansions[canon];
      if (extra != null) {
        for (final e in extra) {
          put(e);
        }
      }
    }
    return out;
  }

  static String _stripKoreanSuffix(String token) {
    if (MatchData.aliasToCanon.containsKey(token)) return token;
    String? best;
    for (final s in MatchData.koreanSuffixes) {
      if (token.endsWith(s) && (best == null || s.length > best.length)) best = s;
    }
    if (best == null) return token;
    final rest = token.substring(0, token.length - best.length);
    final restLen = rest.runes.length;
    if (restLen >= 2 || (restLen == 1 && MatchData.aliasToCanon.containsKey(rest))) {
      return rest;
    }
    return token;
  }

  static double _total(Map<String, double> m) {
    var s = 0.0;
    for (final v in m.values) {
      s += v;
    }
    return s;
  }

  static Set<String> _bigrams(String s) {
    final runes = s.runes.toList();
    final out = <String>{};
    for (var i = 0; i + 1 < runes.length; i++) {
      out.add(String.fromCharCodes([runes[i], runes[i + 1]]));
    }
    return out;
  }

  static bool _fuzzyEqual(String x, String y) {
    if (_digits.hasMatch(x) || _digits.hasMatch(y)) return false;
    final xl = x.runes.length;
    final yl = y.runes.length;
    if (_hangul.hasMatch(x) && _hangul.hasMatch(y)) {
      return xl >= 2 && yl >= 2 && (x.contains(y) || y.contains(x));
    }
    if (xl < 4 || yl < 4) return false;
    final bx = _bigrams(x);
    final by = _bigrams(y);
    if (bx.isEmpty || by.isEmpty) return false;
    final inter = bx.intersection(by).length;
    return 2 * inter / (bx.length + by.length) >= 0.8;
  }

  /// 0..1 similarity of two weighted token sets.
  static double softSimilarity(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final aSmall = _total(a) <= _total(b);
    final small = aSmall ? a : b;
    final large = aSmall ? b : a;

    final used = <String>{};
    final exact = <String>{};
    var matched = 0.0;
    for (final e in small.entries) {
      final other = large[e.key];
      if (other != null) {
        matched += math.min(e.value, other);
        used.add(e.key);
        exact.add(e.key);
      }
    }
    for (final e in small.entries) {
      if (exact.contains(e.key)) continue;
      for (final f in large.entries) {
        if (used.contains(f.key)) continue;
        if (_fuzzyEqual(e.key, f.key)) {
          matched += 0.8 * math.min(e.value, f.value);
          used.add(f.key);
          break;
        }
      }
    }
    final wSmall = _total(small);
    final wLarge = _total(large);
    final overlap = matched / wSmall;
    final jaccard = matched / (wSmall + wLarge - matched);
    return 0.6 * overlap + 0.4 * jaccard;
  }

  // ------------------------------------------------------------ other signals

  static double categorySimilarity(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x == y) return 1;
    if (x == 'other' || y == 'other' || x.isEmpty || y.isEmpty) return 0.5;
    for (final pair in MatchData.relatedCategories) {
      if ((pair[0] == x && pair[1] == y) || (pair[0] == y && pair[1] == x)) {
        return 0.35;
      }
    }
    return 0;
  }

  static double locationSimilarity(String a, String b, double meters) {
    final na = a.trim().toLowerCase();
    final nb = b.trim().toLowerCase();
    if (na.isNotEmpty && na == nb) return 1;
    if (meters <= 40) return 0.95;
    if (meters <= 100) return 0.8;
    if (meters <= 200) return 0.6;
    if (meters <= 400) return 0.35;
    if (meters <= 800) return 0.12;
    return 0;
  }

  /// A found report should be on/after the lost one. Within three days 1.0,
  /// then a linear decay to 0 at 21 days. "Found" more than a day BEFORE the
  /// loss is unlikely, but not impossible (wrong date typed): 0.15.
  static double dateSimilarity(DateTime lost, DateTime found) {
    final l = DateTime.utc(lost.year, lost.month, lost.day);
    final f = DateTime.utc(found.year, found.month, found.day);
    final days = f.difference(l).inDays;
    if (days < -1) return 0.15;
    if (days <= 3) return 1;
    return math.max(0, 1 - (days - 3) / 18);
  }

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
