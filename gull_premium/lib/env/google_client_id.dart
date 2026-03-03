import '../core/env/app_env.dart';

/// Google OAuth 2.0 Web client ID for "Continue with Google" sign-in.
/// Value is read from [AppEnv] (env.json / --dart-define). See ENV_SETUP.md.
String get kGoogleWebClientId => AppEnv.googleWebClientId;
