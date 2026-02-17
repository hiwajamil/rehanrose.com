import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/voice_message_repository.dart';

final voiceMessageRepositoryProvider = Provider<VoiceMessageRepository>((ref) {
  return VoiceMessageRepository();
});
