import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../widgets/notification_filter_bar.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();

  /// Filtre de catégorie, purement local (aucun aller-retour serveur).
  NotificationFilter _filter = NotificationFilter.all;

  /// Suppressions par glissement en attente de confirmation : conservées ici
  /// pour être propagées au serveur si l'écran est quitté avant l'expiration
  /// de la SnackBar.
  final List<PendingNotificationDeletion> _pendingDeletions = [];

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetch();
    });
  }

  @override
  void dispose() {
    // La SnackBar disparaît avec l'écran : on confirme ce qui restait en
    // attente, sinon la suppression ne partirait jamais vers l'API.
    if (_pendingDeletions.isNotEmpty) {
      final provider = context.read<NotificationProvider>();
      for (final pending in List.of(_pendingDeletions)) {
        provider.confirmRemoval(pending);
      }
      _pendingDeletions.clear();
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Pagination au défilement : on précharge avant d'atteindre le bas.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 300) return;
    final provider = context.read<NotificationProvider>();
    if (provider.hasMore && !provider.isLoadingMore && !provider.isLoading) {
      provider.loadMore();
    }
  }

  Future<void> _deleteIds(NotificationProvider provider, List<String> ids) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await provider.deleteNotifications(ids);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorDeleteNotif)),
      );
    }
  }

  /// Suppression par glissement : retrait immédiat + SnackBar « Annuler ».
  /// L'appel serveur n'est émis qu'à la fermeture de la SnackBar.
  void _dismissOne(NotificationProvider provider, NotificationModel notif) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final pending = provider.removeForUndo([notif.id]);
    if (pending.isEmpty) return;
    _pendingDeletions.add(pending);
    _selectedIds.remove(notif.id);

    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.notificationDeleted),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () {
            // La restauration réelle est faite dans le callback `closed`,
            // qui reçoit `SnackBarClosedReason.action`.
          },
        ),
      ),
    );

    controller.closed.then((reason) async {
      _pendingDeletions.remove(pending);
      if (reason == SnackBarClosedReason.action) {
        provider.restoreRemoved(pending);
        return;
      }
      final success = await provider.confirmRemoval(pending);
      if (!success && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorDeleteNotif)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final isSelectionMode = _selectedIds.isNotEmpty;
    final now = DateTime.now();

    final visible = applyNotificationFilter(notifications, _filter);
    final counts = _countByCategory(notifications);
    final rows = _buildRows(visible, l10n, now, provider.hasMore);

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
                tooltip: l10n.clearSelectionTooltip,
              )
            : null,
        title: Text(
          isSelectionMode
              ? l10n.notificationsSelectedCount(_selectedIds.length)
              : l10n.notifications,
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                final idsToDelete = _selectedIds.toList();
                _deleteIds(provider, idsToDelete);
                _clearSelection();
              },
              tooltip: l10n.delete,
            )
          else
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: notifications.any((n) => !n.isRead)
                  ? () {
                      final messenger = ScaffoldMessenger.of(context);
                      provider.markAllAsRead().then((success) {
                        if (!success && mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.errorMarkAllNotifRead)),
                          );
                        }
                      });
                    }
                  : null,
              tooltip: l10n.markAllAsReadTooltip,
            ),
        ],
        // Rafraîchissement non bloquant : un filet de progression sous l'AppBar
        // au lieu d'un spinner plein écran qui remplacerait la liste.
        bottom: provider.isRefreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          if (provider.isStale) _offlineBanner(context, provider),
          if (notifications.isNotEmpty)
            NotificationFilterBar(
              selected: _filter,
              counts: counts,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          Expanded(
            child: provider.isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.fetch,
                    child: notifications.isEmpty
                        ? _emptyState(context, l10n, provider)
                        : visible.isEmpty
                            ? _emptyForFilter(context)
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  if (row is _InboxLoadMore) {
                                    return _loadMoreFooter(context, provider);
                                  }
                                  if (row is _InboxHeader) {
                                    return _sectionHeader(context, row.label);
                                  }
                                  final item = row as _InboxTile;
                                  return _dismissibleTile(
                                    context,
                                    l10n,
                                    provider,
                                    item.notification,
                                    isSelectionMode,
                                    now,
                                  );
                                },
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Map<NotificationCategory, int> _countByCategory(
    List<NotificationModel> items,
  ) {
    final counts = <NotificationCategory, int>{};
    for (final item in items) {
      counts.update(item.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Aplatit les sections (« Aujourd'hui », « Hier », « Cette semaine »,
  /// « Plus tôt ») en une liste de lignes pour `ListView.builder`.
  /// L'ordre interne de chaque section reste celui du serveur (plus récent
  /// d'abord).
  List<Object> _buildRows(
    List<NotificationModel> items,
    AppLocalizations l10n,
    DateTime now,
    bool hasMore,
  ) {
    final buckets = <NotificationDateBucket, List<NotificationModel>>{};
    for (final item in items) {
      final bucket = NotificationDateBucket.of(item.createdAtLocal, now: now);
      buckets.putIfAbsent(bucket, () => []).add(item);
    }

    final rows = <Object>[];
    for (final bucket in NotificationDateBucket.values) {
      final section = buckets[bucket];
      if (section == null || section.isEmpty) continue;
      rows.add(_InboxHeader(_bucketLabel(bucket, l10n)));
      rows.addAll(section.map(_InboxTile.new));
    }
    if (hasMore) rows.add(const _InboxLoadMore());
    return rows;
  }

  String _bucketLabel(NotificationDateBucket bucket, AppLocalizations l10n) {
    switch (bucket) {
      case NotificationDateBucket.today:
        return l10n.today;
      case NotificationDateBucket.yesterday:
        return l10n.yesterday;
      case NotificationDateBucket.thisWeek:
        return l10n.thisWeek;
      case NotificationDateBucket.earlier:
        return l10n.notificationSectionEarlier;
    }
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Tuile + glissement de suppression. En mode sélection multiple le
  /// glissement est neutralisé pour ne pas entrer en conflit avec les
  /// cases à cocher.
  Widget _dismissibleTile(
    BuildContext context,
    AppLocalizations l10n,
    NotificationProvider provider,
    NotificationModel notif,
    bool isSelectionMode,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final tile = NotificationTile(
      notification: notif,
      isSelectionMode: isSelectionMode,
      isSelected: _selectedIds.contains(notif.id),
      now: now,
      onLongPress: () => _toggleSelection(notif.id),
      onTap: () => _onTileTap(provider, l10n, notif, isSelectionMode),
    );

    if (isSelectionMode) return tile;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: theme.colorScheme.error,
        child: Semantics(
          label: l10n.delete,
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
      ),
      onDismissed: (_) => _dismissOne(provider, notif),
      child: tile,
    );
  }

  void _onTileTap(
    NotificationProvider provider,
    AppLocalizations l10n,
    NotificationModel notif,
    bool isSelectionMode,
  ) {
    if (isSelectionMode) {
      _toggleSelection(notif.id);
      return;
    }
    if (!notif.isRead) {
      // Un placeholder local est traité sans appel API côté provider :
      // pas d'erreur affichée tant que le vrai id n'est pas connu.
      final messenger = ScaffoldMessenger.of(context);
      provider.markAsRead(notif.id).then((success) {
        if (!success && mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.errorMarkNotifRead)),
          );
        }
      });
    }
    NotificationService().handleNotificationData(notif.data);
  }

  Widget _emptyState(
    BuildContext context,
    AppLocalizations l10n,
    NotificationProvider provider,
  ) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              provider.fetchFailed
                  ? l10n.errorFetchNotifications
                  : l10n.noNotifications,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (provider.fetchFailed)
          TextButton(
            onPressed: provider.fetch,
            style: _minTapTarget,
            child: Text(l10n.retry),
          ),
      ],
    );
  }

  /// État vide propre au filtre : la liste n'est pas vide, c'est la catégorie
  /// sélectionnée qui ne contient rien parmi les éléments chargés.
  Widget _emptyForFilter(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.filter_alt_off_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.notificationsEmptyForFilter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _filter = NotificationFilter.all),
            style: _minTapTarget,
            child: Text(l10n.notificationsShowAllFilters),
          ),
        ),
      ],
    );
  }

  /// Bandeau discret affiché quand la liste vient du cache local.
  Widget _offlineBanner(BuildContext context, NotificationProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final syncedAt = provider.lastSyncAt;
    final label = syncedAt == null
        ? l10n.offlineBanner
        : l10n.offlineBannerWithDate(
            DateFormat.yMMMd(locale).add_Hm().format(syncedAt),
          );

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: provider.isLoading ? null : provider.fetch,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Semantics(
                  label: l10n.retry,
                  child: Icon(
                    Icons.refresh,
                    size: 16,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pied de liste : spinner pendant le chargement de la page suivante, sinon
  /// un repli cliquable (cas où la liste tient dans l'écran, donc pas de scroll).
  Widget _loadMoreFooter(BuildContext context, NotificationProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: provider.loadMore,
          style: _minTapTarget,
          child: Text(AppLocalizations.of(context)!.loadMore),
        ),
      ),
    );
  }

  /// Cible tactile minimale de 48 dp (recommandation d'accessibilité) :
  /// le `TextButton` par défaut plafonne à 36 dp de haut.
  static final ButtonStyle _minTapTarget = TextButton.styleFrom(
    minimumSize: const Size(48, 48),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _InboxHeader {
  final String label;
  const _InboxHeader(this.label);
}

class _InboxTile {
  final NotificationModel notification;
  const _InboxTile(this.notification);
}

class _InboxLoadMore {
  const _InboxLoadMore();
}
