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
Future<void> playOrderNotificationSound() async {
  final player = AudioPlayer();
  player.onPlayerComplete.listen((_) {
    player.dispose();
  });

  // One-shot: release player when playback finishes.
  await player.setReleaseMode(ReleaseMode.release);

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

  try {
    await player.setSource(AssetSource(_kOrderNotificationSoundAsset));
    await player.resume();
  } catch (_) {
    try {
      await player.setSource(AssetSource(_kOrderNotificationSoundAssetAlt));
      await player.resume();
    } catch (__) {
      player.dispose();
      SystemSound.play(SystemSoundType.alert);
    }
  }
}
