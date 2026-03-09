import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';

import '../../controllers/controllers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/voice_file_reader.dart';

/// Returns true if we should use a full-screen dialog (web/desktop) for auth required.
bool get _useAuthDialogInsteadOfBottomSheet {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    default:
      return false;
  }
}

/// Shows the "Account Required" UX when an unauthenticated user tries to use voice recording.
/// Uses ModalBottomSheet on mobile, AlertDialog on Web/Desktop. Sign In / Sign Up push to auth
/// routes so the user can return and finish their order.
void showVoiceMessageAuthRequired(BuildContext context) {
  if (_useAuthDialogInsteadOfBottomSheet) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _VoiceMessageAuthRequiredContent(
        onSignIn: () {
          Navigator.of(ctx).pop();
          context.push('/login');
        },
        onSignUp: () {
          Navigator.of(ctx).pop();
          context.push('/register');
        },
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceMessageAuthRequiredContent(
        onSignIn: () {
          Navigator.of(ctx).pop();
          context.push('/login');
        },
        onSignUp: () {
          Navigator.of(ctx).pop();
          context.push('/register');
        },
      ),
    );
  }
}

/// Premium "Account Required" UI: icon, title, message, Sign In / Sign Up buttons.
class _VoiceMessageAuthRequiredContent extends StatelessWidget {
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const _VoiceMessageAuthRequiredContent({
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    final playfair = GoogleFonts.playfairDisplay(
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
    final padding = MediaQuery.paddingOf(context);
    final isSheet = !_useAuthDialogInsteadOfBottomSheet;

    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(isSheet ? 24 : 0)),
      ),
      padding: EdgeInsets.fromLTRB(24, isSheet ? 20 : 28, 24, padding.bottom + 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSheet)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            if (isSheet) const SizedBox(height: 20),
            Icon(
              Icons.mic_rounded,
              size: 48,
              color: AppColors.rosePrimary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.shield_rounded,
              size: 28,
              color: AppColors.sage.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 20),
            Text(
              'Account Required',
              style: playfair.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'To ensure security and save your personalized messages, please Sign In or Create an Account to use the Voice Message feature.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSignIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSignUp,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );

    if (_useAuthDialogInsteadOfBottomSheet) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: content,
      );
    }
    return content;
  }
}

/// Sub-dialog for recording a voice message (max 60s), uploading it, and showing QR preview.
/// Returns the voice message URL when done, or null if cancelled / not supported.
/// Call only when user is authenticated (auth check is done at tap in add-on modal).
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
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(null);
      });
      return;
    }
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final has = await _recorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _permissionChecked = true;
        _hasPermission = has;
      });
      if (!has) _showPermissionDeniedSnackBar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionChecked = true;
        _hasPermission = false;
      });
      _showPermissionDeniedSnackBar();
    }
  }

  void _showPermissionDeniedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? 'Microphone access was denied. To enable: click the lock or info icon in your browser\'s address bar, allow microphone, then refresh the page.'
              : 'Microphone permission is needed to record. Please enable it in your device settings.',
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) return;
    final String path;
    final RecordConfig config;
    if (kIsWeb) {
      path = 'web_voice_${DateTime.now().millisecondsSinceEpoch}';
      config = const RecordConfig(encoder: AudioEncoder.wav);
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    try {
      await _recorder.start(config, path: path);
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
      await _uploadAndShowQr(actualPath, isWebRecording: kIsWeb);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _error = 'Could not save recording.';
      });
    }
  }

  Future<void> _uploadAndShowQr(String filePath,
      {bool isWebRecording = false}) async {
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
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final repo = ref.read(voiceMessageRepositoryProvider);
      final url = await repo.uploadVoiceMessage(
        bytes: Uint8List.fromList(bytes),
        userId: uid,
        extension: isWebRecording ? 'wav' : 'm4a',
        contentType: isWebRecording ? 'audio/wav' : 'audio/mp4',
      );
      if (!mounted) return;
      setState(() {
        _voiceMessageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Error: ${e.toString()}';
      });
    }
  }

  void _done() {
    Navigator.of(context).pop(_voiceMessageUrl);
  }

  /// Returns the URL to encode in QR: our playback page with the audio URL as param.
  /// When scanned, opens our app at /v?url=... which plays the audio with proper controls.
  String _playbackUrlForQr(String audioUrl) {
    try {
      final origin = Uri.base.origin;
      final basePath = Uri.base.path.replaceAll(RegExp(r'/+$'), '');
      final path = (basePath.isEmpty || basePath == '/') ? '/v' : '$basePath/v';
      final uri = Uri.parse(origin).replace(
        path: path.startsWith('/') ? path : '/$path',
        queryParameters: {'url': audioUrl},
      );
      return uri.toString();
    } catch (_) {
      return audioUrl;
    }
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
            if (!_permissionChecked || !_hasPermission)
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
                data: _playbackUrlForQr(_voiceMessageUrl!),
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
            ]             else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
