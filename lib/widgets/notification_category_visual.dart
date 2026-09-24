import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../models/notification_model.dart';

/// Habillage visuel d'une catégorie de notification : icône + couleurs.
///
/// Toutes les couleurs sont dérivées du [ColorScheme] courant — aucune couleur
/// littérale (`Colors.blue`, `Colors.grey`…) ne doit apparaître ici, sous peine
/// de casser le thème clair/sombre et les thèmes personnalisés (la couleur de
/// base est choisie par l'utilisateur via `ThemeProvider.primaryColor`).
class NotificationCategoryVisual {
  /// Icône représentant la catégorie.
  final IconData icon;

  /// Couleur de l'icône (contraste garanti sur [background]).
  final Color foreground;

  /// Fond de la pastille portant l'icône.
  final Color background;

  const NotificationCategoryVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  /// Dérive l'habillage d'une catégorie à partir du thème.
  ///
  /// Chaque catégorie reçoit un couple `container` / `onContainer` distinct :
  /// la teinte suit donc automatiquement la couleur d'accent de l'application.
  factory NotificationCategoryVisual.of(
    NotificationCategory category,
    ColorScheme scheme,
  ) {
    switch (category) {
      case NotificationCategory.debts:
        return NotificationCategoryVisual(
          icon: Icons.account_balance_wallet_outlined,
          foreground: scheme.onErrorContainer,
          background: scheme.errorContainer,
        );
      case NotificationCategory.contacts:
        return NotificationCategoryVisual(
          icon: Icons.person_add_alt_1_outlined,
          foreground: scheme.onSecondaryContainer,
          background: scheme.secondaryContainer,
        );
      case NotificationCategory.jointAccounts:
        return NotificationCategoryVisual(
          icon: Icons.groups_outlined,
          foreground: scheme.onPrimaryContainer,
          background: scheme.primaryContainer,
        );
      case NotificationCategory.scheduledExpenses:
        return NotificationCategoryVisual(
          icon: Icons.event_repeat_outlined,
          foreground: scheme.onTertiaryContainer,
          background: scheme.tertiaryContainer,
        );
      case NotificationCategory.announcements:
        return NotificationCategoryVisual(
          icon: Icons.campaign_outlined,
          foreground: scheme.onInverseSurface,
          background: scheme.inverseSurface,
        );
      case NotificationCategory.other:
        return NotificationCategoryVisual(
          icon: Icons.notifications_none,
          foreground: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHighest,
        );
    }
  }
}

/// Libellé lisible d'une catégorie, réutilisé par la tuile (lecteur d'écran)
/// et par les puces de filtre.
String notificationCategoryLabel(
  NotificationCategory category,
  AppLocalizations l10n,
) {
  switch (category) {
    case NotificationCategory.debts:
      return l10n.debts;
    case NotificationCategory.contacts:
      return l10n.notificationFilterContacts;
    case NotificationCategory.jointAccounts:
      return l10n.accounts;
    case NotificationCategory.scheduledExpenses:
      return l10n.notificationFilterScheduled;
    case NotificationCategory.announcements:
      return l10n.announcements;
    case NotificationCategory.other:
      return l10n.notifications;
  }
}

/// Pastille circulaire portant l'icône de la catégorie.
///
/// Taille fixe (indépendante de `textScaler`) pour que la colonne de texte
/// garde toute la largeur disponible quand la police grossit.
class NotificationCategoryAvatar extends StatelessWidget {
  final NotificationCategory category;

  const NotificationCategoryAvatar({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final visual = NotificationCategoryVisual.of(
      category,
      Theme.of(context).colorScheme,
    );
    final label = notificationCategoryLabel(
      category,
      AppLocalizations.of(context)!,
    );

    return Semantics(
      label: label,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: visual.background,
          shape: BoxShape.circle,
        ),
        child: Icon(visual.icon, size: 20, color: visual.foreground),
      ),
    );
  }
}
