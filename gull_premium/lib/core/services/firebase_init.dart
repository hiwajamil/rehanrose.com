/// Whether Firebase was successfully initialized in main().
/// Used so the router can skip FirebaseAnalyticsObserver when init failed (e.g. web).
bool get isFirebaseInitialized => _firebaseInitialized;
bool _firebaseInitialized = false;

void setFirebaseInitialized(bool value) {
  _firebaseInitialized = value;
}
