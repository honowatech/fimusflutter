enum AccountType {
  particulier('particulier', 'Personnel'),
  petitCommerce('petit_commerce', 'Petit commerce (vente)'),
  entreprise('entreprise', 'Entreprise (Service)'),
  kiosque('kiosque', 'Kiosque (transfert d\'argent)');

  final String key;
  final String label;

  const AccountType(this.key, this.label);

  /// Indique si ce profil a accès aux opérations USSD Agent/Marchand
  bool get hasUssdAgent => this == kiosque;

  /// Indique si ce profil a le module de gestion de produits
  bool get hasProducts => this == petitCommerce;

  /// Indique si ce profil a le module de gestion d'équipe / staff
  bool get hasStaff => this == entreprise;

  /// Indique si ce profil utilise le menu USSD (Personnel standard ou Kiosque agent)
  bool get hasUssdMenu => this == particulier || this == kiosque;

  /// Indique s'il s'agit d'un compte particulier / personnel
  bool get isPersonal => this == particulier;

  /// Indique s'il s'agit d'une activité commerciale ou professionnelle
  bool get isBusiness => !isPersonal;

  static AccountType fromString(String? raw) {
    if (raw == null) return particulier;
    final t = raw.toLowerCase().trim();
    switch (t) {
      case 'particulier':
      case 'personal':
      case 'individual':
        return particulier;

      case 'petit_commerce':
      case 'petitcommerce':
      case 'commerce':
      case 'commercant':
      case 'boutique':
        return petitCommerce;

      case 'entreprise':
      case 'company':
      case 'service':
      case 'professionnel': // Rétrocompatibilité : les anciens 'professionnel' sont migrés vers Entreprise
      case 'professional':
        return entreprise;

      case 'kiosque':
      case 'agent':
      case 'transfert':
        return kiosque;

      default:
        return particulier;
    }
  }
}
