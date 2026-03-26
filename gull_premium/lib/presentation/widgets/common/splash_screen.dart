import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Luxury splash screen:
/// A fast-paced brand fade sequence, followed by the final slogan.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _finalSlogan =
      'We believe that every emotion deserves to arrive beautifully';
  static const List<String> _luxuryWords = <String>[
    'Chanel',
    'Red Roses',
    'Dior',
    'Orchids',
    'Tom Ford',
  ];

  // Total word sequence duration: 5 * 450ms = 2250ms (~2.25s).
  static const Duration _wordInterval = Duration(milliseconds: 450);
  static const Duration _wordFadeDuration = Duration(milliseconds: 220);

  // Final slogan should remain readable for ~1 to 1.5 seconds.
  static const Duration _sloganMinVisibleDuration =
      Duration(milliseconds: 1400);
  static const Duration _sloganFadeInDuration = Duration(milliseconds: 550);
  static const Duration _sloganFadeOutDuration = Duration(milliseconds: 250);

  int _wordIndex = 0;
  bool _showWords = true;
  bool _showFinalSlogan = false;
  bool _isExiting = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSequence());
  }


  Future<void> _runSequence() async {
    // Run brand animation concurrently with any background init.
    final brandFuture = _runBrandSequence();
    final backgroundFuture = _runBackgroundInitialization();

    await brandFuture;
    if (!mounted) return;

    // Grand finale: fade in slogan once the word sequence finishes.
    setState(() {
      _showWords = false;
      _showFinalSlogan = true;
      _isExiting = false;
    });

    // Wait until the slogan has been on screen long enough AND background
    // work has finished (whichever is smoother).
    await Future.wait(<Future<void>>[
      backgroundFuture,
      Future<void>.delayed(_sloganMinVisibleDuration),
    ]);

    if (!mounted || _didComplete) return;

    // Quick fade-out so the navigation feels seamless.
    setState(() => _isExiting = true);
    await Future<void>.delayed(_sloganFadeOutDuration);

    if (!mounted || _didComplete) return;
    _didComplete = true;
    widget.onComplete();
  }

  Future<void> _runBrandSequence() async {
    for (var i = 0; i < _luxuryWords.length; i++) {
      if (!mounted) return;
      setState(() => _wordIndex = i);
      await Future<void>.delayed(_wordInterval);
    }
  }

  Future<void> _runBackgroundInitialization() async {
    // Firebase and locale init already happens before `runApp()` in `main.dart`.
    // This function exists to keep the splash sequencing clean and extensible
    // if you add additional warmups later.
    await Future<void>.delayed(Duration.zero);
  }

  TextStyle _luxuryTextStyle({required double fontSize}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.6,
        height: 1.1,
        color: AppColors.inkCharcoal,
        decoration: TextDecoration.none,
      );

  TextStyle get _wordTextStyle => _luxuryTextStyle(fontSize: 48);

  TextStyle get _sloganTextStyle => _luxuryTextStyle(fontSize: 22);

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: _showWords ? 1 : 0,
              duration: _wordFadeDuration,
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: _wordFadeDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _luxuryWords[_wordIndex],
                  key: ValueKey<String>(_luxuryWords[_wordIndex]),
                  style: _wordTextStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedOpacity(
              opacity: _showFinalSlogan ? 1.0 : 0.0,
              duration: _sloganFadeInDuration,
              curve: Curves.easeInOut,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AnimatedOpacity(
                  // Separate opacity for exit so it can fade faster.
                  opacity: _isExiting ? 0.0 : 1.0,
                  duration: _sloganFadeOutDuration,
                  curve: Curves.easeOut,
                  child: Center(
                    child: Text(
                      _finalSlogan,
                      style: _sloganTextStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
