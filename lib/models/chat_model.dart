import 'package:cloud_firestore/cloud_firestore.dart';

/// A 1:1 conversation between two users about a specific item.
///
/// Firestore document at `/chats/{chatId}` with subcollection
/// `/chats/{chatId}/messages/{messageId}`.
class ChatModel {
  ChatModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.itemId,
    required this.itemTitle,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    this.unread = const <String, int>{},
  });

  factory ChatModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawUnread = data['unread'];
    final unread = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (key is String && value is num) unread[key] = value.toInt();
      });
    }
    return ChatModel(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] as List? ?? []),
      participantNames: List<String>.from(
        data['participantNames'] as List? ?? [],
      ),
      itemId: data['itemId'] as String? ?? '',
      itemTitle: data['itemTitle'] as String? ?? 'Item',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unread: unread,
    );
  }

  final String id;
  final List<String> participantIds;
  final List<String> participantNames;
  final String itemId;
  final String itemTitle;
  final String lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  /// Unread message count **per participant** (uid → count). Each person only
  /// ever sees their own number.
  final Map<String, int> unread;

  /// Unread messages for [userId].
  int unreadFor(String userId) => unread[userId] ?? 0;

  /// Returns the OTHER participant's name (not the current user).
  String otherParticipantName(String currentUserId) {
    final idx = participantIds.indexOf(currentUserId);
    if (idx == -1) {
      return participantNames.isNotEmpty ? participantNames.first : 'Unknown';
    }
    final otherIdx = idx == 0 ? 1 : 0;
    return participantNames.length > otherIdx
        ? participantNames[otherIdx]
        : 'Unknown';
  }

  /// Returns the OTHER participant's user id, or `null` if there is none.
  String? otherParticipantId(String currentUserId) {
    for (final id in participantIds) {
      if (id != currentUserId) return id;
    }
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'unread': unread,
    };
  }
}

/// A single message in a chat. Firestore doc at
/// `/chats/{chatId}/messages/{messageId}`.
class MessageModel {
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.attachmentUrl = '',
  });

  factory MessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? 'unknown',
      senderName: data['senderName'] as String? ?? 'Anonymous',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentUrl: data['attachmentUrl'] as String? ?? '',
    );
  }

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final String attachmentUrl;

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'attachmentUrl': attachmentUrl,
    };
  }
}
