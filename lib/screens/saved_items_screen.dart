import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../services/firestore_service.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';
import 'item_detail_screen.dart';

/// Reports the person has bookmarked.
class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  // Created once so rebuilds do not re-subscribe to Firestore.
  late final Stream<List<ItemModel>> _stream = FirestoreService.instance
      .watchSavedItems(context.read<AuthState>().user?.id ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('Saved reports')),
      body: SafeArea(
        child: StreamBuilder<List<ItemModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                title: 'Could not load saved reports',
                subtitle: 'Check your connection and try again later.',
                icon: Icons.cloud_off_rounded,
              );
            }
            if (!snapshot.hasData) return const LoadingIndicator();
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const EmptyState(
                title: 'Nothing saved yet',
                subtitle:
                    'Tap the bookmark on a report to keep it here for later.',
                icon: Icons.bookmark_border_rounded,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = items[i];
                return FadeSlideIn(
                  key: ValueKey(item.id),
                  delay: FadeSlideIn.stagger(i, stepMs: 30, maxMs: 240),
                  child: ItemCard(
                    item: item,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ItemDetailScreen(item: item),
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
