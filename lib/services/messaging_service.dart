import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_model.dart';
import '../utils/constants.dart';

/// Realtime 1:1 chat backed by Firestore.
///
/// Chats live at `/chats/{chatId}` with the messages in the sub-collection
/// `/chats/{chatId}/messages/{messageId}`.
class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  /// How many of the newest messages a conversation loads.
  static const int messageLimit = 200;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection(AppConstants.colChats);

  /// Deterministic id, so the same two people always share one conversation
  /// per item: `chat_<smallerUid>_<largerUid>_<itemId>`.
  static String chatIdFor(String userA, String userB, String itemId) {
    final ids = [userA, userB]..sort();
    return 'chat_${ids.join('_')}_$itemId';
  }

  /// Finds the conversation about [itemId] between the two users, creating it
  /// the first time.
  Future<ChatModel> getOrCreateChat({
    required String currentUserId,
    required String currentUserDisplayName,
    required String otherUserId,
    required String otherUserDisplayName,
    required String itemId,
    required String itemTitle,
  }) async {
    if (currentUserId == otherUserId) {
      throw ArgumentError('You cannot start a chat with yourself.');
    }
    final chatId = chatIdFor(currentUserId, otherUserId, itemId);
    final docRef = _chats.doc(chatId);

    final existing = await docRef.get();
    if (existing.exists) return ChatModel.fromFirestore(existing);

    final now = DateTime.now();
    final chat = ChatModel(
      id: chatId,
      participantIds: [currentUserId, otherUserId],
      participantNames: [currentUserDisplayName, otherUserDisplayName],
      itemId: itemId,
      itemTitle: itemTitle,
      lastMessage: '',
      lastMessageAt: now,
      createdAt: now,
      unread: {currentUserId: 0, otherUserId: 0},
    );
    await docRef.set(chat.toFirestore());
    return chat;
  }

  /// One conversation by id, or null when it does not exist (any more).
  Future<ChatModel?> fetchChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    return doc.exists ? ChatModel.fromFirestore(doc) : null;
  }

  /// All conversations [userId] takes part in, most recent first.
  Stream<List<ChatModel>> watchChats(String userId) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map(ChatModel.fromFirestore).toList()
            ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return chats;
        });
  }

  /// The newest [messageLimit] messages, oldest first.
  Stream<List<MessageModel>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection(AppConstants.colMessages)
        .orderBy('sentAt', descending: true)
        .limit(messageLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MessageModel.fromFirestore)
              .toList()
              .reversed
              .toList(),
        );
  }

  /// Sends a text message and updates the chat summary in one atomic batch.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection(AppConstants.colMessages).doc();

    final batch = _db.batch();
    batch.set(messageRef, {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'attachmentUrl': '',
    });
    batch.update(chatRef, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      // Only the RECIPIENT gets an unread message — never the sender.
      'unread.$recipientId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Resets [userId]'s unread counter for [chatId].
  Future<void> markRead(String chatId, String userId) async {
    try {
      await _chats.doc(chatId).update({'unread.$userId': 0});
    } on FirebaseException {
      // Not critical (e.g. offline): the badge just stays a bit longer.
    }
  }
}
