import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Path to the custom order notification sound asset.
/// File at [gull_premium]/assets/sounds/new-notification-2.mp3.
const String _kOrderNotificationSoundAsset = 'assets/sounds/new-notification-2.mp3';
const String _kOrderNotificationSoundAssetAlt = 'sounds/new-notification-2.mp3';

/// Plays the custom order notification sound once.
/// Falls back to system alert if the asset fails to load.
/// On mobile, configures audio context so the sound plays as a notification (audible, correct stream).
/// On Web, browser autoplay policy may block playback until the user has interacted with the page;
/// if so, we catch [NotAllowedError] and log without crashing.
/// Volume is explicitly set to 1.0 (max) for reliable playback across platforms.
Future<void> playOrderNotificationSound() async {
  final player = AudioPlayer();
  player.onPlayerComplete.listen((_) {
    player.dispose();
  });

  try {
    // One-shot: release player when playback finishes.
    await player.setReleaseMode(ReleaseMode.release);

    // Explicit max volume for reliable cross-platform playback (Mobile, Tablet, Web).
    await player.setVolume(1.0);

    // On mobile, use notification audio context so the sound is audible (e.g. not tied to media volume on Android).
    if (!kIsWeb) {
      try {
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.notification,
              contentType: AndroidContentType.sonification,
            ),
          ),
        );
      } catch (_) {
        // setAudioContext may be no-op or fail on some platforms; continue to play.
      }
    }

    await player.setSource(AssetSource(_kOrderNotificationSoundAsset));
    await player.resume();
    return;
  } catch (e, st) {
    try {
      // Retry with alternate asset path (e.g. Web asset resolution).
      await player.setVolume(1.0);
      await player.setSource(AssetSource(_kOrderNotificationSoundAssetAlt));
      await player.resume();
      return;
    } catch (_) {
      // Fallback to system sound only if this was not an autoplay block (e.g. asset load failure).
      if (!_isAutoplayBlocked(e)) {
        try {
          player.dispose();
          SystemSound.play(SystemSoundType.alert);
        } catch (__) {}
        return;
      }
    }
    // Web: Autoplay policy often blocks unmuted audio until user gesture (NotAllowedError).
    if (kIsWeb && _isAutoplayBlocked(e)) {
      if (kDebugMode) {
        debugPrint('Notification sound skipped: browser autoplay policy (user interaction required).');
      }
    } else if (kDebugMode) {
      debugPrint('Notification sound error: $e');
      debugPrint('$st');
    }
    player.dispose();
  }
}

/// Heuristic: detect autoplay-blocked errors (e.g. NotAllowedError from the browser).
bool _isAutoplayBlocked(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('notallowed') ||
      s.contains('not allowed') ||
      s.contains('autoplay') ||
      s.contains('user gesture');
}
