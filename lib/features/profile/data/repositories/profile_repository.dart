import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userProfileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

class ProfileRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // 1. Update Display Name
  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await user.updateDisplayName(newName);
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': newName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // 2. Reliable Profile Picture Update (Direct Base64 Sync - No Storage Bucket Errors)
  Future<String> uploadProfileImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User session not found");

    final bytes = await imageFile.readAsBytes();
    final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    await _firestore.collection('users').doc(user.uid).update({
      'photoUrl': base64String,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return base64String;
  }

  // 3. Change Password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("User session not found");
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("Current password galat hai.");
      } else if (e.code == 'weak-password') {
        throw Exception("Naya password kam az kam 6 characters ka hona chahiye.");
      }
      throw Exception(e.message ?? "Password update nahi ho saka.");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}