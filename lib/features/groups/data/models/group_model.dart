import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String baseCurrency;
  final String createdById;
  final List<String> members;
  final Map<String, String> memberRoles; // userId -> 'ADMIN' | 'MEMBER'
  final Map<String, double> netBalances; // userId -> net balance (+ve owes money, -ve in debt)
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.description,
    this.baseCurrency = 'PKR',
    required this.createdById,
    required this.members,
    required this.memberRoles,
    this.netBalances = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      baseCurrency: map['baseCurrency'] ?? 'PKR',
      createdById: map['createdById'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      memberRoles: Map<String, String>.from(map['memberRoles'] ?? {}),
      netBalances: (map['netBalances'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'baseCurrency': baseCurrency,
      'createdById': createdById,
      'members': members,
      'memberRoles': memberRoles,
      'netBalances': netBalances,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}