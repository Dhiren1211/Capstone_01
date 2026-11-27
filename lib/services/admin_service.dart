import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/item_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/ksu_buildings.dart';

/// Headline numbers for the admin overview.
class AdminStats {
  const AdminStats({
    required this.users,
    required this.newUsers7d,
    required this.bannedUsers,
    required this.admins,
    required this.reports,
    required this.lost,
    required this.found,
    required this.reunited,
    required this.verified,
    required this.verifiedOpen,
  });

  final int users;

  /// Accounts created in the last 7 days.
  final int newUsers7d;
  final int bannedUsers;
  final int admins;
  final int reports;
  final int lost;
  final int found;
  final int reunited;
  final int verified;

  /// Verified reports that are still open (lost / found).
  final int verifiedOpen;

  /// Open reports that no admin has checked yet.
  int get awaitingReview => (lost + found - verifiedOpen).clamp(0, 1 << 30);
}

/// Who is an admin, and everything only admins may do.
///
/// An admin is a verified user that has a document at `/admins/{uid}`. The
/// Firestore rules check the same document, so nothing here can be done from
/// a non-admin account even with a modified app.
///
/// The FIRST admin has to be created by hand (Firebase console, or
/// `node scripts/make-admin.mjs <email>` against the emulators); after that,
/// admins can promote other users from the panel.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection(AppConstants.colAdmins);
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AppConstants.colUsers);
  CollectionReference<Map<String, dynamic>> get _items =>
      _db.collection(AppConstants.colItems);
  DocumentReference<Map<String, dynamic>> get _buildingsDoc =>
      _db.collection(AppConstants.colConfig).doc(AppConstants.docBuildings);

  // ---------------------------------------------------------------------------
  // Role
  // ---------------------------------------------------------------------------

  /// Emits whether [uid] is an admin, and again whenever that changes.
  /// Errors (e.g. offline, rules not deployed yet) count as "not an admin".
  Stream<bool> watchIsAdmin(String uid) {
    return _admins
        .doc(uid)
        .snapshots()
        .map((d) => d.exists)
        .handleError((Object e) => debugPrint('[admin] role check failed: $e'));
  }

  /// Uids of every admin.
  Stream<Set<String>> watchAdminIds() {
    return _admins.snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> setAdmin(UserModel user, bool admin, {required String byUid}) {
    final ref = _admins.doc(user.id);
    if (!admin) return ref.delete();
    return ref.set({
      'email': user.email,
      'displayName': user.displayName,
      'addedBy': byUid,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  /// Counts use Firestore aggregate queries: one cheap request each, no
  /// matter how many documents there are.
  Future<AdminStats> fetchStats() async {
    Future<int> count(Query<Map<String, dynamic>> q) async =>
        (await q.count().get()).count ?? 0;

    final results = await Future.wait([
      count(_users),
      count(_users.where('banned', isEqualTo: true)),
      count(
        _users.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
        ),
      ),
      count(_admins),
      count(_items),
      count(_items.where('status', isEqualTo: 'lost')),
      count(_items.where('status', isEqualTo: 'found')),
      count(_items.where('status', isEqualTo: 'reunited')),
      count(_items.where('verified', isEqualTo: true)),
      // Equality-only filters: served without a composite index.
      count(
        _items
            .where('verified', isEqualTo: true)
            .where('status', whereIn: ['lost', 'found']),
      ),
    ]);
    return AdminStats(
      users: results[0],
      bannedUsers: results[1],
      newUsers7d: results[2],
      admins: results[3],
      reports: results[4],
      lost: results[5],
      found: results[6],
      reunited: results[7],
      verified: results[8],
      verifiedOpen: results[9],
    );
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  /// The newest [limit] accounts.
  Stream<List<UserModel>> watchUsers({int limit = 500}) {
    return _users
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
          final out = <UserModel>[];
          for (final d in s.docs) {
            try {
              out.add(UserModel.fromFirestore(d));
            } catch (e) {
              debugPrint('[admin] skipped malformed user ${d.id}: $e');
            }
          }
          return out;
        });
  }

  Future<void> setBanned(String uid, bool banned, {String reason = ''}) {
    return _users.doc(uid).update({
      'banned': banned,
      'bannedReason': banned ? reason.trim() : '',
      'bannedAt': banned ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Reports posted by [uid], newest first.
  Stream<List<ItemModel>> watchItemsOf(String uid) {
    return _items.where('reporterId', isEqualTo: uid).snapshots().map(
      (s) =>
          s.docs.map(ItemModel.fromFirestore).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  /// The newest [limit] reports (any status).
  Stream<List<ItemModel>> watchAllItems({int limit = 300}) {
    return _items
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
          final out = <ItemModel>[];
          for (final d in s.docs) {
            try {
              out.add(ItemModel.fromFirestore(d));
            } catch (e) {
              debugPrint('[admin] skipped malformed item ${d.id}: $e');
            }
          }
          return out;
        });
  }

  Future<void> setVerified(String itemId, bool verified, {required String byUid}) {
    return _items.doc(itemId).update({
      'verified': verified,
      'verifiedBy': verified ? byUid : '',
      'verifiedAt': verified ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Removes a report and corrects the reporter's post counter.
  Future<void> deleteItem(ItemModel item) async {
    final batch = _db.batch();
    batch.delete(_items.doc(item.id));
    batch.update(_users.doc(item.reporterId), {
      'postsCount': FieldValue.increment(-1),
    });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // The reporter's profile may be gone; still remove the report.
      if (e.code != 'not-found') rethrow;
      await _items.doc(item.id).delete();
    }
  }

  // ---------------------------------------------------------------------------
  // Building positions
  // ---------------------------------------------------------------------------

  /// Live admin overrides from `config/buildings`.
  Stream<Map<String, dynamic>?> watchBuildingPositions() {
    return _buildingsDoc.snapshots().map((d) => d.data());
  }

  /// Moves [building] to ([lat], [lng]) for everyone.
  Future<void> setBuildingPosition(
    KsuBuilding building,
    double lat,
    double lng, {
    required String byUid,
  }) {
    if (!BuildingPositions.isValid(lat, lng)) {
      throw ArgumentError('Coordinates out of range');
    }
    return _buildingsDoc.set({
      'positions': {
        building.name: [lat, lng],
      },
      'updatedBy': byUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Puts [building] back at its built-in (or surveyed) position.
  Future<void> resetBuildingPosition(
    KsuBuilding building, {
    required String byUid,
  }) {
    return _buildingsDoc.update({
      FieldPath(['positions', building.name]): FieldValue.delete(),
      'updatedBy': byUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Keeps [BuildingPositions]' admin layer in step with Firestore while
/// someone is signed in (the document is only readable when signed in).
class BuildingPositionsSync {
  BuildingPositionsSync._();
  static final BuildingPositionsSync instance = BuildingPositionsSync._();

  StreamSubscription<Map<String, dynamic>?>? _sub;

  void bind(bool signedIn) {
    if (!signedIn) {
      _sub?.cancel();
      _sub = null;
      return;
    }
    _sub ??= AdminService.instance.watchBuildingPositions().listen(
      BuildingPositions.applyAdmin,
      onError: (Object e) => debugPrint('[buildings] sync failed: $e'),
    );
  }
}
