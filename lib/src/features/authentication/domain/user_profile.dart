class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String currency;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.currency = 'THB',
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      currency: map['currency'] ?? 'THB',
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'displayName': displayName, 'currency': currency};
  }
}
