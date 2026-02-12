/// Stub implementation of [updatePageMeta]. No-op on non-web platforms.
void updatePageMeta({
  required String title,
  String? description,
  String? keywords,
}) {
  // No-op on mobile/desktop; only web implementation updates DOM.
}
