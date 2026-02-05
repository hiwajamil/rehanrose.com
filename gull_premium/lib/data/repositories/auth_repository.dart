import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

/// Repository for authentication and user/vendor/admin status.
class AuthRepository {
  AuthRepository({
    fa.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fa.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fa.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Current user or null if not signed in.
  fa.User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<fa.User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password. Throws [fa.FirebaseAuthException] on failure.
  Future<fa.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Create user with email and password. Throws [fa.FirebaseAuthException] on failure.
  Future<fa.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign out.
  Future<void> signOut() => _auth.signOut();

  /// Vendor status for the given user id: 'pending' | 'approved' | 'rejected'.
  Future<String> getVendorStatus(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['vendorStatus']?.toString() ?? 'pending';
  }

  /// Whether the user is an admin (exists in admins collection).
  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('admins').doc(uid).get();
    return doc.exists;
  }

  /// Set user document (e.g. after sign up) with role and vendorStatus.
  /// Adds createdAt with server timestamp.
  Future<void> setUserDoc(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Set vendor application document. Adds createdAt with server timestamp.
  Future<void> setVendorApplication(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('vendor_applications').doc(uid).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update vendor application status (admin approval/rejection).
  Future<void> updateVendorApplication(
    String applicationId, {
    required String status,
    String? approvedBy,
    String? rejectedBy,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      if (status == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
      if (status == 'rejected') 'rejectedAt': FieldValue.serverTimestamp(),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
    };
    await _firestore
        .collection('vendor_applications')
        .doc(applicationId)
        .update(updates);
  }

  /// Set user vendorStatus (e.g. approved).
  Future<void> setUserVendorStatus(String uid, String status) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'vendorStatus': status}, SetOptions(merge: true));
  }

  /// Set vendors document (studio info). Merges with existing.
  Future<void> setVendorDoc(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('vendors')
        .doc(uid)
        .set({...data, 'approvedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Approve a vendor application: update application, user status, and create vendor doc.
  Future<void> approveVendorApplication(
    String applicationId,
    Map<String, dynamic> applicationData,
    String adminId,
  ) async {
    await updateVendorApplication(applicationId, status: 'approved', approvedBy: adminId);
    await setUserVendorStatus(applicationId, 'approved');
    await setVendorDoc(applicationId, {
      'studioName': applicationData['studioName'],
      'ownerName': applicationData['ownerName'],
      'email': applicationData['email'],
      'phone': applicationData['phone'],
      'location': applicationData['location'],
    });
  }

  /// Reject a vendor application.
  Future<void> rejectVendorApplication(String applicationId, String adminId) async {
    await updateVendorApplication(applicationId, status: 'rejected', rejectedBy: adminId);
    await setUserVendorStatus(applicationId, 'rejected');
  }

  /// Stream of pending vendor applications for admin.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchVendorApplications() {
    return _firestore
        .collection('vendor_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
