import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Small building blocks shared by the admin tabs.

/// A selectable filter pill ("Awaiting review", "Suspended", ...).
class AdminFilterPill extends StatelessWidget {
  const AdminFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label  $count';
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: AppTextStyles.captionMedium.copyWith(
        color: selected
            ? AppColors.backgroundOf(context)
            : AppColors.textSecondaryOf(context),
      ),
      selectedColor: AppColors.textPrimaryOf(context),
      backgroundColor: AppColors.cardOf(context),
      side: BorderSide(
        color: selected
            ? AppColors.textPrimaryOf(context)
            : AppColors.borderOf(context),
      ),
      shape: const StadiumBorder(),
    );
  }
}

/// A tiny coloured tag ("Admin", "Suspended", "Verified").
class AdminTag extends StatelessWidget {
  const AdminTag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  factory AdminTag.verified(BuildContext context) => AdminTag(
    label: 'Verified',
    icon: Icons.verified_rounded,
    background: AppColors.successBgOf(context),
    foreground: AppColors.successFgOf(context),
  );

  factory AdminTag.pending(BuildContext context) => AdminTag(
    label: 'Awaiting review',
    icon: Icons.schedule_rounded,
    background: AppColors.warningBgOf(context),
    foreground: AppColors.warning,
  );

  factory AdminTag.admin(BuildContext context) => AdminTag(
    label: 'Admin',
    icon: Icons.shield_outlined,
    background: AppColors.primarySurfaceOf(context),
    foreground: AppColors.primaryOf(context),
  );

  factory AdminTag.banned(BuildContext context) => AdminTag(
    label: 'Suspended',
    icon: Icons.block_rounded,
    background: AppColors.errorBgOf(context),
    foreground: AppColors.errorFgOf(context),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search box used at the top of the Reports / Users / Buildings tabs.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        isDense: true,
        filled: true,
        fillColor: AppColors.cardOf(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderOf(context)),
        ),
      ),
    );
  }
}

/// Runs [action] and shows a snack bar with [success] or the error.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (e) {
    debugPrint('[admin] action failed: $e');
    final denied = e.toString().contains('permission-denied');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          denied
              ? 'Not allowed. Are the latest Firestore rules deployed?'
              : 'That did not work. Check your connection and try again.',
        ),
      ),
    );
    return false;
  }
}

/// A yes / no dialog. Returns true when the person confirmed.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
