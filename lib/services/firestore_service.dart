import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../utils/constants.dart';
import 'matching_service.dart';

/// CRUD + queries for items, saved items and notifications.
///
/// Design note — **no composite indexes needed.** Every query below is either
/// a single-field `orderBy`, or a plain equality filter. Anything that would
/// need a composite index (filter + sort) is sorted/filtered in memory
/// instead, so the app works on a fresh Firebase project without deploying
/// any index.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection(AppConstants.colItems);
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AppConstants.colUsers);
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(AppConstants.colNotifications);

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  /// The newest [limit] items, optionally narrowed by status / category.
  Stream<List<ItemModel>> watchItems({
    String? statusFilter,
    String? categoryFilter,
    int limit = AppConstants.itemsFeedLimit,
  }) {
    return _items
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          var items = _parseItems(snapshot.docs);
          if (statusFilter != null && statusFilter != 'all') {
            items = items.where((i) => i.status == statusFilter).toList();
          }
          if (categoryFilter != null && categoryFilter != 'all') {
            items = items.where((i) => i.category == categoryFilter).toList();
          }
          return items;
        });
  }

  /// Parses documents one by one: a single malformed report (e.g. a field
  /// stored with the wrong type) is skipped and logged instead of turning
  /// the whole feed into an error.
  static List<ItemModel> _parseItems(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <ItemModel>[];
    for (final d in docs) {
      try {
        out.add(ItemModel.fromFirestore(d));
      } catch (e) {
        debugPrint('[items] skipped malformed item ${d.id}: $e');
      }
    }
    return out;
  }

  /// Items reported by [userId], newest first.
  Stream<List<ItemModel>> watchMyItems(String userId) {
    return _items.where('reporterId', isEqualTo: userId).snapshots().map((s) {
      final items = _parseItems(s.docs)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<ItemModel?> fetchItem(String itemId) async {
    final doc = await _items.doc(itemId).get();
    if (!doc.exists) return null;
    return ItemModel.fromFirestore(doc);
  }

  /// Saves a new report and bumps the reporter's post counter in ONE atomic
  /// batch. Afterwards, looks for matching reports of the opposite kind.
  Future<ItemModel> createItem(ItemModel item, {List<ItemModel>? feed}) async {
    final docRef = _items.doc();
    final withId = item.withId(docRef.id);

    final data = withId.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final batch = _db.batch();
    batch.set(docRef, data);
    batch.set(_users.doc(item.reporterId), {
      'postsCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();

    // Matching is best-effort: it must never make the report itself fail, nor
    // keep the person waiting for long. (A slow server call carries on in the
    // background after the timeout.)
    try {
      await MatchingService.instance
          .findMatchesForNewItem(withId, feed: feed)
          .timeout(const Duration(seconds: 6), onTimeout: () => const []);
    } catch (e) {
      debugPrint('[matching] skipped: $e');
    }
    return withId;
  }

  /// Marks an item as reunited (closed).
  Future<void> markReunited(String itemId) async {
    await _items.doc(itemId).update({
      'reunited': true,
      'status': 'reunited',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an item (owner only — enforced by the Firestore rules).
  Future<void> deleteItem(ItemModel item) async {
    final batch = _db.batch();
    batch.delete(_items.doc(item.id));
    batch.set(_users.doc(item.reporterId), {
      'postsCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Recent items of the given status that are still open. Used by matching.
  Future<List<ItemModel>> recentOpenItems({
    required String status,
    int limit = AppConstants.itemsFeedLimit,
  }) async {
    final snap = await _items
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map(ItemModel.fromFirestore)
        .where((i) => i.status == status && !i.reunited)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Saved items (stored as an id list on the user's own profile document)
  // ---------------------------------------------------------------------------

  Future<void> saveItem(String userId, String itemId) {
    return _users.doc(userId).set({
      'savedItemIds': FieldValue.arrayUnion([itemId]),
    }, SetOptions(merge: true));
  }

  Future<void> unsaveItem(String userId, String itemId) {
    return _users.doc(userId).set({
      'savedItemIds': FieldValue.arrayRemove([itemId]),
    }, SetOptions(merge: true));
  }

  Future<bool> isSaved(String userId, String itemId) async {
    final doc = await _users.doc(userId).get();
    final saved = (doc.data()?['savedItemIds'] as List?) ?? const [];
    return saved.contains(itemId);
  }

  Stream<List<String>> watchSavedIds(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      final saved = (doc.data()?['savedItemIds'] as List?) ?? const [];
      return saved.whereType<String>().toList();
    });
  }

  /// The actual saved items. Fetches each document directly, so there is no
  /// "10 / 30 ids per query" limit; deleted items are silently skipped.
  Stream<List<ItemModel>> watchSavedItems(String userId) {
    return watchSavedIds(userId).asyncMap((ids) async {
      if (ids.isEmpty) return <ItemModel>[];
      final docs = await Future.wait(ids.map((id) => _items.doc(id).get()));
      return docs.where((d) => d.exists).map(ItemModel.fromFirestore).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _notifications.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs.map(NotificationModel.fromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Writes a notification (for the current user, or — for match alerts — for
  /// the other person).
  Future<void> createNotification(NotificationModel n, {String? id}) async {
    final ref = id == null ? _notifications.doc() : _notifications.doc(id);
    final data = n.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['isRead'] = false;
    await ref.set(data);
  }

  Future<void> markNotificationRead(String notificationId) {
    return _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snapshot = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Count of unread notifications (for badges).
  Stream<int> watchUnreadCount(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }
}
