/// Lightweight model for listing vendors (designers/florists) on the public page.
/// Data comes from the [vendors] Firestore collection (one doc per approved vendor).
class VendorListModel {
  final String id;
  final String shopName;
  /// Optional shop logo URL. When null, UI can show a placeholder.
  final String? logoUrl;
  /// Optional star rating (e.g. 0–5). When null, UI can hide or show "No reviews".
  final double? rating;

  const VendorListModel({
    required this.id,
    required this.shopName,
    this.logoUrl,
    this.rating,
  });

  factory VendorListModel.fromFirestore(String id, Map<String, dynamic> data) {
    final shopName = data['studioName']?.toString().trim() ??
        data['shopName']?.toString().trim() ??
        '';
    final logoUrl = data['logoUrl']?.toString().trim();
    final raw = data['rating'];
    final rating = raw is num
        ? raw.toDouble()
        : (raw != null ? double.tryParse(raw.toString()) : null);
    return VendorListModel(
      id: id,
      shopName: shopName.isNotEmpty ? shopName : 'Shop',
      logoUrl: logoUrl != null && logoUrl.isNotEmpty ? logoUrl : null,
      rating: rating,
    );
  }
}
