/// Normalisation des noms de catégories : chaque mot en Title case
/// (majuscule initiale, reste en minuscules), plusieurs mots autorisés,
/// espaces superflus supprimés. Appliquée à la création comme à l'affichage
/// pour garantir une casse homogène dans toute l'application.
String normalizeCategory(String input) {
  final compact = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.isEmpty) return compact;
  return compact
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

const String _diacritics = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
const String _base = 'aaaaaaceeeeiiiinooooouuuuyy';

/// Clé de tri alphabétique insensible à la casse et aux accents
/// (é → e, è → e…) pour un ordre correct en français.
String categorySortKey(String input) {
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().split('')) {
    final index = _diacritics.indexOf(char);
    buffer.write(index >= 0 ? _base[index] : char);
  }
  return buffer.toString();
}
