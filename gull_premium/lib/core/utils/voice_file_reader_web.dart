import 'dart:html' as html;
import 'dart:typed_data';

/// Reads the recorded voice from a blob URL (web only).
/// On web, [path] is the blob URL returned by record.stop().
/// Uses native html.HttpRequest (Safari fix: http.get fails on blob: URLs on iOS Safari).
Future<List<int>?> readVoiceRecordingBytes(String path) async {
  final trimmed = path.trim();
  if (!trimmed.startsWith('blob:')) return null;
  try {
    final req = await html.HttpRequest.request(
      trimmed,
      method: 'GET',
      responseType: 'arraybuffer',
    );
    final buffer = req.response as ByteBuffer?;
    if (buffer == null || buffer.lengthInBytes == 0) return null;
    final bytes = buffer.asUint8List();
    return bytes.isEmpty ? null : bytes.toList();
  } catch (_) {
    return null;
  }
}
