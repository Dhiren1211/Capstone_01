import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/auth_state.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../widgets/app_card.dart';
import '../widgets/auth_layout.dart' show showAppSnack;
import 'edit_profile_screen.dart';
import 'legal_screens.dart';

/// Settings. Every row does something real:
///
/// * Edit profile: name and photo.
/// * Reset password: e-mails a Firebase reset link.
/// * Appearance: system / light / dark.
/// * Alerts: pop-ups for possible matches and for new messages.
/// * Location: when off, the app never asks for GPS.
/// * Log out: forgets this phone for alerts, then ends the session.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sendingReset = false;

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _resetPassword() async {
    final auth = context.read<AuthState>();
    final email = auth.user?.email;
    if (email == null || _sendingReset) return;
    setState(() => _sendingReset = true);
    final error = await auth.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _sendingReset = false);
    if (error == null) {
      showAppSnack(context, 'Reset link sent to $email.');
    } else {
      showAppSnack(context, error, error: true);
    }
  }

  /// Turning an alert on also makes sure the operating system lets the app
  /// show it.
  Future<void> _setAlert(bool on, Future<void> Function(bool) save) async {
    await save(on);
    if (!on) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted || granted) return;
    showAppSnack(
      context,
      'Notifications are blocked for smartFind. Allow them in the phone '
      'settings to receive pop-ups.',
      error: true,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'This phone stops receiving your alerts until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorFgOf(ctx),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final nav = Navigator.of(context);
    await context.read<AuthState>().signOut();
    nav.pushNamedAndRemoveUntil(AppConstants.routeLogin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const _Heading('Account'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit profile',
                        subtitle: 'Name and photo',
                        onTap: () => _push(const EditProfileScreen()),
                      ),
                      _Tile(
                        icon: Icons.lock_reset_rounded,
                        label: 'Reset password',
                        subtitle: _sendingReset
                            ? 'Sending'
                            : 'We email you a reset link',
                        onTap: _resetPassword,
                        last: true,
                      ),
                    ],
                  ),
                ),
                const _Heading('Appearance'),
                AppCard(
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) => settings.setThemeMode(s.first),
                    ),
                  ),
                ),
                const _Heading('Alerts'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SwitchTile(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Possible matches',
                        subtitle:
                            'Pop up when a report looks like one of yours',
                        value: settings.matchAlerts,
                        onChanged: (v) => _setAlert(v, settings.setMatchAlerts),
                      ),
                      _SwitchTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Messages',
                        subtitle: 'Pop up when someone writes to you',
                        value: settings.messageAlerts,
                        onChanged: (v) =>
                            _setAlert(v, settings.setMessageAlerts),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const _Heading('Privacy'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _SwitchTile(
                    icon: Icons.location_on_outlined,
                    label: 'Location services',
                    subtitle: 'Map position and "Use my location" in reports',
                    value: settings.locationEnabled,
                    onChanged: settings.setLocationEnabled,
                    last: true,
                  ),
                ),
                const _Heading('About'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Tile(
                        icon: Icons.info_outline_rounded,
                        label: 'About smartFind',
                        value: 'v${AppConstants.appVersion}',
                        onTap: () => _push(const AboutScreen()),
                      ),
                      _Tile(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        onTap: () => _push(const TermsOfServiceScreen()),
                      ),
                      _Tile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => _push(const PrivacyPolicyScreen()),
                      ),
                      _Tile(
                        icon: Icons.handshake_outlined,
                        label: 'Community Guidelines',
                        onTap: () => _push(const CommunityGuidelinesScreen()),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _Tile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    destructive: true,
                    onTap: _logout,
                    last: true,
                    showChevron: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: AppColors.textTertiaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.value,
    this.destructive = false,
    this.last = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? value;
  final bool destructive;
  final bool last;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppColors.errorFgOf(context)
        : AppColors.textPrimaryOf(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.dividerOf(context))),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: destructive
                  ? color
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(color: color),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.dividerOf(context))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondaryOf(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: label,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
