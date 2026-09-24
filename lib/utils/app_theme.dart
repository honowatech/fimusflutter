import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Construction centralisée des thèmes de l'application.
///
/// Les deux thèmes partent de la même couleur de marque (`seed`, choisie par
/// l'utilisateur via `ThemeProvider.primaryColor`) et de la même base
/// Material 3 : seuls les jetons qui dépendent de la luminosité diffèrent.
///
/// IMPORTANT : [AppTheme.light] doit rester strictement identique au thème
/// historiquement construit dans `main.dart` (bordures d'`InputDecoration`,
/// `GoogleFonts.outfitTextTheme()`, Material 3) — aucune régression visuelle
/// n'est acceptable en mode clair.
class AppTheme {
  const AppTheme._();

  /// Rayon commun à toutes les bordures de champs de saisie.
  static const double _fieldRadius = 12.0;

  /// Thème clair (référence historique, ne pas modifier sans capture avant/après).
  static ThemeData light(Color seed) => _build(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      );

  /// Thème sombre, dérivé de la même couleur de marque.
  static ThemeData dark(Color seed) => _build(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      );

  static ThemeData _build(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    // google_fonts applique la typographie par défaut du mode demandé quand on
    // ne lui passe rien : en sombre, il faut explicitement partir du TextTheme
    // sombre, sinon le texte reste noir sur fond noir.
    final textTheme = isDark
        ? GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.outfitTextTheme();

    // En clair on conserve la valeur littérale d'origine (Colors.grey.shade400)
    // pour garder un rendu au pixel près ; en sombre on passe par le jeton
    // `outline`, seul contraste lisible sur une surface foncée.
    final enabledBorderColor =
        isDark ? colorScheme.outline : Colors.grey.shade400;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: enabledBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Jetons de couleur sémantiques dérivés du [ColorScheme] courant.
///
/// Les widgets avaient historiquement des couleurs littérales
/// (`Colors.orange.shade800` pour un avertissement, `Colors.blue.shade50` pour
/// un bandeau informatif…) illisibles en thème sombre. Ces extensions donnent
/// un couple « conteneur / contenu » qui reste contrasté dans les deux modes,
/// en conservant la teinte attendue en clair.
extension AppSemanticColors on ColorScheme {
  bool get _isDark => brightness == Brightness.dark;

  /// Choisit une couleur selon la luminosité du thème courant.
  ///
  /// Utile pour les rares teintes d'identité (avatars de catégorie, bannière
  /// DEV…) qu'on veut garder **à l'identique en clair** tout en leur donnant
  /// une variante lisible en sombre.
  Color tone({required Color light, required Color dark}) =>
      _isDark ? dark : light;

  /// Teinte d'avertissement (orange/ambre) lisible dans les deux thèmes.
  Color get warning => _isDark
      ? const Color(0xFFFFB951) // ambre désaturé, contraste AA sur fond sombre
      : const Color(0xFFEF6C00); // Colors.orange.shade800 historique

  /// Fond des bandeaux et cartouches d'avertissement.
  Color get warningContainer =>
      _isDark ? const Color(0xFF4A3100) : const Color(0xFFFFF8E1);

  /// Texte et icônes posés sur [warningContainer].
  Color get onWarningContainer =>
      _isDark ? const Color(0xFFFFDFA8) : const Color(0xFFFF6F00);

  /// Bordure des cartouches d'avertissement.
  Color get warningOutline =>
      _isDark ? const Color(0xFF7A5400) : const Color(0xFFFFE082);

  /// Teinte informative (bleu) lisible dans les deux thèmes.
  Color get info =>
      _isDark ? const Color(0xFF9CCAFF) : const Color(0xFF1565C0);

  /// Fond des bandeaux informatifs.
  Color get infoContainer =>
      _isDark ? const Color(0xFF00325B) : const Color(0xFFE3F2FD);

  /// Texte et icônes posés sur [infoContainer].
  Color get onInfoContainer =>
      _isDark ? const Color(0xFFD3E4FF) : const Color(0xFF0D47A1);

  /// Bordure des bandeaux informatifs.
  Color get infoOutline =>
      _isDark ? const Color(0xFF17497B) : const Color(0xFF90CAF9);

  /// Teinte de succès (vert) lisible dans les deux thèmes.
  Color get success =>
      _isDark ? const Color(0xFF7BDC9A) : const Color(0xFF2E7D32);

  /// Teinte de dépense / montant négatif.
  Color get expense =>
      _isDark ? const Color(0xFFFF8A80) : const Color(0xFFE53935);

  /// Teinte de revenu / montant positif.
  Color get income =>
      _isDark ? const Color(0xFF69F0AE) : const Color(0xFF00C853);

  /// Ombre discrète des cartes, plus marquée en sombre pour rester perceptible.
  Color get cardShadow => _isDark
      ? Colors.black.withValues(alpha: 0.30)
      : Colors.black.withValues(alpha: 0.04);
}
