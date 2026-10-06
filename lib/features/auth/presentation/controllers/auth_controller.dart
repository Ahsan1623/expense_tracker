import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// App me check karne ke liye k user logged in hai ya nahi
final authStateProvider = StreamProvider<User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

// Current User ki Live Profile (Naam, DP, Email) ke liye Auto-Dispose Provider
// User switch hone ya logout hone par ye khud-ba-khud memory clean karega
final currentUserProfileProvider =
    StreamProvider.autoDispose<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;

  if (authUser == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) {
          return UserModel(
            uid: authUser.uid,
            email: authUser.email ?? '',
            displayName: authUser.displayName ?? 'User',
            photoUrl: authUser.photoURL,
            createdAt: DateTime.now(),
          );
        }
        return UserModel.fromMap(doc.data()!, doc.id);
      });
});