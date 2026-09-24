import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../models/notification_model.dart';
import 'notification_category_visual.dart';

/// Formatage relatif de la date d'une notification.
///
/// « À l'instant » → « il y a 12 min » → « il y a 3 h » → date courte
/// localisée (`intl`). Aucune dépendance au fuseau : l'appelant fournit
/// une date déjà locale et le `now` courant (testable).
class NotificationDateLabel {
  const NotificationDateLabel._();

  static String relative(
    DateTime? date, {
    required DateTime now,
    required String locale,
    required AppLocalizations l10n,
  }) {
    if (date == null) return '';
    final elapsed = now.difference(date);

    // Horloge serveur légèrement en avance : on ne montre jamais de négatif.
    if (elapsed.isNegative || elapsed.inMinutes < 1) {
      return l10n.notificationTimeJustNow;
    }
    if (elapsed.inMinutes < 60) {
      return l10n.notificationTimeMinutesAgo(elapsed.inMinutes);
    }
    if (elapsed.inHours < 24) {
      return l10n.notificationTimeHoursAgo(elapsed.inHours);
    }
    // Au-delà de 24 h : date courte, sans l'année tant qu'on reste dans
    // l'année civile en cours.
    if (date.year == now.year) {
      return DateFormat.MMMd(locale).format(date);
    }
    return DateFormat.yMd(locale).format(date);
  }
}

/// Une ligne du centre de notifications.
///
/// Accessibilité :
/// - l'état lu / non lu n'est PAS porté par la seule couleur de fond : le titre
///   passe en gras et une pastille « Non lu » textuelle s'affiche ;
/// - la tuile entière est fusionnée en un seul nœud sémantique (catégorie,
///   état, titre, message, date) ;
/// - hauteur minimale de 72 dp (> 48 dp) et mise en page en [Wrap] pour la
///   ligne date + état, afin de ne pas déborder à `textScaler` 1.5.
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  /// Mode sélection multiple actif (appui long) : la case à cocher remplace
  /// l'icône de catégorie et le glissement est désactivé par l'écran.
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// `now` injecté pour que la liste entière partage le même instant de
  /// référence (et pour rendre le rendu testable).
  final DateTime now;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final isRead = notification.isRead;
    final title = notification.title.isNotEmpty
        ? notification.title
        : (notification.message.isNotEmpty
            ? notification.message
            : l10n.notificationFallback);
    // Le message n'est répété en second que s'il apporte autre chose que le
    // titre déjà affiché.
    final body = notification.title.isNotEmpty ? notification.message : '';
    final dateLabel = NotificationDateLabel.relative(
      notification.createdAtLocal,
      now: now,
      locale: locale,
      l10n: l10n,
    );

    final background = isSelected
        ? scheme.primary.withValues(alpha: 0.18)
        : (isRead ? null : scheme.primary.withValues(alpha: 0.06));

    final stateLabel =
        isRead ? l10n.notificationReadBadge : l10n.notificationUnreadBadge;

    return MergeSemantics(
      child: Semantics(
        selected: isSelectionMode ? isSelected : null,
        // Annonce explicite de l'état : le lecteur d'écran ne « voit » ni le
        // gras ni la teinte de fond.
        value: stateLabel,
        child: Material(
          color: background ?? Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _leading(context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Wrap (et non Row) : à textScaler 1.5 la date et la
                          // pastille passent à la ligne au lieu de déborder.
                          Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (dateLabel.isNotEmpty)
                                Text(
                                  dateLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              if (!isRead)
                                _unreadBadge(theme, scheme, stateLabel),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(BuildContext context) {
    if (!isSelectionMode) {
      return NotificationCategoryAvatar(category: notification.category);
    }
    // Cible tactile de 48 dp garantie par `materialTapTargetSize.padded`.
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Checkbox(
          value: isSelected,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onChanged: (_) => onTap(),
        ),
      ),
    );
  }

  /// Marqueur de non-lu : pastille + libellé texte, pour ne pas reposer
  /// uniquement sur la couleur (daltonisme, contraste faible).
  Widget _unreadBadge(ThemeData theme, ColorScheme scheme, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
