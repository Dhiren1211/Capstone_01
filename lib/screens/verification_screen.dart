import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_layout.dart';
import '../widgets/info_banner.dart';
import '../widgets/primary_button.dart';

/// "Check your inbox" - shown (by the auth gate) while a signed-in account
/// still has an unverified e-mail address.
///
/// The screen re-checks every few seconds, so it moves on by itself as soon as
/// the link in the e-mail has been opened - on this phone or any other device.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendCooldown = 30;

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _checking = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      context.read<AuthState>().checkEmailVerified(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final auth = context.read<AuthState>();
    final verified = await auth.checkEmailVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!verified) {
      showAppSnack(
        context,
        auth.error ??
            'Not verified yet. Open the link in the e-mail first, then try again.',
        error: true,
      );
      auth.clearError();
    }
    // When verified, AuthState flips to signedIn and the gate replaces this
    // screen automatically.
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() => _resending = true);
    final error = await context.read<AuthState>().resendVerification();
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (error == null) _cooldown = _resendCooldown;
    });
    if (error != null) {
      showAppSnack(context, error, error: true);
      return;
    }
    showAppSnack(context, 'Verification e-mail sent again.');
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthState, String?>((a) => a.pendingEmail);
    final emulatorHint = kDebugMode && AppConfig.useEmulator;

    return AuthLayout(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primarySurfaceOf(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.mark_email_unread_outlined,
          size: 28,
          color: AppColors.primaryOf(context),
        ),
      ),
      title: 'Check your inbox',
      subtitle: email == null || email.isEmpty
          ? 'We sent you a verification link. Open it, then come back here.'
          : 'We sent a verification link to $email. Open it, then come back '
                'here. This page continues by itself.',
      children: [
        const InfoBanner(
          message: 'Nothing there? Look in the spam folder, or send the e-mail again.',
        ),
        if (emulatorHint) ...[
          const SizedBox(height: 12),
          InfoBanner(
            tone: BannerTone.warning,
            message:
                'Emulator mode: no real e-mail is sent. If this page does not '
                'move on, run  node scripts/verify-email.mjs ${email ?? 'your@email'}',
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'I have verified my e-mail',
          isLoading: _checking,
          onPressed: _checkNow,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: _cooldown > 0 ? 'Send again in $_cooldown s' : 'Send e-mail again',
          variant: PrimaryButtonVariant.outlined,
          isLoading: _resending,
          onPressed: _cooldown > 0 ? null : _resend,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.read<AuthState>().signOut(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondaryOf(context),
          ),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}
