import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Reads the recorded voice from a blob URL (web only).
/// On web, [path] is the blob URL returned by record.stop().
/// Uses XMLHttpRequest (Safari fix: http.get fails on blob: URLs on iOS Safari).
Future<List<int>?> readVoiceRecordingBytes(String path) async {
  final trimmed = path.trim();
  if (!trimmed.startsWith('blob:')) return null;
  try {
    final xhr = web.XMLHttpRequest();
    final completer = Completer<List<int>?>();

    xhr
      ..open('GET', trimmed, true)
      ..responseType = 'arraybuffer'
      ..onLoad.listen((_) {
        final jsBuffer = xhr.response as JSArrayBuffer?;
        final ByteBuffer? buffer = jsBuffer?.toDart;
        if (buffer == null || buffer.lengthInBytes == 0) {
          completer.complete(null);
          return;
        }
        final bytes = buffer.asUint8List();
        completer.complete(bytes.isEmpty ? null : bytes.toList());
      })
      ..onError.listen((_) => completer.complete(null))
      ..send();

    return await completer.future;
  } catch (_) {
    return null;
  }
}
