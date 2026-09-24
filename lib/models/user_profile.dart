import 'account_type.dart';

class UserProfile {
  final String firstName;
  final String lastName;
  final String currency;
  final String country;
  final String? photoUrl;
  final String type;
  final bool hasChangedType;

  UserProfile({
    required this.firstName,
    required this.lastName,
    this.currency = 'CFA',
    this.country = 'Tous',
    this.photoUrl,
    this.type = 'particulier',
    this.hasChangedType = false,
  });

  /// Type de compte typé
  AccountType get accountType => AccountType.fromString(type);

  /// Profil Personnel
  bool get isParticulier => accountType.isPersonal;

  /// Profil Kiosque (Transfert d'argent)
  bool get isKiosque => accountType == AccountType.kiosque;

  /// Profil Petit commerce (Vente)
  bool get isCommercant => accountType == AccountType.petitCommerce;

  /// Profil Entreprise (Service)
  bool get isEntreprise => accountType == AccountType.entreprise;

  /// Accès aux codes USSD Agent / Marchand
  bool get hasUssdAgent => accountType.hasUssdAgent;

  /// Rétrocompatibilité : équivalent à hasUssdAgent (ou compte non particulier)
  bool get isProfessionnel => hasUssdAgent;

  /// Accès au module Produits
  bool get hasProducts => accountType.hasProducts;

  /// Accès au module Staff
  bool get hasStaff => accountType.hasStaff;

  /// Affichage du menu USSD (Particulier ou Kiosque)
  bool get hasUssdMenu => accountType.hasUssdMenu;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'currency': currency,
      'country': country,
      'photoUrl': photoUrl,
      'type': type,
      'hasChangedType': hasChangedType,
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
      hasChangedType: json['hasChangedType'] ?? false,
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? currency,
    String? country,
    String? photoUrl,
    String? type,
    bool? hasChangedType,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currency: currency ?? this.currency,
      country: country ?? this.country,
      photoUrl: photoUrl ?? this.photoUrl,
      type: type ?? this.type,
      hasChangedType: hasChangedType ?? this.hasChangedType,
    );
  }
}

