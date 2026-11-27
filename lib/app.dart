import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/chat_model.dart';
import 'models/item_model.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/building_detail_screen.dart';
import 'screens/campus_vr_screen.dart';
import 'screens/chat_detail_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/item_detail_screen.dart';
import 'screens/legal_screens.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/report_screens.dart';
import 'screens/saved_items_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/verification_screen.dart';
import 'services/admin_service.dart';
import 'services/notification_service.dart';
import 'state/auth_state.dart';
import 'state/settings_store.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/ksu_buildings.dart';

/// Root app widget: light and dark themes (chosen in Settings), named routes
/// and the binding between the signed-in person and the alert service.
///
/// Session persistence:
/// * Firebase Auth keeps the session by itself.
/// * The splash screen waits for [AuthState.isLoading] to finish, then routes
///   to /home when signed in, to /onboarding on the first run, or to /login.
/// * [_AuthGate] (wrapped around /home) shows the "check your inbox" screen
///   while the e-mail is unverified and returns to /login if the session ends.
class SmartfindApp extends StatelessWidget {
  const SmartfindApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsStore, ThemeMode>(
      (s) => s.themeMode,
    );
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      scrollBehavior: const _SmoothScrollBehavior(),
      initialRoute: AppConstants.routeSplash,
      onGenerateRoute: _onGenerateRoute,
      builder: (context, child) {
        // Transparent status bar so the page colour runs edge to edge (no
        // grey band); icon brightness follows the active theme.
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
          child: _AlertBinder(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.routeSplash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );

      case AppConstants.routeOnboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => OnboardingScreen(
            onComplete: () async {
              final navigator = Navigator.of(context);
              await SplashScreen.markOnboardingSeen();
              navigator.pushReplacementNamed(AppConstants.routeLogin);
            },
          ),
        );

      case AppConstants.routeLogin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              LoginScreen(onAuthSuccess: () => _enterApp(context)),
        );

      case AppConstants.routeSignup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              SignupScreen(onAuthSuccess: () => _enterApp(context)),
        );

      case AppConstants.routeHome:
        return MaterialPageRoute<void>(
          builder: (_) => const _AuthGate(child: MainShell()),
        );

      case AppConstants.routeItemDetail:
        final item = settings.arguments as ItemModel?;
        if (item == null) return _errorRoute('Item not found');
        return MaterialPageRoute<void>(
          builder: (_) => ItemDetailScreen(item: item),
        );

      case AppConstants.routeReportLost:
        final lostAt = settings.arguments as String?;
        return MaterialPageRoute<void>(
          builder: (_) => ReportLostScreen(initialBuilding: lostAt),
        );

      case AppConstants.routeReportFound:
        final foundAt = settings.arguments as String?;
        return MaterialPageRoute<void>(
          builder: (_) => ReportFoundScreen(initialBuilding: foundAt),
        );

      case AppConstants.routeBuildingDetail:
        final building = settings.arguments as KsuBuilding?;
        if (building == null) return _errorRoute('Building not found');
        return MaterialPageRoute<void>(
          builder: (_) => BuildingDetailScreen(building: building),
        );

      case AppConstants.routeCampusVr:
        return MaterialPageRoute<void>(builder: (_) => const CampusVrScreen());

      case AppConstants.routeNotifications:
        return MaterialPageRoute<void>(
          builder: (_) => const NotificationsScreen(),
        );

      case AppConstants.routeChats:
        return MaterialPageRoute<void>(builder: (_) => const ChatsScreen());

      case AppConstants.routeChatDetail:
        final chat = settings.arguments as ChatModel?;
        if (chat == null) return _errorRoute('Chat not found');
        return MaterialPageRoute<void>(
          builder: (_) => ChatDetailScreen(chat: chat),
        );

      case AppConstants.routeSettings:
        return MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

      case AppConstants.routeSavedItems:
        return MaterialPageRoute<void>(
          builder: (_) => const SavedItemsScreen(),
        );

      case AppConstants.routeForgotPassword:
        return MaterialPageRoute<void>(
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppConstants.routeEditProfile:
        return MaterialPageRoute<void>(
          builder: (_) => const EditProfileScreen(),
        );

      case AppConstants.routeTerms:
        return MaterialPageRoute<void>(
          builder: (_) => const TermsOfServiceScreen(),
        );

      case AppConstants.routePrivacy:
        return MaterialPageRoute<void>(
          builder: (_) => const PrivacyPolicyScreen(),
        );

      case AppConstants.routeGuidelines:
        return MaterialPageRoute<void>(
          builder: (_) => const CommunityGuidelinesScreen(),
        );

      case AppConstants.routeAdmin:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminPanelScreen(),
        );

      case AppConstants.routeAbout:
        return MaterialPageRoute<void>(builder: (_) => const AboutScreen());

      default:
        return _errorRoute('Unknown route: ${settings.name}');
    }
  }

  /// Goes to the home route and clears everything below it, so the back
  /// button never returns to the login / sign-up screens.
  static void _enterApp(BuildContext context) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppConstants.routeHome, (route) => false);
  }

  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(child: Text(message)),
      ),
    );
  }
}

/// Soft, bouncy (iOS-style) scrolling on every platform. Scroll views that
/// set their own physics keep them; `AlwaysScrollableScrollPhysics` parents
/// pick this up as well, so pull-to-refresh still works.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

/// Decides what the signed-in area of the app shows:
///
/// * verified student → [child] (the app)
/// * account with an unverified e-mail → "Check your inbox" screen
/// * signed out (session expired, user signed out) → back to the login screen
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.child});
  final Widget child;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _redirecting = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.signedIn:
        _redirecting = false;
        if (auth.isBanned) return const _SuspendedScreen();
        return widget.child;
      case AuthStatus.needsVerification:
        _redirecting = false;
        return const VerifyEmailScreen();
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        if (!_redirecting) {
          _redirecting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppConstants.routeLogin,
              (route) => false,
            );
          });
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }
}


/// Keeps the alert service in step with the signed-in person: it starts
/// listening (and registers this phone for push) when someone is signed in and
/// stops when they sign out.
class _AlertBinder extends StatefulWidget {
  const _AlertBinder({required this.child});
  final Widget child;

  @override
  State<_AlertBinder> createState() => _AlertBinderState();
}

class _AlertBinderState extends State<_AlertBinder> {
  String? _boundUid;

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthState, String?>(
      (a) => a.isAuthenticated ? a.user?.id : null,
    );
    if (uid != _boundUid) {
      _boundUid = uid;
      // After the frame: binding may ask for a permission and open streams.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.bindUser(uid);
        // Admin corrections to building positions (live).
        BuildingPositionsSync.instance.bind(uid != null);
      });
    }
    return widget.child;
  }
}

/// Shown instead of the app while an admin has suspended the account.
class _SuspendedScreen extends StatelessWidget {
  const _SuspendedScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final reason = auth.user?.bannedReason ?? '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.block_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Account suspended',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'An administrator has suspended this account, so you cannot '
                'post reports or send messages right now.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reason: $reason',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
