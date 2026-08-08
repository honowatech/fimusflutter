class UssdFormatter {
  /// Normalise un template USSD provenant du Backoffice, de la BD ou du Frontoffice.
  ///
  /// - Nettoie les espaces parasites, tabulations, retours à la ligne.
  /// - Remplace les encodages URL (`%23` -> `#`, `%2A` -> `*`).
  /// - Harmonise les placeholders : `${key}`, `<key>`, `[key]`, `:key`, `%key%` -> `{key}` (minuscules).
  /// - Remplace les `#` internes parasites (ex: `#144#11*` -> `#144*11*`).
  /// - Élimine les doublons de symboles USSD (`**` -> `*`, `##` -> `#`).
  /// - S'assure que le template commence par `*` ou `#` et se termine par `#`.
  static String normalizeTemplate(String rawTemplate) {
    if (rawTemplate.trim().isEmpty) return '';

    String template = rawTemplate.trim();

    // 1. Décodage basique URL si présent
    template = template.replaceAll('%23', '#').replaceAll('%2A', '*').replaceAll('%2a', '*');

    // 2. Nettoyage espaces et retours à la ligne internes
    template = template.replaceAll(RegExp(r'\s+'), '');

    // 3. Harmonisation des placeholders en {key} minuscules
    // Format ${key} -> {key}
    template = template.replaceAllMapped(
      RegExp(r'\$\{(\w+)\}'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );
    // Format <key> -> {key}
    template = template.replaceAllMapped(
      RegExp(r'<(\w+)>'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );
    // Format [key] -> {key}
    template = template.replaceAllMapped(
      RegExp(r'\[(\w+)\]'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );
    // Format :key -> {key}
    template = template.replaceAllMapped(
      RegExp(r':([a-zA-Z_]\w*)'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );
    // Format %key% -> {key}
    template = template.replaceAllMapped(
      RegExp(r'%(\w+)%'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );
    // Format {key} standard -> minuscule
    template = template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => '{${m.group(1)!.toLowerCase()}}',
    );

    // 4. Garantir le bon format de démarrage et de fin
    if (!template.endsWith('#')) {
      template = '$template#';
    }
    if (!template.startsWith('*') && !template.startsWith('#')) {
      template = '*$template';
    }

    // 5. Remplacer tout '#' intermédiaire (ni au premier caractère, ni au dernier) par '*'
    // Exemple: #144#11*{phone}*{amount}# -> #144*11*{phone}*{amount}#
    if (template.length > 2) {
      final String firstChar = template[0];
      String middle = template.substring(1, template.length - 1);
      middle = middle.replaceAll('#', '*');
      template = '$firstChar$middle#';
    }

    // 6. Nettoyage des doublons de symboles (* et #)
    template = template.replaceAll(RegExp(r'\*+'), '*');
    template = template.replaceAll(RegExp(r'#+'), '#');

    return template;
  }

  /// Extrait la liste ordonnée et unique des champs requis (placeholders `{field}`) d'un template normalisé.
  static List<String> extractFields(String template) {
    final normalized = normalizeTemplate(template);
    final matches = RegExp(r'\{(\w+)\}').allMatches(normalized);
    final Set<String> fields = {};
    for (final m in matches) {
      final field = m.group(1);
      if (field != null && field.isNotEmpty) {
        fields.add(field.toLowerCase());
      }
    }
    return fields.toList();
  }

  /// Assainit un numéro de téléphone pour un code USSD local.
  /// Supprime les espaces, tirets, parenthèses et préfixes internationaux (`+237`, `00237`, etc.).
  static String sanitizePhoneNumber(String rawPhone) {
    String phone = rawPhone.trim().replaceAll(RegExp(r'[^0-9]'), '');
    
    // Supprimer le préfixe '00' international si présent
    if (phone.startsWith('00')) {
      phone = phone.substring(2);
    }
    
    // Indicatifs pays d'Afrique gérés dans l'application (ex: 237, 225, 221, etc.)
    final countryCodes = ['237', '225', '221', '229', '228', '223', '226', '243', '224', '241', '242', '227', '233', '254', '261'];
    for (final code in countryCodes) {
      if (phone.startsWith(code) && phone.length > code.length + 6) {
        phone = phone.substring(code.length);
        break;
      }
    }
    
    // Pour les numéros à 9 chiffres (ex: Cameroun) : si un '0' initial a été saisi pour 10 chiffres (ex: 0670000000 -> 670000000)
    if (phone.length == 10 && phone.startsWith('0') && (phone.startsWith('06') || phone.startsWith('02') || phone.startsWith('03'))) {
      phone = phone.substring(1);
    }
    
    return phone;
  }

  /// Assainit un montant numérique pour un code USSD.
  /// Supprime les décimales `.0`, `.00`, les espaces, virgules et devises.
  static String sanitizeAmount(String rawAmount) {
    String clean = rawAmount.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    // Supprimer suffixe devise ou texte non numérique excepté point
    clean = clean.replaceAll(RegExp(r'[^0-9.]'), '');
    
    if (clean.contains('.')) {
      final doubleVal = double.tryParse(clean);
      if (doubleVal != null) {
        return doubleVal.round().toString();
      }
      clean = clean.split('.').first;
    }
    return clean;
  }

  /// Construit le code USSD final prêt à être exécuté par le téléphone.
  ///
  /// - Normalise le template.
  /// - Fait la correspondance intelligente des clés (phone/contact/numero/agent, amount/montant/prix, merchant_code/code_marchand).
  /// - Assainit chaque valeur injectée.
  /// - Lève une exception claire si un placeholder n'a pas été fourni.
  static String buildFinalCode(String template, Map<String, String> values) {
    String finalCode = normalizeTemplate(template);

    // Normaliser le map des valeurs (clés en minuscules)
    final Map<String, String> normalizedValues = {};
    values.forEach((k, v) {
      normalizedValues[k.toLowerCase()] = v;
    });

    final fields = extractFields(finalCode);

    for (final field in fields) {
      String? value = normalizedValues[field];

      // Tenter les alias courants si la clé exacte n'existe pas dans `values`
      if (value == null || value.isEmpty) {
        if (field == 'contact' || field == 'phone' || field == 'numero' || field == 'recipient' || field == 'agent' || field == 'destinataire' || field == 'telephone' || field == 'msisdn') {
          value = normalizedValues['contact'] ??
              normalizedValues['phone'] ??
              normalizedValues['numero'] ??
              normalizedValues['recipient'] ??
              normalizedValues['agent'] ??
              normalizedValues['destinataire'] ??
              normalizedValues['telephone'] ??
              normalizedValues['msisdn'];
        } else if (field == 'amount' || field == 'montant' || field == 'price' || field == 'somme' || field == 'valeur') {
          value = normalizedValues['amount'] ??
              normalizedValues['montant'] ??
              normalizedValues['price'] ??
              normalizedValues['somme'] ??
              normalizedValues['valeur'];
        } else if (field == 'merchant_code' || field == 'code_marchand' || field == 'merchant' || field == 'marchand' || field == 'code') {
          value = normalizedValues['merchant_code'] ??
              normalizedValues['code_marchand'] ??
              normalizedValues['merchant'] ??
              normalizedValues['marchand'] ??
              normalizedValues['code'];
        }
      }

      if (value == null || value.trim().isEmpty) {
        throw Exception('Valeur manquante pour le champ USSD: $field');
      }

      // Assainissement de la valeur selon son type
      String sanitizedValue;
      if (field == 'contact' || field == 'phone' || field == 'numero' || field == 'recipient' || field == 'agent' || field == 'destinataire' || field == 'telephone' || field == 'msisdn') {
        sanitizedValue = sanitizePhoneNumber(value);
      } else if (field == 'amount' || field == 'montant' || field == 'price' || field == 'somme' || field == 'valeur') {
        sanitizedValue = sanitizeAmount(value);
      } else if (field == 'merchant_code' || field == 'code_marchand' || field == 'merchant' || field == 'marchand' || field == 'code') {
        sanitizedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
      } else {
        sanitizedValue = value.replaceAll(RegExp(r'[^0-9*#]'), '');
      }

      if (sanitizedValue.isEmpty) {
        throw Exception('Valeur invalide ou vide pour le champ USSD: $field');
      }

      finalCode = finalCode.replaceAll('{$field}', sanitizedValue);
    }

    // Détection de tout placeholder non substitué résiduel (ex: {inconnu})
    final remainingPlaceholders = RegExp(r'\{(\w+)\}').allMatches(finalCode);
    if (remainingPlaceholders.isNotEmpty) {
      final missing = remainingPlaceholders.map((m) => m.group(1) ?? '').where((s) => s.isNotEmpty).join(', ');
      throw Exception('Valeur manquante pour le champ USSD: $missing');
    }

    // Nettoyage final des symboles doubles accidentels
    finalCode = normalizeTemplate(finalCode);

    // Validation finale de syntaxe USSD
    if (!RegExp(r'^[*#][0-9*#]+#$').hasMatch(finalCode)) {
      throw Exception('Code USSD final invalide: $finalCode');
    }

    return finalCode;
  }
}
