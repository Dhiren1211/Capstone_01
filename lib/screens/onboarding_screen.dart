import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';

/// Full-bleed welcome: a campus photo (or a sky-blue gradient with an
/// illustration when no photo is bundled), the smartFind wordmark on top and
/// a large two-line headline with one blue call to action at the bottom.
///
/// To use a real photo, drop a portrait image at
/// `assets/images/welcome_campus.jpg` - no code change needed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _photo = 'assets/images/welcome_campus.jpg';

  final _controller = PageController();
  int _current = 0;

  /// Whether the optional campus photo is bundled (checked once).
  bool _hasPhoto = false;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      asset: 'assets/images/onboarding_1_lost.png',
      eyebrow: 'Lost something on campus?',
      headline: 'Find it\nfaster',
      body:
          'Describe it once and pick the building. We compare it with '
          'everything that has been found.',
    ),
    _OnboardPage(
      asset: 'assets/images/onboarding_2_found.png',
      eyebrow: 'Found something?',
      headline: 'Return it\nwith ease',
      body:
          'Post a photo and tell the owner where to meet you. A good '
          'report gets an item home faster.',
    ),
    _OnboardPage(
      asset: 'assets/images/onboarding_3_map.png',
      eyebrow: 'Smart alerts',
      headline: 'Get matched\ninstantly',
      body:
          'When a report looks at least 70% like yours, your phone tells '
          'you, even when the app is closed.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    rootBundle.load(_photo).then(
      (_) {
        if (mounted) setState(() => _hasPhoto = true);
      },
      onError: (Object _) {}, // no photo bundled: keep the gradient
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _pages.length - 1) {
      _controller.nextPage(
        duration: reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _current == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background: photo, or gradient sky.
            if (_hasPhoto)
              Image.asset(_photo, fit: BoxFit.cover, excludeFromSemantics: true)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.onboardingGradient,
                ),
              ),
            // Bottom shade so white text is readable on any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'smartFind',
                            style: AppTextStyles.brandWordmark(size: 44)
                                .copyWith(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x40000000),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onComplete,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 44),
                          ),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _current = i),
                      itemBuilder: (context, i) => _PageView(
                        page: _pages[i],
                        showIllustration: !_hasPhoto,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Row(
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            width: i == _current ? 26 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == _current
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                    child: PrimaryButton(
                      label: last ? 'Explore' : 'Next',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  const _OnboardPage({
    required this.asset,
    required this.eyebrow,
    required this.headline,
    required this.body,
  });

  final String asset;
  final String eyebrow;
  final String headline;
  final String body;
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.showIllustration});

  final _OnboardPage page;
  final bool showIllustration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: showIllustration
                ? Center(
                    child: FadeSlideIn(
                      offset: 28,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 260,
                          maxHeight: 260,
                        ),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 30,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          page.asset,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.travel_explore_rounded,
                            size: 96,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            page.eyebrow,
            style: AppTextStyles.h3.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            page.headline,
            style: AppTextStyles.display.copyWith(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
