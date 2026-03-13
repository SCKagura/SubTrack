class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String currency;
  final double monthlyBudget;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.currency = 'THB',
    this.monthlyBudget = 0,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      currency: map['currency'] ?? 'THB',
      monthlyBudget: (map['monthlyBudget'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'currency': currency,
      'monthlyBudget': monthlyBudget,
    };
  }
}
