import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/emotion_category.dart';

class FlowerModel {
  final String id;
  final String name;
  final String description;
  final int priceIqd;
  final List<String> imageUrls;
  final String bouquetCode;
  final DateTime? createdAt;
  final String occasion;

  /// Primary emotion category ID (love, apology, gratitude, sympathy, wellness, celebration).
  /// Must match one of [kEmotionCategoryIds]. Used for filtering. Falls back to occasion if missing.
  final String? emotionCategoryId;

  const FlowerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceIqd,
    required this.imageUrls,
    required this.occasion,
    required this.bouquetCode,
    this.emotionCategoryId,
    this.createdAt,
  });

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
    return FlowerModel(
      id: id,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceIqd: (json['priceIqd'] as num?)?.toInt() ?? 0,
      imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? [],
      occasion: _occasionFromJson(json['occasion']),
      bouquetCode: json['bouquetCode']?.toString() ?? '',
      emotionCategoryId: emotionCategoryId,
      createdAt: _createdAtFromJson(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'priceIqd': priceIqd,
      'imageUrls': imageUrls,
      'occasion': occasion,
      'bouquetCode': bouquetCode,
      if (emotionCategoryId != null) 'emotionCategoryId': emotionCategoryId!,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
