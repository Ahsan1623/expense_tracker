import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String defaultCurrency;
  final List<String> fcmTokens;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.defaultCurrency = 'PKR', // Default currency set kar sakte hain
    this.fcmTokens = const [],
    required this.createdAt,
  });

  // Firestore se data read karne ke liye
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      defaultCurrency: map['defaultCurrency'] ?? 'PKR',
      fcmTokens: List<String>.from(map['fcmTokens'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore me save karne ke liye
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'defaultCurrency': defaultCurrency,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}