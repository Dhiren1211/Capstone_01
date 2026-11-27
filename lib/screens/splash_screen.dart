import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../widgets/motion.dart';
import '../widgets/smartfind_logo.dart';

/// Short branded start screen.
///
/// Shows the logo for about a second (instantly when the system asks for
/// reduced motion), waits until Firebase has reported who is signed in and
/// then routes:
///   * signed in (or still to verify the e-mail) -> home gate
///   * first launch -> onboarding
///   * otherwise -> login
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const _onboardingSeenKey = 'has_seen_onboarding';

  /// Called by the onboarding screen when it completes, so later launches go
  /// straight to the login screen.
  static Future<void> markOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingSeenKey, true);
    } catch (_) {
      // Not critical: onboarding is simply shown again next time.
    }
  }

  static Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingSeenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );
  bool _routed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl.isAnimating || _ctrl.value > 0) return;
    if (reduceMotion(context)) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
    _waitAndRoute();
  }

  Future<void> _waitAndRoute() async {
    if (_routed) return;
    _routed = true;
    final minimum = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 1100);
    await Future<void>.delayed(minimum);
    if (!mounted) return;

    // Wait (up to 10 s) for Firebase to report who is signed in.
    final auth = context.read<AuthState>();
    var waited = 0;
    while (auth.isLoading && waited < 10000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
      if (!mounted) return;
    }

    // Signed in (or signed in but still has to verify the e-mail): the home
    // route's auth gate shows the right screen for each case.
    if (auth.isAuthenticated || auth.needsVerification) {
      Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
      return;
    }

    final seen = await SplashScreen.hasSeenOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      seen ? AppConstants.routeLogin : AppConstants.routeOnboarding,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(_fade),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SmartfindLogo(
                    markSize: 72,
                    wordmarkSize: 32,
                    axis: Axis.vertical,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppConstants.appTagline,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
