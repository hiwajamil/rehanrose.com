import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer/member as shown in Super Admin CRM (users collection, role == 'customer').
/// All string fields use safe fallbacks so parsing never throws.
class CustomerMemberModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final DateTime? createdAt;
  /// Optional: treat as VIP if true or e.g. order count >= threshold in UI.
  final bool isVip;

  const CustomerMemberModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    this.createdAt,
    this.isVip = false,
  });

  /// Parses a Firestore user document. Returns null if data is null or role != 'customer'.
  /// Never throws: uses fallbacks for null/missing fields (e.g. 'No Name', 'No Email', 'N/A').
  static CustomerMemberModel? fromFirestore(String docId, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      final role = data['role']?.toString();
      if (role != 'customer') return null;

      final fullName = _string(data['fullName']) ??
          _string(data['displayName']) ??
          'No Name';
      final email = _string(data['email']) ?? 'No Email';
      final phone = _string(data['phoneNumber']) ??
          _string(data['phone']) ??
          'N/A';
      final city = _string(data['city']) ?? 'N/A';

      DateTime? createdAt;
      final ts = data['createdAt'];
      if (ts is Timestamp) {
        createdAt = ts.toDate();
      } else if (ts is DateTime) {
        createdAt = ts;
      } else if (ts != null) {
        createdAt = DateTime.tryParse(ts.toString());
      }

      final isVip = data['isVip'] == true || data['vip'] == true;

      return CustomerMemberModel(
        uid: docId,
        fullName: fullName.isEmpty ? 'No Name' : fullName,
        email: email.isEmpty ? 'No Email' : email,
        phone: phone.isEmpty ? 'N/A' : phone,
        city: city.isEmpty ? 'N/A' : city,
        createdAt: createdAt,
        isVip: isVip,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
