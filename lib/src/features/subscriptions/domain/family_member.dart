import 'package:uuid/uuid.dart';

class FamilyMember {
  final String id;
  final String name;
  final String photoUrl;
  final bool isCurrentUser;
  final String? email;
  final String status; // 'pending' or 'accepted'
  final String? linkedUserId;

  FamilyMember({
    required this.id,
    required this.name,
    required this.photoUrl,
    this.isCurrentUser = false,
    this.email,
    this.status = 'pending',
    this.linkedUserId,
  });

  factory FamilyMember.create({
    required String name,
    required String photoUrl,
    bool isCurrentUser = false,
    String? email,
  }) {
    return FamilyMember(
      id: const Uuid().v4(),
      name: name,
      photoUrl: photoUrl,
      isCurrentUser: isCurrentUser,
      email: email,
      status: 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'isCurrentUser': isCurrentUser,
      'email': email,
      'status': status,
      'linkedUserId': linkedUserId,
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMember(
      id: id,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isCurrentUser: map['isCurrentUser'] ?? false,
      email: map['email'],
      status: map['status'] ?? 'pending',
      linkedUserId: map['linkedUserId'],
    );
  }
}
