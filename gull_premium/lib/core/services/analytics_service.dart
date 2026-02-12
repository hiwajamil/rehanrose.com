import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized Firebase Analytics logging for user behavior.
/// No-ops when [FirebaseAnalytics] is unavailable (e.g. init failed).
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics? _analytics;

  /// Log when user opens a product details page.
  Future<void> logViewItem({required String itemId, required String itemName}) async {
    await _analytics?.logViewItem(
      items: [
        AnalyticsEventItem(
          itemId: itemId,
          itemName: itemName,
        ),
      ],
    );
  }

  /// Log when user taps "Order via WhatsApp" (add_to_cart / click_whatsapp).
  Future<void> logClickWhatsApp({
    String? itemId,
    String? itemName,
  }) async {
    final params = <String, Object>{};
    if (itemId != null && itemId.isNotEmpty) params['item_id'] = itemId;
    if (itemName != null && itemName.isNotEmpty) params['item_name'] = itemName;
    await _analytics?.logEvent(
      name: 'click_whatsapp',
      parameters: params.isNotEmpty ? params : null,
    );
  }

  /// Log search: what users type or select (e.g. search bar or emotion filter).
  Future<void> logSearch(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return;
    await _analytics?.logSearch(searchTerm: searchTerm.trim());
  }

  /// Log which category (Love, Birthday, etc.) the user selected.
  Future<void> logSelectContent({
    required String contentType,
    required String itemId,
    String? itemName,
  }) async {
    await _analytics?.logSelectContent(
      contentType: contentType,
      itemId: itemId,
      parameters: itemName != null && itemName.isNotEmpty
          ? <String, Object>{'item_name': itemName}
          : null,
    );
  }
}
