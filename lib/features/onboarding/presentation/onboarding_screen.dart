import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../generated/app_localizations.dart';

class _OnboardingPage {
  const _OnboardingPage(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

/// First-launch intro: three swipeable pages introducing the app's core
/// pillars, then hands off to [onDone]. Shown once; gated by
/// [SettingKeys.onboardingComplete] in shared_preferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingKeys.onboardingComplete, true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      _OnboardingPage(
        Icons.picture_as_pdf_rounded,
        l10n.onboardingTitle1,
        l10n.onboardingBody1,
      ),
      _OnboardingPage(
        Icons.folder_copy_rounded,
        l10n.onboardingTitle2,
        l10n.onboardingBody2,
      ),
      _OnboardingPage(
        Icons.pie_chart_rounded,
        l10n.onboardingTitle3,
        l10n.onboardingBody3,
      ),
    ];
    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.skip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final page in pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.7, end: 1),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [scheme.primary, scheme.tertiary],
                                ),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Icon(
                                page.icon,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                  child: Text(isLast ? l10n.getStarted : l10n.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
