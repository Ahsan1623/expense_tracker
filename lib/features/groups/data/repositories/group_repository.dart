import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../models/group_model.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

// Current user ke groups ki real-time stream
final userGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(groupRepositoryProvider);
  return repo.getUserGroups(user.uid);
});

class GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Create Group with Initial Members
  Future<void> createGroup({
    required String name,
    required String description,
    required String creatorId,
    List<String> initialMemberEmails = const [],
  }) async {
    final docRef = _firestore.collection('groups').doc();

    final Set<String> memberIds = {creatorId};
    final Map<String, double> netBalances = {creatorId: 0.0};

    for (final email in initialMemberEmails) {
      final cleanEmail = email.trim().toLowerCase();
      final userSnap = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        final uid = userSnap.docs.first.id;
        memberIds.add(uid);
        netBalances[uid] = 0.0;
      }
    }

    final group = GroupModel(
      groupId: docRef.id,
      name: name,
      description: description,
      createdById: creatorId,
      members: memberIds.toList(),
      netBalances: netBalances,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(), memberRoles: {},
    );

    await docRef.set(group.toMap());
  }

  // Add Member to Existing Group by Email (Baad me add karne ke liye)
  Future<void> addMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final userSnap = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (userSnap.docs.isEmpty) {
      throw Exception('Is email se koi registered user nahi mila.');
    }

    final newUserId = userSnap.docs.first.id;
    final groupRef = _firestore.collection('groups').doc(groupId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupRef);
      if (!snap.exists) throw Exception('Group nahi mila.');

      final members = List<String>.from(snap.data()!['members'] ?? []);
      if (members.contains(newUserId)) {
        throw Exception('Yeh user pehle se is group ka member hai.');
      }

      final balances = Map<String, dynamic>.from(snap.data()!['netBalances'] ?? {});
      members.add(newUserId);
      balances[newUserId] = 0.0;

      transaction.update(groupRef, {
        'members': members,
        'netBalances': balances,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }
}

// Members profiles fetch karne ka provider
final groupMembersProfilesProvider =
    FutureProvider.family<Map<String, String>, List<String>>((ref, memberIds) async {
  if (memberIds.isEmpty) return {};

  final firestore = FirebaseFirestore.instance;
  final Map<String, String> namesMap = {};

  final snapshots = await firestore
      .collection('users')
      .where(FieldPath.documentId, whereIn: memberIds.take(10).toList())
      .get();

  for (final doc in snapshots.docs) {
    final data = doc.data();
    namesMap[doc.id] = data['displayName'] ?? data['email'] ?? 'Member';
  }

  for (final id in memberIds) {
    namesMap.putIfAbsent(
      id,
      () => 'Member (${id.substring(0, id.length > 5 ? 5 : id.length)})',
    );
  }

  return namesMap;
});