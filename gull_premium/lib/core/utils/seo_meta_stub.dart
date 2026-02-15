/// Stub implementation of [updatePageMeta]. No-op on non-web platforms.
void updatePageMeta({
  required String title,
  String? description,
  String? keywords,
  String? ogImage,
  String? ogUrl,
}) {
  // No-op on mobile/desktop; only web implementation updates DOM.
}
