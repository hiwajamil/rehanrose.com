import 'dart:io';

/// Reads the recorded voice file as bytes (mobile/desktop only).
Future<List<int>?> readVoiceRecordingBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
