// ignore_for_file: constant_identifier_names

/// Centralized environment variables and secrets.
///
/// Values are read from compile-time `--dart-define` (or `--dart-define-from-file=env.json`).
/// Never commit real secrets to the repo. Use [env.json] (gitignored) for local dev;
/// see [ENV_SETUP.md] in the project root for setup instructions.
class AppEnv {
  AppEnv._();

  /// Google Places API key (for map/address autocomplete on mobile).
  /// On web, the app uses a Firebase Functions proxy; this key is only used on iOS/Android.
  static const String placesApiKey = String.fromEnvironment(
    'PLACES_API_KEY',
    defaultValue: '',
  );

  /// Google OAuth 2.0 Web client ID for "Continue with Google" sign-in.
  /// From Firebase Console → Authentication → Google → Web client ID.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Super admin email; this user is always treated as admin (bypasses [admins] collection).
  /// Leave empty in env to disable; set only in secure environments.
  static const String superAdminEmail = String.fromEnvironment(
    'SUPER_ADMIN_EMAIL',
    defaultValue: '',
  );
}
