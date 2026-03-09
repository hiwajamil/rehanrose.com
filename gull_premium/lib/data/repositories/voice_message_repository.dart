import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads voice message bytes to Firebase Storage and returns the download URL.
/// Path: voice_messages/{userId}/message_{timestamp}.m4a for accountability.
class VoiceMessageRepository {
  VoiceMessageRepository({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const String _pathPrefix = 'voice_messages';

  /// Uploads [bytes] (e.g. m4a or wav) and returns the download URL.
  /// [userId] is the authenticated user's UID (required for secure, accountable storage).
  /// [extension] and [contentType] default to m4a/audio-mp4 for native; use
  /// .wav and audio/wav for web recordings.
  Future<String> uploadVoiceMessage({
    required Uint8List bytes,
    required String userId,
    String extension = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$_pathPrefix/$userId/message_$timestamp.$extension';
    final ref = _storage.ref(path);
    await ref
        .putData(
          bytes,
          SettableMetadata(contentType: contentType),
        )
        .timeout(const Duration(seconds: 60));
    return ref.getDownloadURL();
  }
}
