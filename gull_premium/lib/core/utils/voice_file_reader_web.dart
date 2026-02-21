import 'package:http/http.dart' as http;

/// Reads the recorded voice from a blob URL (web only).
/// On web, [path] is the blob URL returned by record.stop().
Future<List<int>?> readVoiceRecordingBytes(String path) async {
  if (!path.startsWith('blob:')) return null;
  try {
    final response = await http.get(Uri.parse(path));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}
