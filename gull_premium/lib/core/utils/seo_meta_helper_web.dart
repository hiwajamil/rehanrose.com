// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation: updates document title and meta description/keywords.
void updatePageMeta({
  required String title,
  String? description,
  String? keywords,
}) {
  html.document.title = title;
  _setMetaContent('description', description);
  _setMetaContent('keywords', keywords);
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
