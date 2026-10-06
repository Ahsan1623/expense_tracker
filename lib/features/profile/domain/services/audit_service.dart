import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/audit_log_model.dart';

final auditServiceProvider = Provider<AuditService>((ref) => AuditService());

final userAuditLogsStreamProvider = StreamProvider<List<AuditLogModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('audit_history')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => AuditLogModel.fromMap(doc.data(), doc.id))
          .toList());
});

class AuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Permanent log write for a user
  Future<void> logActivity({
    required String userId,
    required String title,
    required String description,
    required double amount,
    required AuditType type,
    String? groupName,
    String? personName,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('audit_history')
          .doc();

      final log = AuditLogModel(
        logId: docRef.id,
        title: title,
        description: description,
        amount: amount,
        type: type,
        groupName: groupName,
        personName: personName,
        timestamp: DateTime.now(),
      );

      await docRef.set(log.toMap());
    } catch (_) {
      // Background audit failsafe
    }
  }

  // Clear ONLY from the dedicated History screen
  Future<void> clearAllUserHistory(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('audit_history')
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}