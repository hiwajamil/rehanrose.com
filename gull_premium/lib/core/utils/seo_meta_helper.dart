// SEO meta helper: updates browser title/description/keywords on navigation (web only).

import 'seo_meta_stub.dart'
    if (dart.library.html) 'seo_meta_helper_web.dart' as impl;

const String kAppName = 'Rehan Rose';

/// Updates the page title and optional meta description and keywords.
/// On web this updates document.title and creates/updates
/// meta name="description" and meta name="keywords".
/// [ogImage] and [ogUrl] set Open Graph meta so link previews (e.g. when sharing
/// from the browser) show the bouquet photo and canonical URL.
void updatePageMeta({
  required String title,
  String? description,
  String? keywords,
  String? ogImage,
  String? ogUrl,
}) {
  impl.updatePageMeta(
    title: title,
    description: description,
    keywords: keywords,
    ogImage: ogImage,
    ogUrl: ogUrl,
  );
}
