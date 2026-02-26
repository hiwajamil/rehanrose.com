import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer/member as shown in Super Admin CRM (users collection, role == 'customer').
class CustomerMemberModel {
  final String uid;
  final String fullName;
  final String phone;
  final String city;
  final DateTime? createdAt;
  /// Optional: treat as VIP if true or e.g. order count >= threshold in UI.
  final bool isVip;

  const CustomerMemberModel({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.city,
    this.createdAt,
    this.isVip = false,
  });

  static CustomerMemberModel? fromFirestore(String docId, Map<String, dynamic>? data) {
    if (data == null) return null;
    final role = data['role']?.toString();
    if (role != 'customer') return null;

    final fullName = data['fullName']?.toString().trim() ??
        data['displayName']?.toString().trim() ??
        '';
    final phone = data['phoneNumber']?.toString().trim() ??
        data['phone']?.toString().trim() ??
        '';
    final city = data['city']?.toString().trim() ?? '';

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
      fullName: fullName.isEmpty ? '—' : fullName,
      phone: phone.isEmpty ? '—' : phone,
      city: city.isEmpty ? '—' : city,
      createdAt: createdAt,
      isVip: isVip,
    );
  }
}
