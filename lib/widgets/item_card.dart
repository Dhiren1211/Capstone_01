import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../services/image_upload_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'motion.dart';
import 'status_badge.dart';

/// One report in a list.
///
/// * default: a horizontal row (photo on the left, text on the right);
/// * [compact]: a narrow vertical card for horizontal carousels. Give it a
///   width (e.g. `SizedBox(width: 200)`); its height follows its content.
///
/// All text is limited with ellipsis, so no combination of content, font
/// scale or screen width can overflow.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.compact = false,
    this.matchConfidence,
  });

  final ItemModel item;
  final VoidCallback? onTap;
  final bool compact;

  /// Optional match percentage (0-100); shown as a chip when it is >= 70.
  final int? matchConfidence;

  @override
  Widget build(BuildContext context) {
    final card = compact ? _vertical(context) : _row(context);
    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${item.statusEnum.label}: ${item.title}, ${item.location}',
      child: card,
    );
  }

  BoxDecoration _box(BuildContext context) => BoxDecoration(
    color: AppColors.cardOf(context),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: AppColors.borderOf(context)),
    boxShadow: AppColors.softShadowOf(context),
  );

  Widget _row(BuildContext context) {
    final cat = ItemCategory.fromValue(item.category);
    return Container(
      decoration: _box(context),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 92,
              height: 92,
              child: _thumbnail(context, 92),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    StatusBadge(status: item.statusEnum, compact: true),
                    if (item.verified) ...[
                      const SizedBox(width: 4),
                      const VerifiedMark(size: 15),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    if (matchConfidence != null && matchConfidence! >= 70)
                      _MatchChip(percent: matchConfidence!),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3Bold.copyWith(
                    fontSize: 16,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: AppColors.textTertiaryOf(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.timeAgo(item.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textTertiaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertical(BuildContext context) {
    return Container(
      decoration: _box(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumbnail(context, 200),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: item.statusEnum, compact: true),
                      if (item.verified) ...[
                        const SizedBox(width: 4),
                        const VerifiedMark(size: 15),
                      ],
                    ],
                  ),
                ),
                if (matchConfidence != null && matchConfidence! >= 70)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _MatchChip(percent: matchConfidence!),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(BuildContext context, double size) {
    final placeholder = ColoredBox(
      color: AppColors.primarySurfaceOf(context),
      child: Center(
        child: Icon(
          ItemCategory.fromValue(item.category).icon,
          color: AppColors.textTertiaryOf(context),
          size: 30,
        ),
      ),
    );
    if (item.imageUrl.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: ImageUploadService.optimizedUrl(item.imageUrl, width: 480),
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => ColoredBox(color: AppColors.chipIdleOf(context)),
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentSurfaceOf(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent% match',
        maxLines: 1,
        style: AppTextStyles.overline.copyWith(
          letterSpacing: 0.2,
          color: AppColors.accentOf(context),
        ),
      ),
    );
  }
}
