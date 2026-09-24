import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../models/notification_model.dart';
import 'notification_category_visual.dart';

/// Filtre de catégorie du centre de notifications.
///
/// Purement côté client : il ne porte que sur les éléments DÉJÀ chargés (la
/// pagination reste pilotée par le serveur, sans paramètre de catégorie).
enum NotificationFilter {
  all(null),
  debts(NotificationCategory.debts),
  contacts(NotificationCategory.contacts),
  jointAccounts(NotificationCategory.jointAccounts),
  scheduledExpenses(NotificationCategory.scheduledExpenses),
  announcements(NotificationCategory.announcements);

  /// `null` pour [NotificationFilter.all] : aucun filtrage.
  final NotificationCategory? category;

  const NotificationFilter(this.category);

  bool matches(NotificationModel notification) {
    final target = category;
    if (target == null) return true;
    return notification.category == target;
  }

  String label(AppLocalizations l10n) {
    final target = category;
    if (target == null) return l10n.all;
    return notificationCategoryLabel(target, l10n);
  }
}

/// Filtre la liste selon [filter] en conservant l'ordre d'origine.
List<NotificationModel> applyNotificationFilter(
  List<NotificationModel> items,
  NotificationFilter filter,
) {
  if (filter == NotificationFilter.all) return items;
  return items.where(filter.matches).toList();
}

/// Bandeau de puces de filtre, en tête de liste.
///
/// Défilement horizontal : à `textScaler` 1.5 les puces s'allongent sans
/// jamais provoquer d'overflow.
class NotificationFilterBar extends StatelessWidget {
  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onChanged;

  /// Nombre d'éléments chargés par catégorie, affiché en suffixe de la puce.
  /// Une catégorie à zéro reste sélectionnable : l'écran montre alors son
  /// état vide dédié.
  final Map<NotificationCategory, int> counts;

  const NotificationFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final filter in NotificationFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_chipLabel(filter, l10n, total)),
                selected: filter == selected,
                showCheckmark: true,
                // Garantit une cible tactile d'au moins 48 dp de haut.
                materialTapTargetSize: MaterialTapTargetSize.padded,
                tooltip: filter.label(l10n),
                onSelected: (_) => onChanged(filter),
              ),
            ),
        ],
      ),
    );
  }

  /// Libellé + effectif chargé, ex. « Dettes (3) ». Le nombre est omis à zéro
  /// pour ne pas alourdir la puce.
  String _chipLabel(NotificationFilter filter, AppLocalizations l10n, int total) {
    final label = filter.label(l10n);
    final count =
        filter == NotificationFilter.all ? total : (counts[filter.category] ?? 0);
    return count > 0 ? '$label ($count)' : label;
  }
}
