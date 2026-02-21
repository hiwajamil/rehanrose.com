/// Type of complementary add-on product.
enum AddOnType {
  vase,
  chocolate,
  card,
  teddyBear,
}

/// Extension to parse from Firestore string.
extension AddOnTypeX on AddOnType {
  static AddOnType? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'vase':
        return AddOnType.vase;
      case 'chocolate':
        return AddOnType.chocolate;
      case 'card':
        return AddOnType.card;
      case 'teddybear':
        return AddOnType.teddyBear;
      default:
        return null;
    }
  }

  String get firestoreValue {
    switch (this) {
      case AddOnType.vase:
        return 'vase';
      case AddOnType.chocolate:
        return 'chocolate';
      case AddOnType.card:
        return 'card';
      case AddOnType.teddyBear:
        return 'TeddyBear';
    }
  }

  /// Firestore category value: 'Vase' | 'Chocolate' | 'Card'.
  String get categoryValue {
    switch (this) {
      case AddOnType.vase:
        return 'Vase';
      case AddOnType.chocolate:
        return 'Chocolate';
      case AddOnType.card:
        return 'Card';
      case AddOnType.teddyBear:
        return 'TeddyBear';
    }
  }
}

/// Complementary product (cross-sell) offered at checkout.
/// Names are translatable (En, Ku, Ar). Price in IQD.
class AddOnModel {
  final String id;
  /// Name in English.
  final String nameEn;
  /// Name in Kurdish (e.g. گوڵدان for vase).
  final String nameKu;
  /// Name in Arabic.
  final String nameAr;
  /// Price in IQD.
  final int priceIqd;
  final String imageUrl;
  final AddOnType type;
  /// If true, offered with all flowers; if false, specific to vendors.
  final bool isGlobal;
  /// If false, hidden from customers; admin can toggle. Default true.
  final bool isActive;

  const AddOnModel({
    required this.id,
    required this.nameEn,
    required this.nameKu,
    required this.nameAr,
    required this.priceIqd,
    required this.imageUrl,
    required this.type,
    this.isGlobal = true,
    this.isActive = true,
  });

  /// Localized name for locale code: en, ku, ar.
  String nameForLocale(String localeCode) {
    switch (localeCode) {
      case 'ku':
        return nameKu;
      case 'ar':
        return nameAr;
      default:
        return nameEn;
    }
  }

  factory AddOnModel.fromJson(String id, Map<String, dynamic> json) {
    final typeStr = json['category']?.toString() ?? json['type']?.toString();
    final type = AddOnTypeX.fromString(typeStr) ?? AddOnType.vase;
    return AddOnModel(
      id: id,
      nameEn: json['nameEn']?.toString() ?? json['name']?.toString() ?? '',
      nameKu: json['nameKu']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? '',
      priceIqd: (json['priceIqd'] as num?)?.toInt() ?? (json['price'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      type: type,
      isGlobal: json['isGlobal'] != false,
      isActive: json['isActive'] != false,
    );
  }

  /// Firestore document for addons collection: { category, name, price, imageUrl, isActive }.
  Map<String, dynamic> toJson() {
    return {
      'category': type.categoryValue,
      'name': nameEn,
      'price': priceIqd,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }
}
