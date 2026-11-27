import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
import '../state/settings_store.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import 'messaging_service.dart';

/// Called by the system when a push message arrives while the app is not
/// running. Messages that carry a `notification` block (all of ours) are shown
/// by Android / iOS themselves, as a heads-up pop-up on the screen even when
/// the phone is locked, so there is nothing to do here. The handler must still
/// exist, be top-level and keep its entry-point pragma.
@pragma('vm:entry-point')
Future<void> smartfindBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[push] background message ${message.messageId}');
}

/// Pop-up alerts for possible matches and new messages.
///
/// Three layers, so something always reaches the user:
///  1. FCM push (needs the Worker in `server/`): arrives even when the app is
///     closed or the screen is off; shown by the system.
///  2. While the app is open: FCM messages are turned into heads-up pop-ups
///     (the system does not draw them in the foreground).
///  3. Without a server: new in-app notifications (Firestore) are shown as
///     pop-ups while the app is running.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String matchChannelId = 'smartfind_matches';
  static const String messageChannelId = 'smartfind_messages';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  String? _uid;
  String? _token;

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<List<NotificationModel>>? _feedSub;
  StreamSubscription<List<ChatModel>>? _chatSub;

  /// Conversation currently on screen (set by the chat page): new messages in
  /// it do not need a pop-up.
  String? openChatId;
  final Map<String, int> _chatUnread = <String, int>{};
  bool _chatsPrimed = false;

  /// Notification ids already announced (FCM and Firestore describe the same one).
  final Set<String> _announced = <String>{};
  bool _feedPrimed = false;

  Map<String, dynamic>? _pendingTap;

  bool get _supported => !kIsWeb;

  /// Call once, after Firebase was initialised. Does not ask for permission.
  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;
    if (_initialized || !_supported) return;
    _initialized = true;

    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _onTap(_decode(response.payload)),
      );

      final android = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          matchChannelId,
          'Possible matches',
          description: 'Alerts when a report looks like yours.',
          importance: Importance.max,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          messageChannelId,
          'Messages',
          description: 'New chat messages about lost and found items.',
          importance: Importance.high,
        ),
      );

      // The app was opened by tapping a pop-up that this plugin drew.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _pendingTap = _decode(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('[notifications] local plugin setup failed: $e');
    }

    if (!AppConfig.pushAvailable) return;
    try {
      FirebaseMessaging.onBackgroundMessage(smartfindBackgroundMessageHandler);
      // iOS draws nothing in the foreground by itself; we draw our own pop-up.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions();
      _messageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _onTap(Map<String, dynamic>.from(m.data)),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingTap = Map<String, dynamic>.from(initial.data);
    } catch (e) {
      debugPrint('[notifications] push setup failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Signing in / out
  // ---------------------------------------------------------------------------

  /// Call whenever the signed-in user changes (null = signed out).
  Future<void> bindUser(String? uid) async {
    if (!_supported || uid == _uid) return;
    final previous = _uid;
    _uid = uid;

    await _feedSub?.cancel();
    _feedSub = null;
    await _chatSub?.cancel();
    _chatSub = null;
    _feedPrimed = false;
    _chatsPrimed = false;
    _chatUnread.clear();
    _announced.clear();

    if (previous != null && previous != uid) {
      await _forgetToken(previous);
    }
    if (uid == null) return;

    await requestPermission();
    await _registerToken(uid);
    _watchFeed(uid);
    _watchChats(uid);
  }

  /// Asks for the notification permission (Android 13+, iOS). Safe to repeat.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    var granted = true;
    try {
      final android = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestNotificationsPermission();
      if (result == false) granted = false;
    } catch (e) {
      debugPrint('[notifications] android permission request failed: $e');
    }
    if (AppConfig.pushAvailable) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          granted = false;
        }
      } catch (e) {
        debugPrint('[notifications] permission request failed: $e');
      }
    }
    return granted;
  }

  Future<void> _registerToken(String uid) async {
    if (!AppConfig.pushAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _token = token;
        await _storeToken(uid, token);
      }
      await _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        final current = _uid;
        if (current != null) _storeToken(current, t);
      });
    } catch (e) {
      // Common on emulators without Google Play services: not an error.
      debugPrint('[notifications] no push token: $e');
    }
  }

  Future<void> _storeToken(String uid, String token) async {
    try {
      final ref = FirebaseFirestore.instance.collection(AppConstants.colUsers).doc(uid);
      final snap = await ref.get();
      final current = ((snap.data()?['fcmTokens'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      if (current.contains(token)) return;
      final next = [...current.reversed.take(4).toList().reversed, token];
      await ref.set({'fcmTokens': next}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[notifications] could not save the push token: $e');
    }
  }

  Future<void> _forgetToken(String uid) async {
    final token = _token;
    if (token == null) return;
    try {
      await FirebaseFirestore.instance.collection(AppConstants.colUsers).doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[notifications] could not remove the push token: $e');
    }
    _token = null;
  }

  /// Sign-out helper: forget this phone BEFORE the session ends, so the next
  /// person on the same phone does not receive the previous user's alerts.
  Future<void> prepareSignOut() async {
    final uid = _uid;
    if (uid == null) return;
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _forgetToken(uid);
    try {
      if (AppConfig.pushAvailable) await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[notifications] deleteToken failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Showing pop-ups
  // ---------------------------------------------------------------------------

  bool get _appInForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool _allowed(String type) {
    final s = SettingsStore.instance;
    return type == 'new_message' ? s.messageAlerts : s.matchAlerts;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final type = (data['type'] as String?) ?? 'match_found';
    if (!_allowed(type)) return;
    final key = (data['notificationId'] as String?) ?? message.messageId ?? '';
    if (key.isNotEmpty && !_announced.add(key)) return;
    final n = message.notification;
    show(
      id: key,
      title: n?.title ?? 'smartFind',
      body: n?.body ?? '',
      data: data,
    );
  }

  void _watchFeed(String uid) {
    _feedSub = FirestoreService.instance.watchNotifications(uid).listen(
      (list) {
        if (!_feedPrimed) {
          // Everything that exists when the app starts counts as seen.
          _announced.addAll(list.map((n) => n.id));
          _feedPrimed = true;
          return;
        }
        for (final n in list.reversed) {
          if (n.isRead || !_announced.add(n.id)) continue;
          if (DateTime.now().difference(n.createdAt).inMinutes > 30) continue;
          if (!_allowed(n.type.value)) continue;
          // With a server, the system already shows it while we are in the
          // background; only draw it ourselves when the app is on screen or
          // when there is no server at all.
          if (!_appInForeground && AppConfig.pushApiConfigured) continue;
          show(
            id: n.id,
            title: n.title,
            body: n.body,
            data: {
              'type': n.type.value,
              'itemId': n.itemId ?? '',
              'chatId': n.chatId ?? '',
              'notificationId': n.id,
            },
          );
        }
      },
      onError: (Object e) => debugPrint('[notifications] feed error: $e'),
    );
  }

  /// Message pop-ups without a server: while the app process is alive, a new
  /// message in any conversation is drawn as a pop-up. With a server
  /// configured, the server pushes messages instead (also when the app is
  /// closed), so this watcher stays off to avoid duplicates.
  void _watchChats(String uid) {
    if (AppConfig.pushApiConfigured) return;
    _chatSub = MessagingService.instance.watchChats(uid).listen(
      (chats) {
        if (!_chatsPrimed) {
          for (final c in chats) {
            _chatUnread[c.id] = c.unreadFor(uid);
          }
          _chatsPrimed = true;
          return;
        }
        for (final c in chats) {
          final now = c.unreadFor(uid);
          final before = _chatUnread[c.id] ?? 0;
          _chatUnread[c.id] = now;
          if (now <= before || c.lastMessage.isEmpty) continue;
          if (openChatId == c.id && _appInForeground) continue;
          if (!_allowed('new_message')) continue;
          final key = 'msg_${c.id}_${c.lastMessageAt.millisecondsSinceEpoch}';
          if (!_announced.add(key)) continue;
          show(
            id: key,
            title: 'Message from ${c.otherParticipantName(uid)}',
            body: c.lastMessage,
            data: {
              'type': 'new_message',
              'chatId': c.id,
              'itemId': c.itemId,
              'notificationId': key,
            },
          );
        }
      },
      onError: (Object e) => debugPrint('[notifications] chat watch error: $e'),
    );
  }

  /// Draws a heads-up pop-up. The complete [body] is part of the notification
  /// (expanded "big text" style), so long messages wrap instead of being cut.
  Future<void> show({
    required String id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (!_supported || !_initialized) return;
    final type = (data['type'] as String?) ?? 'match_found';
    final channel = type == 'new_message' ? messageChannelId : matchChannelId;
    try {
      await _local.show(
        id: (id.isEmpty ? DateTime.now().millisecondsSinceEpoch : id.hashCode) & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channel == matchChannelId ? 'Possible matches' : 'Messages',
            channelDescription: channel == matchChannelId
                ? 'Alerts when a report looks like yours.'
                : 'New chat messages about lost and found items.',
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.message,
            styleInformation: BigTextStyleInformation(body, contentTitle: title),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('[notifications] could not show a pop-up: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Tapping
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) return <String, dynamic>{};
    try {
      final v = jsonDecode(payload);
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Opens what the notification is about. Stored until the signed-in area of
  /// the app is on screen if the user tapped it while the app was starting.
  void _onTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _pendingTap = data;
    flushPendingTap();
  }

  /// Called by the main screen once it is showing.
  Future<void> flushPendingTap() async {
    final data = _pendingTap;
    final nav = _navigatorKey?.currentState;
    if (data == null || nav == null || _uid == null) return;
    _pendingTap = null;

    final type = data['type'] as String? ?? '';
    final itemId = data['itemId'] as String? ?? '';
    final chatId = data['chatId'] as String? ?? '';
    try {
      if (type == 'new_message' && chatId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection(AppConstants.colChats)
            .doc(chatId)
            .get();
        if (doc.exists) {
          nav.pushNamed(AppConstants.routeChatDetail, arguments: ChatModel.fromFirestore(doc));
          return;
        }
        nav.pushNamed(AppConstants.routeChats);
        return;
      }
      if (itemId.isNotEmpty) {
        final item = await FirestoreService.instance.fetchItem(itemId);
        if (item != null) {
          nav.pushNamed(AppConstants.routeItemDetail, arguments: item);
          return;
        }
      }
      nav.pushNamed(AppConstants.routeNotifications);
    } catch (e) {
      debugPrint('[notifications] could not open the target: $e');
      nav.pushNamed(AppConstants.routeNotifications);
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
    await _openedSub?.cancel();
    await _feedSub?.cancel();
    await _chatSub?.cancel();
  }
}
