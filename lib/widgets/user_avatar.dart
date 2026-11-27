import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Round avatar: the photo when there is one, otherwise the initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    final first = String.fromCharCode(list.first.runes.first);
    if (list.length == 1) return first.toUpperCase();
    final last = String.fromCharCode(list.last.runes.first);
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceOf(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: size * 0.36,
          color: AppColors.primaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
