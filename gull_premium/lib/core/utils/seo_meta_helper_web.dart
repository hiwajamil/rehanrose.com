// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation: updates document title, meta description/keywords,
/// and Open Graph meta for link previews (og:title, og:description, og:image, og:url).
void updatePageMeta({
  required String title,
  String? description,
  String? keywords,
  String? ogImage,
  String? ogUrl,
}) {
  html.document.title = title;
  _setMetaContent('description', description);
  _setMetaContent('keywords', keywords);
  _setMetaProperty('og:title', title);
  _setMetaProperty('og:description', description);
  _setMetaProperty('og:image', ogImage);
  _setMetaProperty('og:url', ogUrl);
}

void _setMetaContent(String name, String? content) {
  if (content == null || content.isEmpty) return;
  final meta = html.document.querySelector('meta[name="$name"]');
  if (meta != null) {
    meta.setAttribute('content', content);
  } else {
    final element = html.document.createElement('meta');
    element.setAttribute('name', name);
    element.setAttribute('content', content);
    html.document.head?.append(element);
  }
}

void _setMetaProperty(String property, String? content) {
  if (content == null || content.isEmpty) return;
  final meta = html.document.querySelector('meta[property="$property"]');
  if (meta != null) {
    meta.setAttribute('content', content);
  } else {
    final element = html.document.createElement('meta');
    element.setAttribute('property', property);
    element.setAttribute('content', content);
    html.document.head?.append(element);
  }
}
