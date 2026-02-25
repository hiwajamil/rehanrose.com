import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/vendor_list_model.dart';

/// Super admin email — always has admin access without admins collection.
/// Set via --dart-define=SUPER_ADMIN_EMAIL=... for different environments.
const String kSuperAdminEmail = String.fromEnvironment(
  'SUPER_ADMIN_EMAIL',
  defaultValue: 'hiwa.constructions@gmail.com',
);

/// Repository for authentication and user/vendor/admin status.
class AuthRepository {
  AuthRepository({
    fa.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fa.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fa.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

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

  /// Sign out. Also signs out from Google so next sign-in is fresh.
  /// If the user signed in with email/password, Google sign-out may throw on web;
  /// we still sign out from Firebase so sign-out always succeeds.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore: user may have signed in with email/password; still sign out from Firebase.
    }
    await _auth.signOut();
  }

  /// Sign in with Google. On success, ensures a document exists in [users]
  /// with [uid], [email], [displayName], [photoURL], [createdAt], and
  /// [role: 'customer'] (only if the user doc does not already exist).
  /// Throws on failure (e.g. [fa.FirebaseAuthException], sign-in cancelled).
  Future<fa.UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('sign_in_cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null && accessToken == null) {
      throw Exception(
        'Google Sign-In failed: no credentials. Ensure GOOGLE_WEB_CLIENT_ID is set (Firebase Console → Authentication → Google → Web client ID).',
      );
    }
    final credential = fa.GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await ensureCustomerUserDocIfNeeded(user);
    }
    return userCredential;
  }

  /// Ensures a document exists in [users] for the given Firebase [user].
  /// If the doc does not exist, creates it with uid, email, displayName,
  /// photoURL, createdAt, and role: 'customer'. If it exists, merges only
  /// profile fields so existing role/vendorStatus are preserved.
  Future<void> ensureCustomerUserDocIfNeeded(fa.User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));
      return;
    }
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'customer',
    });
  }

  /// Vendor status for the given user id: 'pending' | 'approved' | 'rejected'.
  Future<String> getVendorStatus(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['vendorStatus']?.toString() ?? 'pending';
  }

  /// User role from Firestore [users] collection: e.g. 'admin', 'vendor'. Null if not set.
  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role']?.toString();
  }

  /// Whether the user is an admin (exists in admins collection or is super admin email).
  Future<bool> isAdmin(String uid) async {
    final user = _auth.currentUser;
    if (user?.email?.trim().toLowerCase() == kSuperAdminEmail.trim().toLowerCase()) {
      return true;
    }
    final doc = await _firestore.collection('admins').doc(uid).get();
    return doc.exists;
  }

  /// Ensures super admin has role 'admin' in users collection (for Firestore rules).
  Future<void> ensureSuperAdminUserDoc(String uid) async {
    await _firestore.collection('users').doc(uid).set(
      {'role': 'admin'},
      SetOptions(merge: true),
    );
  }

  /// Fetches the current user's profile from Firestore [users] collection.
  /// Returns a map with fullName (or displayName), email, phone (phoneNumber), city, photoURL.
  /// Returns null if the document does not exist.
  Future<Map<String, String>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final fullName = data['fullName']?.toString().trim() ??
        data['displayName']?.toString().trim() ??
        '';
    final email = data['email']?.toString().trim() ?? '';
    final phone = data['phoneNumber']?.toString().trim() ?? '';
    final city = data['city']?.toString().trim() ?? '';
    final photoURL = data['photoURL']?.toString();
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'city': city,
      if (photoURL != null && photoURL.isNotEmpty) 'photoURL': photoURL,
    };
  }

  /// Get stored language preference for user. Returns null if not set.
  Future<String?> getLanguage(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['language']?.toString();
  }

  /// Save user language preference (e.g. 'en', 'ar', 'ku').
  Future<void> setLanguage(String uid, String languageCode) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'language': languageCode}, SetOptions(merge: true));
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

  /// Fetches all approved vendors (designers/florists) from the [vendors] collection.
  /// Each document represents one approved vendor; doc id is the vendor uid.
  Future<List<VendorListModel>> getVendors() async {
    final snap = await _firestore.collection('vendors').get();
    final list = <VendorListModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(VendorListModel.fromFirestore(doc.id, doc.data()));
      } catch (e, st) {
        debugPrint('Error parsing vendor doc ${doc.id}: $e');
        debugPrintStack(stackTrace: st);
      }
    }
    return list;
  }

  /// Fetches a single vendor by id (for profile page header). Returns null if not found.
  Future<VendorListModel?> getVendorById(String vendorId) async {
    final doc = await _firestore.collection('vendors').doc(vendorId).get();
    final data = doc.data();
    if (data == null) return null;
    try {
      return VendorListModel.fromFirestore(doc.id, data);
    } catch (e, st) {
      debugPrint('Error parsing vendor doc $vendorId: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}
