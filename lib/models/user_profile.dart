class UserProfile {
  final String firstName;
  final String lastName;
  final String currency;
  final String country;
  final String? photoUrl;
  final String type;

  UserProfile({
    required this.firstName,
    required this.lastName,
    this.currency = 'CFA',
    this.country = 'Tous',
    this.photoUrl,
    this.type = 'particulier',
  });

  bool get isProfessionnel {
    final t = type.toLowerCase().trim();
    return t == 'professional' || t == 'professionnel' || t == 'agent';
  }
  bool get isParticulier => !isProfessionnel;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'currency': currency,
      'country': country,
      'photoUrl': photoUrl,
      'type': type,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      currency: json['currency'] ?? 'CFA',
      country: json['country'] ?? 'Tous',
      photoUrl: json['photoUrl'],
      type: json['type'] ?? json['userType'] ?? 'particulier',
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? currency,
    String? country,
    String? photoUrl,
    String? type,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currency: currency ?? this.currency,
      country: country ?? this.country,
      photoUrl: photoUrl ?? this.photoUrl,
      type: type ?? this.type,
    );
  }
}

