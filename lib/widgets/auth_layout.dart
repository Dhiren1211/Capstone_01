import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'motion.dart';
import 'smartfind_logo.dart';

/// Shared frame for sign-in, sign-up, password reset and e-mail verification:
/// brand row, title, subtitle and the form, in one scrollable column that is
/// centred and capped at 440 px wide on large screens. It scrolls above the
/// keyboard, so no field can ever overflow.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
    this.footer,
    this.leading,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Row of text under the form (for example "No account? Register").
  final Widget? footer;

  /// Optional element above the title (icon badge on the verification page).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, showBack ? 8 : 32, 24, 32),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null) ...[
                      Align(alignment: Alignment.centerLeft, child: leading),
                      const SizedBox(height: 20),
                    ] else ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SmartfindLogo(markSize: 44, wordmarkSize: 22),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Text(
                      title,
                      style: AppTextStyles.display.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ...children,
                    if (footer != null) ...[
                      const SizedBox(height: 24),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Question? **Action**" line used under the auth forms.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$prompt ',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Shows an error (or confirmation) message at the bottom of the screen.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
}
