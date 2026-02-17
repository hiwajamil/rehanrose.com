import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';

import '../../controllers/controllers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/voice_file_reader.dart';

/// Sub-dialog for recording a voice message (max 60s), uploading it, and showing QR preview.
/// Returns the voice message URL when done, or null if cancelled / not supported.
Future<String?> showVoiceMessageDialog(BuildContext context) async {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _VoiceMessageDialogContent(),
  );
}

class _VoiceMessageDialogContent extends ConsumerStatefulWidget {
  const _VoiceMessageDialogContent();

  @override
  ConsumerState<_VoiceMessageDialogContent> createState() =>
      _VoiceMessageDialogContentState();
}

class _VoiceMessageDialogContentState
    extends ConsumerState<_VoiceMessageDialogContent> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  static const int _maxSeconds = 60;
  Timer? _timer;
  String? _voiceMessageUrl;
  String? _error;
  bool _isUploading = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      setState(() {
        _permissionChecked = true;
        _hasPermission = false;
      });
      return;
    }
    final has = await _recorder.hasPermission();
    setState(() {
      _permissionChecked = true;
      _hasPermission = has;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (kIsWeb || !_hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recordingPath = path;
        _isRecording = true;
        _recordSeconds = 0;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_recordSeconds >= _maxSeconds) {
            _timer?.cancel();
            _stopRecording();
          } else {
            _recordSeconds++;
          }
        });
      });
    } catch (e) {
      setState(() => _error = 'Could not start recording.');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = _recordingPath;
    if (path == null) return;
    try {
      final stoppedPath = await _recorder.stop();
      final actualPath = stoppedPath ?? path;
      setState(() => _isRecording = false);
      await _uploadAndShowQr(actualPath);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _error = 'Could not save recording.';
      });
    }
  }

  Future<void> _uploadAndShowQr(String filePath) async {
    setState(() => _isUploading = true);
    _error = null;
    try {
      final bytes = await readVoiceRecordingBytes(filePath);
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isUploading = false;
          _error = 'Could not read recording.';
        });
        return;
      }
      final repo = ref.read(voiceMessageRepositoryProvider);
      final url = await repo.uploadVoiceMessage(bytes: Uint8List.fromList(bytes));
      if (!mounted) return;
      setState(() {
        _voiceMessageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed. Try again.';
      });
    }
  }

  void _done() {
    Navigator.of(context).pop(_voiceMessageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, padding.bottom + 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Voice Message QR Code',
              style: playfair.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 24),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Voice recording is available in the native app. Install from the App Store or Google Play to record.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!_permissionChecked || !_hasPermission)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _permissionChecked && !_hasPermission
                      ? 'Microphone permission is needed to record.'
                      : 'Checking permission…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_voiceMessageUrl != null) ...[
              QrImageView(
                data: _voiceMessageUrl!,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan to play your message',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ] else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.rosePrimary),
                      SizedBox(height: 12),
                      Text('Uploading…'),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    GestureDetector(
                      onTap: _isRecording ? null : _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? AppColors.rosePrimary.withValues(alpha: 0.3)
                              : AppColors.rosePrimary,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? '$_recordSeconds / $_maxSeconds sec'
                          : 'Tap to record (max $_maxSeconds sec)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                    if (_isRecording) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _stopRecording,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Stop & generate QR'),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
