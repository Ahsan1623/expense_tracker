import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // 1. Sign Up With Email Verification
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user != null) {
      await user.updateDisplayName(displayName.trim());
      await user.sendEmailVerification();

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email?.toLowerCase().trim(),
        'displayName': displayName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
      });

      await _auth.signOut();
    }
  }

  // 2. Log In With Verification Check
  Future<UserModel> logInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('Login failed. User profile not found.');
    }

    await user.reload();
    final updatedUser = _auth.currentUser;

    if (updatedUser != null && !updatedUser.emailVerified) {
      await _auth.signOut();
      throw Exception(
        'Email verified nahi hai! Kripya apne inbox/spam folder mein ja kar verification link confirm karein.',
      );
    }

    await _firestore.collection('users').doc(user.uid).set({
      'isVerified': true,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return UserModel.fromMap(doc.data() ?? {}, user.uid);
  }

  // 3. Google Sign-In (Always forces account picker)
  Future<UserModel?> signInWithGoogle() async {
    // Pichla session clear karein taake har dafa popup account chooser khule
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential cred = await _auth.signInWithCredential(credential);
    final User? user = cred.user;

    if (user == null) {
      throw Exception('Google Sign-In mukammal nahi ho saka.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email?.toLowerCase().trim(),
        'displayName': user.displayName ?? googleUser.displayName ?? 'Google User',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });
    }

    final freshDoc = await _firestore.collection('users').doc(user.uid).get();
    return UserModel.fromMap(freshDoc.data() ?? {}, user.uid);
  }

  // 4. Forgot Password (Sirf registered email par jayega)
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw Exception('Apna registered email darj karein.');
    }

    // Step 1: Firestore verify karega ke user exist karta hai ya nahi
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Yeh email kisi account se registered nahi hai. Pehle sign up karein.');
    }

    // Step 2: Sirf verified / registered email par Firebase reset trigger karega
    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}