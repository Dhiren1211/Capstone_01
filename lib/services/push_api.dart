import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Result of asking the server to match a report.
class PushMatchResult {
  const PushMatchResult({required this.notified, required this.matches});

  /// How many notifications the server created (and pushed).
  final int notified;

  /// `{itemId, score, ruleScore, ai, reasons}` per announced match.
  final List<Map<String, dynamic>> matches;
}

/// Client of the optional Cloudflare Worker in `server/` (see README).
///
/// Every request carries the signed-in user's Firebase ID token; the server
/// verifies it. All methods fail soft: they return `null` instead of throwing,
/// so the app can fall back to its on-device behaviour.
class PushApi {
  PushApi({http.Client? client, Future<String?> Function()? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? _firebaseToken;

  static final PushApi instance = PushApi();

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  static Future<String?> _firebaseToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static const Duration _timeout = Duration(seconds: 25);

  /// Asks the server to look for matches of [itemId] and to notify both people.
  /// [candidateIds] are the on-device favourites (the server re-scores them).
  Future<PushMatchResult?> requestMatch(
    String itemId, {
    List<String> candidateIds = const [],
    String? baseUrl,
  }) async {
    final body = await _post('/v1/match', {
      'itemId': itemId,
      if (candidateIds.isNotEmpty) 'candidateIds': candidateIds,
    }, baseUrl: baseUrl);
    if (body == null) return null;
    final matches = (body['matches'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    return PushMatchResult(
      notified: (body['notified'] as num?)?.toInt() ?? 0,
      matches: matches ?? const [],
    );
  }

  /// Tells the server to push a chat message that was just written.
  Future<bool> announceMessage(
    String chatId,
    String text, {
    String? baseUrl,
  }) async {
    final body = await _post('/v1/message', {
      'chatId': chatId,
      'text': text,
    }, baseUrl: baseUrl);
    return body != null;
  }

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> payload, {
    String? baseUrl,
  }) async {
    final root = baseUrl ?? AppConfig.pushApiUrl;
    if (root.isEmpty) return null;
    try {
      final token = await _tokenProvider();
      if (token == null) return null;
      final response = await _client
          .post(
            Uri.parse('$root$path'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('[push-api] $path -> ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on TimeoutException {
      debugPrint('[push-api] $path timed out');
      return null;
    } catch (e) {
      debugPrint('[push-api] $path failed: $e');
      return null;
    }
  }
}
