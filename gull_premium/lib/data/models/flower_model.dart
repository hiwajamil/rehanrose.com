import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/emotion_category.dart';

class FlowerModel {
  final String id;
  final String name;
  final String description;
  final int priceIqd;
  final List<String> imageUrls;
  /// Thumbnail URLs for listing grid (same order as [imageUrls]). Use [imageUrls] when null/empty.
  final List<String>? thumbnailUrls;
  final String bouquetCode;
  final DateTime? createdAt;
  final String occasion;

  /// Primary emotion category ID (love, apology, gratitude, sympathy, wellness, celebration).
  /// Must match one of [kEmotionCategoryIds]. Used for filtering. Falls back to occasion if missing.
  final String? emotionCategoryId;

  /// Vendor (user) ID who created this bouquet. Used for admin pending list and ownership.
  final String? vendorId;

  /// Approval status: 'pending' (awaiting admin), 'approved' (shown on main screen), 'rejected'.
  /// Null/absent is treated as approved for backward compatibility.
  final String? approvalStatus;

  /// Canonical status for UI and logic. Values: 'pending', 'approved', 'rejected'.
  /// Defaults to 'approved' when [approvalStatus] is null (legacy docs).
  String get status => approvalStatus ?? 'approved';

  /// Explicit sale flag. A product is considered on sale if [isOnSale] is true OR [discountPrice] is set.
  final bool isOnSale;
  /// Discount/sale price in IQD. When set (and > 0), product is considered on sale even if [isOnSale] is false.
  final int? discountPrice;

  /// Number of times the product detail page was viewed. Used for analytics overview.
  final int viewCount;
  /// Number of times "Order via WhatsApp" was clicked for this product.
  final int orderCount;

  const FlowerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceIqd,
    required this.imageUrls,
    this.thumbnailUrls,
    required this.occasion,
    required this.bouquetCode,
    this.emotionCategoryId,
    this.vendorId,
    this.approvalStatus,
    this.createdAt,
    this.isOnSale = false,
    this.discountPrice,
    this.viewCount = 0,
    this.orderCount = 0,
  });

  /// True if this product should be shown in Offers: [isOnSale] is true or [discountPrice] is set and > 0.
  bool get isOnSaleEffective =>
      isOnSale == true || (discountPrice != null && discountPrice! > 0);

  /// True when bouquet is approved (or legacy doc without field) and can be shown on main screen.
  bool get isApproved =>
      approvalStatus == null || approvalStatus == 'approved';

  /// True when bouquet is waiting for super admin approval.
  bool get isPendingApproval => approvalStatus == 'pending';

  /// Best URL for listing/card: thumbnail if available, else first full image.
  String get listingImageUrl {
    if (thumbnailUrls != null &&
        thumbnailUrls!.isNotEmpty &&
        thumbnailUrls!.first.isNotEmpty) {
      return thumbnailUrls!.first;
    }
    return imageUrls.isNotEmpty ? imageUrls.first : '';
  }

  /// Backward compatibility: null or empty occasion → "All" so older docs still render.
  static String _occasionFromJson(dynamic value) {
    final s = value?.toString();
    if (s == null) return 'All';
    final t = s.trim();
    if (t.isEmpty) return 'All';
    return t;
  }

  static DateTime? _createdAtFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory FlowerModel.fromJson(String id, Map<String, dynamic> json) {
    final rawEmotion = json['emotionCategoryId']?.toString().trim();
    final emotionCategoryId = (rawEmotion != null &&
            rawEmotion.isNotEmpty &&
            isValidEmotionCategoryId(rawEmotion))
        ? rawEmotion
        : null;
    final thumbRaw = json['thumbnailUrls'] as List?;
    final thumbnailUrls = thumbRaw != null && thumbRaw.isNotEmpty
        ? thumbRaw.cast<String>()
        : null;
    final isOnSale = json['isOnSale'] == true;
    final discountPriceRaw = json['discountPrice'];
    final discountPrice = discountPriceRaw != null
        ? (discountPriceRaw is num ? discountPriceRaw.toInt() : int.tryParse(discountPriceRaw.toString()))
        : null;
    final viewCount = (json['viewCount'] as num?)?.toInt() ?? 0;
    final orderCount = (json['orderCount'] as num?)?.toInt() ?? 0;
    final vendorId = json['vendorId']?.toString();
    final approvalStatus = json['approvalStatus']?.toString();
    return FlowerModel(
      id: id,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceIqd: (json['priceIqd'] as num?)?.toInt() ?? 0,
      imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? [],
      thumbnailUrls: thumbnailUrls,
      occasion: _occasionFromJson(json['occasion']),
      bouquetCode: json['bouquetCode']?.toString() ?? '',
      emotionCategoryId: emotionCategoryId,
      vendorId: vendorId,
      approvalStatus: approvalStatus,
      createdAt: _createdAtFromJson(json['createdAt']),
      isOnSale: isOnSale,
      discountPrice: discountPrice,
      viewCount: viewCount,
      orderCount: orderCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'priceIqd': priceIqd,
      'imageUrls': imageUrls,
      if (thumbnailUrls != null && thumbnailUrls!.isNotEmpty)
        'thumbnailUrls': thumbnailUrls!,
      'occasion': occasion,
      'bouquetCode': bouquetCode,
      if (emotionCategoryId != null) 'emotionCategoryId': emotionCategoryId!,
      if (vendorId != null) 'vendorId': vendorId!,
      if (approvalStatus != null) 'approvalStatus': approvalStatus!,
      if (createdAt != null) 'createdAt': createdAt,
      if (isOnSale) 'isOnSale': true,
      if (discountPrice != null) 'discountPrice': discountPrice!,
      'viewCount': viewCount,
      'orderCount': orderCount,
    };
  }
}
