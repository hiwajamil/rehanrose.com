import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Uploads voice message bytes to Firebase Storage and returns the download URL.
/// Path: voice_messages/{uniqueId}.m4a so the vendor can use the URL for QR.
class VoiceMessageRepository {
  VoiceMessageRepository({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const String _pathPrefix = 'voice_messages';

  /// Uploads [bytes] (e.g. m4a or wav) and returns the download URL.
  /// [uniqueId] if provided is used; otherwise a new UUID is generated.
  /// [extension] and [contentType] default to m4a/audio-mp4 for native; use
  /// .wav and audio/wav for web recordings.
  Future<String> uploadVoiceMessage({
    required Uint8List bytes,
    String? uniqueId,
    String extension = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    final id = uniqueId ?? const Uuid().v4();
    final ref = _storage.ref('$_pathPrefix/$id.$extension');
    await ref
        .putData(
          bytes,
          SettableMetadata(contentType: contentType),
        )
        .timeout(const Duration(seconds: 60));
    return ref.getDownloadURL();
  }
}
