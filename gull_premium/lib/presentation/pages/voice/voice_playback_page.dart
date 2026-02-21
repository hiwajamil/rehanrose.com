import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Page shown when scanning a voice message QR code.
/// Plays the audio from the URL (Firebase Storage).
class VoicePlaybackPage extends StatefulWidget {
  final String audioUrl;

  const VoicePlaybackPage({super.key, required this.audioUrl});

  @override
  State<VoicePlaybackPage> createState() => _VoicePlaybackPageState();
}

class _VoicePlaybackPageState extends State<VoicePlaybackPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.playing || state == PlayerState.completed) {
          _isLoading = false;
        }
      });
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    if (widget.audioUrl.isEmpty) {
      if (mounted) setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }
    try {
      await _player.setSource(UrlSource(widget.audioUrl));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_hasError) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seekTo(double value) async {
    final position = Duration(milliseconds: value.toInt());
    await _player.seek(position);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Voice Message',
                style: playfair.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_hasError)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load the voice message. The file may be unavailable or in an unsupported format.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                GestureDetector(
                  onTap: _isLoading ? null : _togglePlayPause,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLoading
                          ? AppColors.border
                          : AppColors.rosePrimary,
                    ),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_duration > Duration.zero) ...[
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.rosePrimary,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.rosePrimary,
                      overlayColor: AppColors.rosePrimary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.toDouble().clamp(
                            0.0,
                            _duration.inMilliseconds.toDouble(),
                          ),
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: _seekTo,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
