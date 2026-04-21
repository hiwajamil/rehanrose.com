import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal cinematic splash screen with a single mission statement.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _message =
      'We believe that every emotion deserves to arrive beautifully';
  static const Color _creamBackground = Color(0xFFF6F1E8);
  static const Color _premiumText = Color(0xFF2F3C34);
  static const Duration _fadeInDuration = Duration(seconds: 2);
  static const Duration _holdDuration = Duration(milliseconds: 1500);
  static const Duration _fadeOutDuration = Duration(milliseconds: 1500);

  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _fadeInDuration + _holdDuration + _fadeOutDuration,
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: _fadeInDuration.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(1.0),
        weight: _holdDuration.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: _fadeOutDuration.inMilliseconds.toDouble(),
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    unawaited(_runSequence());
  }

  Future<void> _runSequence() async {
    await _controller.forward();
    if (!mounted) return;
    widget.onComplete();
  }

  TextStyle _messageStyle(BuildContext context) =>
      GoogleFonts.playfairDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.3,
        height: 1.35,
        color: _premiumText,
        decoration: TextDecoration.none,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBackground,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              style: _messageStyle(context),
            ),
          ),
        ),
      ),
    );
  }
}
