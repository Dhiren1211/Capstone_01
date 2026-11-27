import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';

/// The university's 360 degree campus tour, shown inside the app.
///
/// Works on phones (Android and iOS). If the page cannot be loaded - no
/// connection, or the university site is down - the person gets a clear
/// message with "Try again" and "Open in browser".
class CampusVrScreen extends StatefulWidget {
  const CampusVrScreen({super.key});

  @override
  State<CampusVrScreen> createState() => _CampusVrScreenState();
}

class _CampusVrScreenState extends State<CampusVrScreen> {
  static final Uri _home = Uri.parse(AppConstants.campusVrUrl);

  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onWebResourceError: (e) {
            // Sub-resources (a missing icon, a blocked tracker) must not hide
            // a tour that is otherwise working.
            if (e.isForMainFrame == false) return;
            if (mounted) setState(() => _failed = true);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final inTour = uri.host == _home.host;
            if (inTour || !request.isMainFrame) return NavigationDecision.navigate;
            // Anything else leaves the app (browser, mail app ...).
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_home);
  }

  Future<void> _openExternally() async {
    final ok = await launchUrl(_home, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No browser available to open the tour.')),
      );
    }
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(_home);
  }

  Future<void> _onBack(bool didPop) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onBack(didPop),
      child: Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('Campus VR tour'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _retry,
            ),
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: _openExternally,
            ),
          ],
          bottom: _progress < 100 && !_failed
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: _failed
            ? Column(
                children: [
                  Expanded(
                    child: EmptyState(
                      title: 'The tour could not be loaded',
                      subtitle:
                          'Check your internet connection and try again. You '
                          'can also open it in your phone\'s browser.',
                      icon: Icons.vrpano_outlined,
                      ctaLabel: 'Try again',
                      onCtaTap: _retry,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextButton(
                      onPressed: _openExternally,
                      child: Text(
                        'Open in browser',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                ],
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
