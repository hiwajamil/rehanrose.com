import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_member_model.dart';

/// Repository for Super Admin CRM: customers (users with role == 'customer').
class MembersRepository {
  MembersRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const int _customersLimit = 500;

  /// Stream of live customer count (users where role == 'customer').
  Stream<int> watchCustomerCount() {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Stream of all customers ordered by createdAt (newest first).
  Stream<List<CustomerMemberModel>> watchCustomers() {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'customer')
        .orderBy('createdAt', descending: true)
        .limit(_customersLimit)
        .snapshots()
        .map((snap) {
      final list = <CustomerMemberModel>[];
      for (final doc in snap.docs) {
        final model = CustomerMemberModel.fromFirestore(doc.id, doc.data());
        if (model != null) list.add(model);
      }
      return list;
    });
  }
}
