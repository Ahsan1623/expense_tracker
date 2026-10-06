import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_contact_model.dart';
import '../../../auth/data/models/user_model.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

// Stream of incoming pending friend requests
final incomingRequestsStreamProvider =
    StreamProvider<List<CommunityContactModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return ref.watch(communityRepositoryProvider).getIncomingRequests(user.uid);
});

// Stream of accepted mutual community contacts
final communityContactsStreamProvider =
    StreamProvider<List<UserModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return ref.watch(communityRepositoryProvider).getMutualContacts(user.uid);
});

class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Send Connection Request via Email
  Future<void> sendConnectionRequest(String targetEmail) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User session not found");

    final cleanEmail = targetEmail.trim().toLowerCase();
    if (cleanEmail == currentUser.email?.toLowerCase()) {
      throw Exception("Aap khud ko request nahi bhej sakte.");
    }

    // Check if target user exists
    final targetUserSnap = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (targetUserSnap.docs.isEmpty) {
      throw Exception("Is email se koi registered user nahi mila.");
    }

    final targetUserDoc = targetUserSnap.docs.first;
    final targetUserId = targetUserDoc.id;

    // Check if already friends
    final existingContact = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('community')
        .doc(targetUserId)
        .get();

    if (existingContact.exists) {
      throw Exception("Yeh user pehle se aapki community mein mojood hai.");
    }

    // Check if request already pending
    final existingRequest = await _firestore
        .collection('community_requests')
        .where('senderId', isEqualTo: currentUser.uid)
        .where('receiverId', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception("Request pehle se pending hai.");
    }

    final docRef = _firestore.collection('community_requests').doc();
    final request = CommunityContactModel(
      requestId: docRef.id,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      senderName: currentUser.displayName ?? 'User',
      receiverId: targetUserId,
      receiverEmail: cleanEmail,
      status: ContactStatus.pending,
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toMap());
  }

  // 2. Incoming Requests Stream
  Stream<List<CommunityContactModel>> getIncomingRequests(String currentUserId) {
    return _firestore
        .collection('community_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommunityContactModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // 3. Accept Connection Request (Two-way mutual link)
  Future<void> acceptRequest(CommunityContactModel request) async {
    final batch = _firestore.batch();
    final requestRef =
        _firestore.collection('community_requests').doc(request.requestId);

    batch.update(requestRef, {'status': 'accepted'});

    // Add to sender's community
    final senderRef = _firestore
        .collection('users')
        .doc(request.senderId)
        .collection('community')
        .doc(request.receiverId);
    batch.set(senderRef, {
      'userId': request.receiverId,
      'email': request.receiverEmail,
      'connectedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Add to receiver's community
    final receiverRef = _firestore
        .collection('users')
        .doc(request.receiverId)
        .collection('community')
        .doc(request.senderId);
    batch.set(receiverRef, {
      'userId': request.senderId,
      'email': request.senderEmail,
      'connectedAt': Timestamp.fromDate(DateTime.now()),
    });

    await batch.commit();
  }

  // 4. Decline Request
  Future<void> declineRequest(String requestId) async {
    await _firestore
        .collection('community_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  // 5. Get Mutual Contacts Stream
  Stream<List<UserModel>> getMutualContacts(String currentUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('community')
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <UserModel>[];

      final contactIds = snap.docs.map((d) => d.id).toList();
      final List<UserModel> contacts = [];

      for (final id in contactIds) {
        final userDoc = await _firestore.collection('users').doc(id).get();
        if (userDoc.exists) {
          contacts.add(UserModel.fromMap(userDoc.data()!, userDoc.id));
        }
      }
      return contacts;
    });
  }

  // 6. Remove Connection (Only if net balance across all shared groups is 0)
  Future<void> removeConnection({
    required String currentUserId,
    required String targetUserId,
  }) async {
    // Check all mutual groups to ensure balance is 0
    final groupsSnap = await _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .get();

    for (final doc in groupsSnap.docs) {
      final members = List<String>.from(doc.data()['members'] ?? []);
      if (members.contains(targetUserId)) {
        final balances = Map<String, dynamic>.from(doc.data()['netBalances'] ?? {});
        final myBal = (balances[currentUserId] as num?)?.toDouble() ?? 0.0;
        final targetBal = (balances[targetUserId] as num?)?.toDouble() ?? 0.0;

        // If either has unsettled balances in shared groups
        if (myBal.abs() > 0.01 && targetBal.abs() > 0.01) {
          throw Exception(
            "Is dost ke sath kuch groups me hisaab baki hai. Pehle tamam shared groups settle karein phir remove karein.",
          );
        }
      }
    }

    final batch = _firestore.batch();
    final myRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('community')
        .doc(targetUserId);

    final targetRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('community')
        .doc(currentUserId);

    batch.delete(myRef);
    batch.delete(targetRef);

    await batch.commit();
  }
}