import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../services/messaging_service.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';
import '../widgets/user_avatar.dart';
import 'chat_detail_screen.dart';

/// All conversations of the signed-in person, newest first.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  // Created once so rebuilds do not re-subscribe to Firestore.
  late final String _userId = context.read<AuthState>().user?.id ?? '';
  late final Stream<List<ChatModel>> _chats = MessagingService.instance
      .watchChats(_userId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: StreamBuilder<List<ChatModel>>(
          stream: _chats,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                title: 'Could not load conversations',
                subtitle: 'Check your connection and try again later.',
                icon: Icons.cloud_off_rounded,
              );
            }
            if (!snapshot.hasData) return const LoadingIndicator();
            final chats = snapshot.data!;
            if (chats.isEmpty) {
              return const EmptyState(
                title: 'No conversations yet',
                subtitle:
                    'Open a report and tap the message button to start one. '
                    'Replies show up here.',
                icon: Icons.chat_bubble_outline_rounded,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              itemCount: chats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final chat = chats[i];
                return FadeSlideIn(
                  key: ValueKey(chat.id),
                  delay: FadeSlideIn.stagger(i, stepMs: 30, maxMs: 240),
                  child: _ChatRow(
                    chat: chat,
                    otherName: chat.otherParticipantName(_userId),
                    unread: chat.unreadFor(_userId),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatDetailScreen(chat: chat),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.otherName,
    required this.unread,
    required this.onTap,
  });

  final ChatModel chat;
  final String otherName;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = chat.lastMessage.isEmpty
        ? 'Start the conversation about ${chat.itemTitle}'
        : chat.lastMessage;
    return Pressable(
      onTap: onTap,
      semanticLabel:
          'Conversation with $otherName about ${chat.itemTitle}'
          '${unread > 0 ? ', $unread unread' : ''}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(name: otherName, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.timeAgo(chat.lastMessageAt),
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'About: ${chat.itemTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: unread > 0
                                ? AppColors.textPrimaryOf(context)
                                : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentOf(context),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: AppTextStyles.overline.copyWith(
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
