import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';
import '../services/push_api.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/user_avatar.dart';
import 'item_detail_screen.dart';

/// One conversation. Messages update live; sending also asks the server (if
/// configured) to push the message to the other person's phone.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.chat});

  final ChatModel chat;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Created once. Building a new stream inside build() would re-subscribe to
  // Firestore on every rebuild.
  late final Stream<List<MessageModel>> _messages = MessagingService.instance
      .watchMessages(widget.chat.id);

  String _userId = '';
  int _lastCount = 0;
  bool _sending = false;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _userId = context.read<AuthState>().user?.id ?? '';
    NotificationService.instance.openChatId = widget.chat.id;
    if (_userId.isNotEmpty) {
      unawaited(MessagingService.instance.markRead(widget.chat.id, _userId));
    }
    _msgCtrl.addListener(() {
      final can = _msgCtrl.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    if (NotificationService.instance.openChatId == widget.chat.id) {
      NotificationService.instance.openChatId = null;
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final user = context.read<AuthState>().user;
    if (user == null) return;
    final recipientId = widget.chat.otherParticipantId(user.id);
    if (recipientId == null) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MessagingService.instance.sendMessage(
        chatId: widget.chat.id,
        senderId: user.id,
        senderName: user.displayName,
        recipientId: recipientId,
        text: text,
      );
      _msgCtrl.clear(); // only cleared once the message really went out
      // Best effort: lets the server push it to the other phone, also when
      // that app is closed. Failure is silent - the message is already stored.
      unawaited(PushApi.instance.announceMessage(widget.chat.id, text));
    } catch (e) {
      debugPrint('[chat] send failed: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Message could not be sent. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openItem() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final ItemModel? item = await FirestoreService.instance.fetchItem(
        widget.chat.itemId,
      );
      if (item == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This report no longer exists.')),
        );
        return;
      }
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(item: item)),
      );
    } catch (e) {
      debugPrint('[chat] open item failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthState, String>((a) => a.user?.id ?? '');
    final otherName = widget.chat.otherParticipantName(userId);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: otherName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Text(
                    widget.chat.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open the report',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: _openItem,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load the conversation.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) return const LoadingIndicator();
                  final messages = snapshot.data!;
                  if (messages.length != _lastCount) {
                    final grew = messages.length > _lastCount;
                    _lastCount = messages.length;
                    if (grew) {
                      _scrollToEnd();
                      if (_userId.isNotEmpty) {
                        unawaited(
                          MessagingService.instance.markRead(
                            widget.chat.id,
                            _userId,
                          ),
                        );
                      }
                    }
                  }
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: AppColors.textTertiaryOf(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: AppTextStyles.h3Bold.copyWith(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Say hello to $otherName about '
                              '"${widget.chat.itemTitle}".',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      return _Bubble(
                        message: msg,
                        isMine: msg.senderId == userId,
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _msgCtrl,
              canSend: _canSend,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final active = canSend && !sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Write a message',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppColors.primaryOf(context),
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: active,
            label: 'Send message',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: active ? onSend : null,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bg = isMine
        ? AppColors.primaryOf(context)
        : AppColors.cardOf(context);
    final fg = isMine
        ? AppColors.onPrimaryOf(context)
        : AppColors.textPrimaryOf(context);
    final sub = fg.withValues(alpha: 0.7);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine
              ? null
              : Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.text,
                style: AppTextStyles.body.copyWith(color: fg),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.timeAgo(message.sentAt),
              style: AppTextStyles.micro.copyWith(color: sub),
            ),
          ],
        ),
      ),
    );
  }
}
