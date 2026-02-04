class FlowerModel {
  final String id;
  final String name;
  final String description;
  final int priceIqd;
  final List<String> imageUrls;
  final String bouquetCode;
  final DateTime? createdAt;
  final String occasion;

  const FlowerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceIqd,
    required this.imageUrls,
    required this.occasion,
    required this.bouquetCode,
    this.createdAt,
  });

  static String _requireOccasion(dynamic value) {
    final s = value?.toString();
    if (s == null || s.isEmpty) {
      throw FormatException('FlowerModel.occasion is required');
    }
    return s;
  }

  factory FlowerModel.fromJson(String id, Map<String, dynamic> json) {
    return FlowerModel(
      id: id,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceIqd: (json['priceIqd'] as num?)?.toInt() ?? 0,
      imageUrls: (json['imageUrls'] as List?)?.cast<String>() ?? [],
      occasion: _requireOccasion(json['occasion']),
      bouquetCode: json['bouquetCode']?.toString() ?? '',
      createdAt: (json['createdAt'] as dynamic) != null
          ? DateTime.tryParse((json['createdAt'] as dynamic).toString())
          : null,
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
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
