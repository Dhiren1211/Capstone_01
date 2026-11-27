import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

/// Application user profile.
///
/// Firestore document at `/users/{userId}` (readable and writable only by its
/// owner).
class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
    this.studentId = '',
    this.postsCount = 0,
    this.savedItemIds = const <String>[],
    this.banned = false,
    this.bannedReason = '',
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final posts = (data['postsCount'] as num?)?.toInt() ?? 0;
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Student',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      postsCount: posts < 0 ? 0 : posts,
      savedItemIds: List<String>.from(
        (data['savedItemIds'] as List?)?.whereType<String>() ??
            const <String>[],
      ),
      banned: data['banned'] as bool? ?? false,
      bannedReason: data['bannedReason'] as String? ?? '',
    );
  }

  /// Fallback built from the Firebase Auth account when the profile document
  /// does not exist (yet).
  factory UserModel.fromAuthUser(User user) {
    final email = user.email ?? '';
    final name = (user.displayName ?? '').trim();
    return UserModel(
      id: user.uid,
      email: email,
      displayName: name.isNotEmpty
          ? name
          : (email.contains('@') ? email.split('@').first : 'Student'),
      avatarUrl: user.photoURL ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String studentId;
  final DateTime createdAt;
  final int postsCount;
  final List<String> savedItemIds;

  /// Suspended by an admin: the person can still sign in but cannot post,
  /// chat or use the app until an admin lifts the suspension.
  final bool banned;
  final String bannedReason;

  int get savedCount => savedItemIds.length;

  /// First-name part of [displayName] for greeting ("Hi Alex").
  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  /// Fields written when the profile document is first created.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'studentId': studentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'postsCount': postsCount,
      'savedItemIds': savedItemIds,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? studentId,
    int? postsCount,
    List<String>? savedItemIds,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt,
      postsCount: postsCount ?? this.postsCount,
      savedItemIds: savedItemIds ?? this.savedItemIds,
      banned: banned,
      bannedReason: bannedReason,
    );
  }
}
