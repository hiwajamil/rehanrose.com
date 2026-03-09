import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Cinematic splash screen with a "dust assembly and dispersion" effect:
/// characters scatter in from random positions, hold, then blow away before
/// transitioning to the main app.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _brandPromise =
      'We believe that every emotion deserves to arrive beautifully.';

  static const int _assemblyDurationMs = 2500;
  static const int _holdDurationMs = 2000;
  static const int _dispersionDurationMs = 1500;

  static const double _blurAssemblyStart = 15.0;
  static const double _scaleAssemblyStart = 0.1;
  static const double _blurDispersionEnd = 15.0;

  late final AnimationController _controller;
  late final List<Offset> _startOffsets;
  late final List<Offset> _dispersionOffsets;
  late final List<double> _assemblyDelays;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final totalMs =
        _assemblyDurationMs + _holdDurationMs + _dispersionDurationMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    final len = _brandPromise.length;
    _startOffsets = List.generate(
      len,
      (_) => Offset(
        (_random.nextDouble() * 2 - 1) * 280,
        (_random.nextDouble() * 2 - 1) * 180,
      ),
    );
    _dispersionOffsets = List.generate(
      len,
      (_) => Offset(
        (_random.nextDouble() * 2 - 1) * 220,
        (_random.nextDouble() * 2 - 1) * 120,
      ),
    );
    _assemblyDelays = List.generate(
      len,
      (_) => _random.nextDouble() * 0.35,
    );

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle get _textStyle => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.3,
        color: AppColors.inkCharcoal,
        height: 1.5,
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width - 80;
    final center = Offset(size.width / 2, size.height / 2);

    final painter = TextPainter(
      text: TextSpan(text: _brandPromise, style: _textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 10,
    )..layout(maxWidth: maxWidth);

    final textWidth = painter.width;
    final textHeight = painter.height;
    final contentTopLeft = Offset(
      center.dx - textWidth / 2,
      center.dy - textHeight / 2,
    );

    final targetOffsets = <Offset>[];
    for (var i = 0; i <= _brandPromise.length; i++) {
      targetOffsets.add(
        painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero),
      );
    }

    return Container(
      color: _splashBackground,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final totalDuration =
              _assemblyDurationMs + _holdDurationMs + _dispersionDurationMs;
          final tAssembly = _assemblyDurationMs / totalDuration;
          final tHoldEnd = (_assemblyDurationMs + _holdDurationMs) / totalDuration;

          return Stack(
            clipBehavior: Clip.none,
            children: List.generate(_brandPromise.length, (i) {
              double opacity;
              double blur;
              double scale;
              Offset position;

              if (t < tAssembly) {
                final assemblyProgress = t / tAssembly;
                final delay = _assemblyDelays[i];
                final p = ((assemblyProgress - delay) / (1.0 - delay))
                    .clamp(0.0, 1.0);
                final curved = Curves.easeOut.transform(p);

                opacity = curved;
                blur = _blurAssemblyStart * (1 - curved);
                scale = _scaleAssemblyStart + (1 - _scaleAssemblyStart) * curved;
                final target = contentTopLeft + targetOffsets[i];
                position = Offset.lerp(
                  center + _startOffsets[i],
                  target,
                  curved,
                )!;
              } else if (t < tHoldEnd) {
                opacity = 1.0;
                blur = 0.0;
                scale = 1.0;
                position = contentTopLeft + targetOffsets[i];
              } else {
                final dispersionProgress =
                    (t - tHoldEnd) / (1.0 - tHoldEnd);
                final curved =
                    Curves.easeIn.transform(dispersionProgress);

                opacity = 1 - curved;
                blur = _blurDispersionEnd * curved;
                scale = 1.0 - 0.4 * curved;
                final target = contentTopLeft + targetOffsets[i];
                position = Offset.lerp(
                  target,
                  target + _dispersionOffsets[i],
                  curved,
                )!;
              }

              return Positioned(
                left: position.dx,
                top: position.dy,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blur,
                          sigmaY: blur,
                        ),
                        child: Text(
                          _brandPromise[i],
                          style: _textStyle,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  static const Color _splashBackground = Color(0xFFFAFAF9);
}
