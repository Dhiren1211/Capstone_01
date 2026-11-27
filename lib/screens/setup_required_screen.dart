import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

/// Shown instead of the app when Firebase cannot be started (for example
/// because the app was run without `--dart-define-from-file=env.json`).
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.problem});

  final String problem;

  static const _command = 'flutter run --dart-define-from-file=env.json';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.backgroundOf(context),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.settings_suggest_rounded,
                        size: 52,
                        color: AppColors.primaryOf(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'One more setup step',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        problem,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'smartFind reads its settings from a file called '
                        'env.json (copy env.example.json and fill it in). '
                        'Stop the app and start it again with:',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOf(context),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _command,
                                style: TextStyle(
                                  color: AppColors.onPrimaryOf(context),
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              icon: Icon(
                                Icons.copy_rounded,
                                color: AppColors.onPrimaryOf(context),
                                size: 18,
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(
                                  const ClipboardData(text: _command),
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Command copied'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Details: README.md, section "Run the app".',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiaryOf(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
