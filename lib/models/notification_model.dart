import 'package:cloud_firestore/cloud_firestore.dart';

/// In-app notification. Firestore doc at `/notifications/{notificationId}`.
class NotificationModel {
  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.itemId,
    this.chatId,
    this.imageHint = '',
    this.itemStatus = '',
    this.otherItemId,
    this.score,
  });

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: NotificationTypeX.fromValue(data['type'] as String? ?? 'system'),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      itemId: data['itemId'] as String?,
      chatId: data['chatId'] as String?,
      imageHint: data['imageHint'] as String? ?? '',
      itemStatus: data['itemStatus'] as String? ?? '',
      otherItemId: data['otherItemId'] as String?,
      score: (data['score'] as num?)?.toInt(),
    );
  }

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? itemId;
  final String? chatId;
  final String imageHint;

  /// 'lost' or 'found': the kind of item that [itemId] points to (used by the
  /// Lost / Found filter tabs). Empty for older notifications.
  final String itemStatus;

  /// For match alerts: the report of the person themself that matched.
  final String? otherItemId;

  /// For match alerts: confidence in percent (0-100).
  final int? score;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.value,
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'itemId': itemId,
      'chatId': chatId,
      'imageHint': imageHint,
      'itemStatus': itemStatus,
      if (otherItemId != null) 'otherItemId': otherItemId,
      if (score != null) 'score': score,
    };
  }

  NotificationModel copyWithRead({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      itemId: itemId,
      chatId: chatId,
      imageHint: imageHint,
      itemStatus: itemStatus,
      otherItemId: otherItemId,
      score: score,
    );
  }
}

enum NotificationType { matchFound, newMessage, system }

extension NotificationTypeX on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.matchFound:
        return 'match_found';
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.system:
        return 'system';
    }
  }

  static NotificationType fromValue(String value) {
    switch (value) {
      case 'match_found':
        return NotificationType.matchFound;
      case 'new_message':
        return NotificationType.newMessage;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}
