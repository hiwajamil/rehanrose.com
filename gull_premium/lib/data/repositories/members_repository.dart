import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/customer_member_model.dart';

/// Result of a paginated customers fetch (cursor-based).
class PaginatedCustomersResult {
  final List<CustomerMemberModel> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedCustomersResult({
    required this.items,
    this.lastDocument,
    this.hasMore = false,
  });
}

/// Same region as [gull_premium/functions/index.js] callable exports.
const String _functionsRegion = 'europe-west1';

/// Repository for Super Admin CRM: customers (users with role == 'customer').
class MembersRepository {
  MembersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: _functionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const String _usersCollection = 'users';
  static const int _pageSize = 20;

  /// Stream of live customer count (users where role == 'customer').
  Stream<int> watchCustomerCount() {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Fetches a page of customers (newest first). Use [startAfter] for the next page.
  Future<PaginatedCustomersResult> getCustomersPage({
    DocumentSnapshot? startAfter,
    int limit = _pageSize,
  }) async {
    var query = _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: 'customer')
        .orderBy('createdAt', descending: true)
        .limit(limit + 1);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    final lastDoc = pageDocs.isNotEmpty ? pageDocs.last : null;

    final list = <CustomerMemberModel>[];
    for (final doc in pageDocs) {
      try {
        final model = CustomerMemberModel.fromFirestore(doc.id, doc.data());
        if (model != null) list.add(model);
      } catch (_) {
        // Skip malformed documents so one bad doc doesn't fail the whole page
        continue;
      }
    }

    return PaginatedCustomersResult(
      items: list,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }

  /// Deletes a customer’s Firebase Auth account and Firestore profile (admin-only; server-side).
  Future<void> deleteCustomerMember(String targetUid) async {
    final callable = _functions.httpsCallable('deleteCustomerUser');
    await callable.call(<String, dynamic>{'targetUid': targetUid});
  }
}
