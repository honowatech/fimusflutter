import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/formatters.dart';

/// Textes et formats des notifications produits **hors arbre de widgets**.
///
/// Trois chemins produisent des textes sans `BuildContext` :
///  * la planification des rappels locaux ([ReminderScheduler]), appelée
///    depuis des providers ou des services ;
///  * la création des canaux Android au démarrage ;
///  * l'isolat d'arrière-plan FCM ([firebaseMessagingBackgroundHandler]) et
///    l'isolat de tap ([notificationTapBackground]), où **aucun** état de
///    l'isolat principal n'est visible.
///
/// Mécanisme retenu : on ne dépend jamais d'un `BuildContext`, on résout
/// directement les traductions à partir du code de langue enregistré, via
/// `lookupAppLocalizations(Locale(code))` (API générée par `flutter gen-l10n`).
/// Le code de langue a deux sources, dans cet ordre :
///  1. [setLocale], appelé par `LocaleProvider` dans l'isolat principal (mise
///     à jour immédiate lors d'un changement de langue) ;
///  2. [loadLocale], qui relit la clé SharedPreferences `language_code`
///     écrite par ce même provider. C'est l'unique source disponible dans un
///     isolat d'arrière-plan : les champs statiques n'y sont pas partagés,
///     [localeCode] y repart donc du défaut tant que [loadLocale] n'a pas été
///     appelé. Tout point d'entrée d'arrière-plan doit l'appeler en premier.
///
/// Repli : locale inconnue ou préférence absente → français.
class NotificationTexts {
  NotificationTexts._();

  /// Clé SharedPreferences écrite par `LocaleProvider.setLocale`.
  static const prefsLocaleKey = 'language_code';

  /// Langue de repli (et défaut historique de l'application).
  static const fallbackLocaleCode = 'fr';

  /// Code de langue courant. Toujours normalisé à la lecture par
  /// [forLocaleCode] : une valeur inattendue retombe sur [fallbackLocaleCode].
  static String localeCode = fallbackLocaleCode;

  /// Normalise un code stocké (`fr`, `en_US`, `EN-gb`, `null`…) vers une
  /// locale réellement supportée. Fonction pure, testable sans plugin.
  static String resolveLocaleCode(String? stored) {
    final raw = stored?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return fallbackLocaleCode;
    final base = raw.split(RegExp(r'[-_]')).first;
    final supported = AppLocalizations.supportedLocales.map(
      (l) => l.languageCode,
    );
    return supported.contains(base) ? base : fallbackLocaleCode;
  }

  /// Traductions correspondant à un code de langue, avec repli.
  /// Fonction pure (aucun canal de plateforme), testable directement.
  static AppLocalizations forLocaleCode(String? code) {
    try {
      return lookupAppLocalizations(Locale(resolveLocaleCode(code)));
    } catch (_) {
      return lookupAppLocalizations(const Locale(fallbackLocaleCode));
    }
  }

  /// Traductions pour la langue courante.
  static AppLocalizations get current => forLocaleCode(localeCode);

  /// Appelé par `LocaleProvider` (isolat principal) à chaque changement de langue.
  static void setLocale(Locale locale) {
    localeCode = resolveLocaleCode(locale.languageCode);
  }

  /// Relit la langue enregistrée sur disque et renvoie les traductions.
  ///
  /// À appeler au début de tout point d'entrée d'arrière-plan et au début de
  /// `NotificationService.init()` : c'est le seul moyen de connaître la langue
  /// choisie dans un isolat qui vient de démarrer.
  static Future<AppLocalizations> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      localeCode = resolveLocaleCode(prefs.getString(prefsLocaleKey));
    } catch (e) {
      debugPrint('Error loading notification locale: $e');
    }
    return current;
  }

  /// Montant affiché dans une notification : séparateur de milliers de
  /// `lib/utils/formatters.dart`, décimales conservées seulement si elles
  /// existent (1 500 000 · 1 500,25 → « 1 500 000 » / « 1 500 000.25 »).
  /// Fonction pure, testable sans plugin.
  static String formatAmount(num amount) {
    final rounded = amount.roundToDouble();
    if ((amount - rounded).abs() < 0.005) return amount.formatAmount();
    return amount.formatAmountDouble();
  }

  /// Heure affichée dans une notification, au format 24 h « HH:mm ».
  ///
  /// Volontairement indépendant de `intl.DateFormat` : les symboles de date
  /// localisés ne sont pas initialisés dans un isolat d'arrière-plan, et le
  /// format 24 h est celui utilisé partout dans l'application.
  /// Fonction pure.
  static String formatTime(DateTime when) =>
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
}
