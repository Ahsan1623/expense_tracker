import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String baseCurrency;
  final String createdById;
  final List<String> members;
  final Map<String, String> memberRoles; // userId -> 'ADMIN' | 'MEMBER'
  final Map<String, String> tempMembers; // tempId -> displayName (Guest/Without app)
  final Map<String, double> netBalances; // userId -> net balance
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
    this.tempMembers = const {},
    this.netBalances = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  // Saare real + temp members ki combined IDs
  List<String> get allMemberIds => [...members, ...tempMembers.keys];

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      baseCurrency: map['baseCurrency'] ?? 'PKR',
      createdById: map['createdById'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      memberRoles: Map<String, String>.from(map['memberRoles'] ?? {}),
      tempMembers: Map<String, String>.from(map['tempMembers'] ?? {}),
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
      'tempMembers': tempMembers,
      'netBalances': netBalances,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}