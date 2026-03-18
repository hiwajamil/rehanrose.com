import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_occasion_model.dart';

/// Repository for user occasions (users/{uid}/occasions).
class UserOccasionsRepository {
  UserOccasionsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _occasionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('occasions');

  /// Stream of occasions for the given user.
  Stream<List<UserOccasionModel>> watchOccasions(String uid) {
    return _occasionsRef(uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserOccasionModel.fromFirestore(d.id, d.data()))
            .whereType<UserOccasionModel>()
            .toList());
  }

  /// Add an occasion. Returns the new document id.
  Future<String> addOccasion(String uid, {required String name, required DateTime date}) async {
    final ref = await _occasionsRef(uid).add(
      UserOccasionModel(id: '', name: name, date: date).toFirestore(),
    );
    return ref.id;
  }

  /// Update an existing occasion by id.
  Future<void> updateOccasion(
    String uid,
    String occasionId, {
    required String name,
    required DateTime date,
  }) async {
    await _occasionsRef(uid).doc(occasionId).update(
          UserOccasionModel(id: occasionId, name: name, date: date).toFirestore(),
        );
  }

  /// Delete an occasion by id.
  Future<void> deleteOccasion(String uid, String occasionId) async {
    await _occasionsRef(uid).doc(occasionId).delete();
  }
}
