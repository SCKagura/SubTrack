import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'family_member.g.dart';

@HiveType(typeId: 0)
class FamilyMember {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String photoUrl;

  @HiveField(3)
  final bool isCurrentUser;

  FamilyMember({
    required this.id,
    required this.name,
    required this.photoUrl,
    this.isCurrentUser = false,
  });

  factory FamilyMember.create({
    required String name,
    required String photoUrl,
    bool isCurrentUser = false,
  }) {
    return FamilyMember(
      id: const Uuid().v4(),
      name: name,
      photoUrl: photoUrl,
      isCurrentUser: isCurrentUser,
    );
  }
}
