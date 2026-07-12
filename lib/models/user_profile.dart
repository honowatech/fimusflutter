class UserProfile {
  final String firstName;
  final String lastName;
  final String currency;
  final String country;

  UserProfile({
    required this.firstName,
    required this.lastName,
    this.currency = 'CFA',
    this.country = 'Tous',
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'currency': currency,
      'country': country,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      currency: json['currency'] ?? 'CFA',
      country: json['country'] ?? 'Tous',
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? currency,
    String? country,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currency: currency ?? this.currency,
      country: country ?? this.country,
    );
  }
}
