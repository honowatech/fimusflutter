import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
// Accès direct au dépôt uniquement pour l'horodatage de synchronisation :
// NotificationService n'expose pas (encore) ce point d'entrée.
import '../services/notifications/inbox_repository.dart';
import '../utils/inbox_merge.dart';
import '../utils/notification_route.dart';

/// Une notification retirée de la liste, avec la position qu'elle occupait.
class RemovedNotification {
  final int index;
  final NotificationModel notification;

  const RemovedNotification({required this.index, required this.notification});
}

/// Suppression optimiste en attente de confirmation (SnackBar « Annuler »).
///
/// Même principe que les rollbacks par snapshot déjà utilisés par le provider,
/// mais l'appel serveur est différé : tant que le jeton n'est pas confirmé,
/// rien n'est envoyé à l'API et l'élément peut retrouver sa place exacte.
class PendingNotificationDeletion {
  /// Triées par index croissant : la réinsertion dans cet ordre restitue
  /// l'ordre d'origine.
  final List<RemovedNotification> entries;
  final int removedUnread;

  /// Un jeton ne se résout qu'une fois : la SnackBar et `dispose()` de l'écran
  /// peuvent tous deux conclure, il ne faut ni double DELETE ni double
  /// réinsertion.
  bool _resolved = false;

  PendingNotificationDeletion({
    required this.entries,
    required this.removedUnread,
  });

  bool get isEmpty => entries.isEmpty;

  bool get isResolved => _resolved;

  List<String> get ids => entries.map((e) => e.notification.id).toList();
}

class NotificationProvider extends ChangeNotifier {
  final InboxRepository _inbox = InboxRepository();

  /// Ids retirés localement mais pas encore confirmés côté serveur : ils sont
  /// filtrés des réponses réseau pour ne pas réapparaître pendant le délai
  /// d'annulation.
  final Set<String> _pendingDeletionIds = {};

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _unreadCount = 0;
  int _page = 1;
  int _lastPage = 1;
  bool _fetchFailed = false;
  bool _fromCache = false;
  DateTime? _lastSyncAt;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  /// Premier chargement : rien à afficher, un indicateur plein écran est légitime.
  bool get isInitialLoading => _isLoading && _notifications.isEmpty;

  /// Rafraîchissement d'une liste déjà affichée : l'indicateur doit rester
  /// discret (ne jamais remplacer la liste).
  bool get isRefreshing => _isLoading && _notifications.isNotEmpty;

  bool get isLoadingMore => _isLoadingMore;

  /// Compteur de non-lus. Source de vérité : `unread_count` renvoyé par l'API ;
  /// il n'est jamais recalculé à partir des seuls éléments chargés (pagination),
  /// seulement ajusté par delta lors des actions locales.
  int get unreadCount => _unreadCount;
  bool get hasMore => _page < _lastPage;
  bool get fetchFailed => _fetchFailed;

  /// `true` quand ce qui est affiché provient du cache local ET que le dernier
  /// appel réseau a échoué : l'écran affiche alors un bandeau « hors ligne ».
  /// (Pas de bandeau pendant le tout premier chargement, tant que le serveur
  /// n'a pas répondu.)
  bool get isStale => _fromCache && _fetchFailed && _notifications.isNotEmpty;

  /// Date de la dernière synchronisation serveur réussie (peut venir du disque).
  DateTime? get lastSyncAt => _lastSyncAt;

  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _page = 1;
    _lastPage = 1;
    _fetchFailed = false;
    _fromCache = false;
    _lastSyncAt = null;
    _pendingDeletionIds.clear();
    notifyListeners();
    NotificationService().updateBadge(0);
    _inbox.clearLastSync();
  }

  int _indexOfId(String id) => _notifications.indexWhere((n) => n.id == id);

  void _setUnread(int value) {
    _unreadCount = value < 0 ? 0 : value;
  }

  /// Injecte instantanément une notification depuis les données du push FCM.
  ///
  /// Si le backend a fourni `notification_id`, l'entrée porte l'id réel et les
  /// actions serveur sont permises tout de suite. Sinon c'est un placeholder
  /// local inerte, dédoublonné par type + entité pour disparaître au fetch.
  void addFromPush(Map<String, dynamic> pushData) {
    final key = NotificationRoute.dedupeKey(pushData);
    final notification = NotificationModel.fromPush(pushData, dedupeKey: key);

    // Un placeholder plus ancien pour la même entité est remplacé (et son
    // non-lu décompté) avant tout ajout.
    final stale = _notifications
        .where((n) => n.isPlaceholder && n.dedupeKey == key)
        .toList();
    if (stale.isNotEmpty) {
      _notifications.removeWhere((n) => n.isPlaceholder && n.dedupeKey == key);
      _setUnread(_unreadCount - stale.where((n) => !n.isRead).length);
    }

    // Une même notification peut arriver deux fois (push + reprise) : si la
    // ligne réelle est déjà là, on ne duplique pas.
    final duplicate = _notifications.any(
      (n) => n.id == notification.id || n.dedupeKey == notification.dedupeKey,
    );
    if (duplicate) {
      if (stale.isNotEmpty) {
        notifyListeners();
        NotificationService().updateBadge(_unreadCount);
      }
      return;
    }

    _notifications.insert(0, notification);
    if (!notification.isRead) _setUnread(_unreadCount + 1);
    notifyListeners();
    NotificationService().upsertCachedNotification(notification);
    NotificationService().updateBadge(_unreadCount);
  }

  /// Écarte les lignes dont la suppression est en cours d'annulation.
  List<NotificationModel> _withoutPendingDeletions(
    List<NotificationModel> items,
  ) {
    if (_pendingDeletionIds.isEmpty) return items;
    return items.where((n) => !_pendingDeletionIds.contains(n.id)).toList();
  }

  Future<void> _hydrateFromCache() async {
    final cached =
        _withoutPendingDeletions(await NotificationService().loadCachedNotifications());
    if (cached.isEmpty) return;
    _notifications = cached;
    // Repli hors ligne : en l'absence de réponse serveur, le cache est la seule
    // source disponible. Écrasé par `unread_count` au premier fetch réussi.
    _setUnread(cached.where((n) => !n.isRead).length);
    _fromCache = true;
    _lastSyncAt ??= await _inbox.loadLastSync();
    notifyListeners();
  }

  /// Recharge la première page. En cas d'échec réseau, la liste affichée
  /// (cache ou page précédente) n'est JAMAIS écrasée : on lève seulement
  /// `fetchFailed` / `isStale` pour que l'écran le signale.
  Future<void> fetch({bool fromCacheFirst = true}) async {
    if (_isLoading) return;

    if (fromCacheFirst && _notifications.isEmpty) {
      await _hydrateFromCache();
    }

    _isLoading = true;
    notifyListeners();

    final page = await NotificationService().getNotifications(page: 1);

    if (page.success) {
      _page = page.currentPage;
      _lastPage = page.lastPage;
      _setUnread(page.unreadCount);
      _notifications = InboxMerge.mergePushPlaceholders(
        _withoutPendingDeletions(page.items),
        _notifications,
      );
      _fetchFailed = false;
      _fromCache = false;
      _lastSyncAt = DateTime.now();
      NotificationService().updateBadge(_unreadCount);
      await NotificationService().saveCachedNotifications(_notifications);
      await _inbox.saveLastSync(_lastSyncAt!);
    } else {
      _fetchFailed = true;
      // Dernière chance : si rien n'est affiché, on tente quand même le cache.
      if (_notifications.isEmpty) {
        await _hydrateFromCache();
      } else {
        _fromCache = true;
        _lastSyncAt ??= await _inbox.loadLastSync();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();

    final next = await NotificationService().getNotifications(page: _page + 1);
    if (!next.success) {
      _isLoadingMore = false;
      _fetchFailed = true;
      notifyListeners();
      return;
    }
    _page = next.currentPage;
    _lastPage = next.lastPage;
    _setUnread(next.unreadCount);
    final existingIds = _notifications.map((n) => n.id).toSet();
    for (final item in _withoutPendingDeletions(next.items)) {
      if (existingIds.contains(item.id)) continue;
      _notifications.removeWhere(
        (n) => n.isPlaceholder && n.dedupeKey == item.dedupeKey,
      );
      _notifications.add(item);
    }
    _isLoadingMore = false;
    notifyListeners();
    await NotificationService().saveCachedNotifications(_notifications);
  }

  /// Alias historique : toutes les opérations se font par id.
  Future<bool> markAsReadById(String id) => markAsRead(id);

  /// Marque une notification comme lue. Aucun appel API n'est émis pour un
  /// placeholder local (id `push_*`) : l'entrée reste inerte jusqu'au fetch.
  Future<bool> markAsRead(String id) async {
    final index = _indexOfId(id);
    if (index < 0) return false;

    final previous = _notifications[index];
    if (previous.isRead) return true;

    final updated = previous.copyWith(
      readAt: DateTime.now().toUtc().toIso8601String(),
    );
    _notifications[index] = updated;
    _setUnread(_unreadCount - 1);
    notifyListeners();
    NotificationService().upsertCachedNotification(updated);

    if (previous.isPlaceholder) {
      NotificationService().updateBadge(_unreadCount);
      return true;
    }

    final success = await NotificationService().markAsRead(id);
    if (!success) {
      // Rollback par id : la liste a pu bouger pendant l'appel réseau.
      final rollbackIndex = _indexOfId(id);
      if (rollbackIndex >= 0) {
        _notifications[rollbackIndex] = previous;
      }
      _setUnread(_unreadCount + 1);
      notifyListeners();
      NotificationService().upsertCachedNotification(previous);
      return false;
    }
    NotificationService().updateBadge(_unreadCount);
    return true;
  }

  Future<bool> markAllAsRead() async {
    final snapshot = List<NotificationModel>.from(_notifications);
    final previousUnread = _unreadCount;
    final now = DateTime.now().toUtc().toIso8601String();

    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(readAt: now);
      }
    }
    _setUnread(0);
    notifyListeners();
    NotificationService().updateBadge(0);

    final success = await NotificationService().markAllAsRead();
    if (!success) {
      _notifications = snapshot;
      _setUnread(previousUnread);
      notifyListeners();
      NotificationService().updateBadge(_unreadCount);
      return false;
    }
    await NotificationService().saveCachedNotifications(_notifications);
    return true;
  }

  /// Supprime par id. Les placeholders locaux ne sont jamais envoyés à l'API ;
  /// en cas d'échec serveur la liste est restaurée à l'identique (ordre inclus).
  Future<bool> deleteNotifications(List<String> ids) async {
    if (ids.isEmpty) return true;
    final targets = ids.toSet();
    final snapshot = List<NotificationModel>.from(_notifications);
    final removedUnread =
        _notifications.where((n) => targets.contains(n.id) && !n.isRead).length;

    _notifications.removeWhere((n) => targets.contains(n.id));
    _setUnread(_unreadCount - removedUnread);
    notifyListeners();
    NotificationService().updateBadge(_unreadCount);

    final serverIds = snapshot
        .where((n) => targets.contains(n.id) && !n.isPlaceholder)
        .map((n) => n.id)
        .toList();

    var success = true;
    if (serverIds.isNotEmpty) {
      success = await NotificationService().deleteNotifications(serverIds);
    }
    if (!success) {
      _notifications = snapshot;
      _setUnread(_unreadCount + removedUnread);
      notifyListeners();
      NotificationService().updateBadge(_unreadCount);
      return false;
    }
    await NotificationService().deleteCachedNotifications(targets.toList());
    return true;
  }

  /// Retire immédiatement des notifications de la liste SANS appeler l'API et
  /// renvoie un jeton de restauration (suppression par glissement).
  ///
  /// L'appelant doit conclure par [restoreRemoved] (bouton « Annuler ») ou par
  /// [confirmRemoval] (SnackBar refermée) — sinon la suppression n'est jamais
  /// propagée au serveur.
  PendingNotificationDeletion removeForUndo(List<String> ids) {
    if (ids.isEmpty) {
      return PendingNotificationDeletion(entries: const [], removedUnread: 0);
    }
    final targets = ids.toSet();
    final removed = <RemovedNotification>[];
    for (var i = 0; i < _notifications.length; i++) {
      if (targets.contains(_notifications[i].id)) {
        removed.add(
          RemovedNotification(index: i, notification: _notifications[i]),
        );
      }
    }
    if (removed.isEmpty) {
      return PendingNotificationDeletion(entries: const [], removedUnread: 0);
    }

    final removedUnread =
        removed.where((e) => !e.notification.isRead).length;
    _notifications.removeWhere((n) => targets.contains(n.id));
    _pendingDeletionIds.addAll(removed.map((e) => e.notification.id));
    _setUnread(_unreadCount - removedUnread);
    notifyListeners();
    NotificationService().updateBadge(_unreadCount);

    return PendingNotificationDeletion(
      entries: removed,
      removedUnread: removedUnread,
    );
  }

  /// Annulation : chaque élément retrouve sa position d'origine.
  void restoreRemoved(PendingNotificationDeletion pending) {
    if (pending.isEmpty || pending._resolved) return;
    pending._resolved = true;
    _pendingDeletionIds.removeAll(pending.ids);

    // Index croissant : la liste ayant pu bouger entre-temps (push, fetch),
    // on borne l'index et on ignore ce qui est déjà revenu.
    for (final entry in pending.entries) {
      if (_notifications.any((n) => n.id == entry.notification.id)) continue;
      final index = entry.index.clamp(0, _notifications.length);
      _notifications.insert(index, entry.notification);
    }
    _setUnread(_unreadCount + pending.removedUnread);
    notifyListeners();
    NotificationService().updateBadge(_unreadCount);
  }

  /// Confirmation : la suppression part enfin vers l'API. En cas d'échec, les
  /// éléments sont remis en place et `false` est renvoyé.
  Future<bool> confirmRemoval(PendingNotificationDeletion pending) async {
    if (pending.isEmpty || pending._resolved) return true;
    pending._resolved = true;
    _pendingDeletionIds.removeAll(pending.ids);

    final serverIds = pending.entries
        .where((e) => !e.notification.isPlaceholder)
        .map((e) => e.notification.id)
        .toList();

    var success = true;
    if (serverIds.isNotEmpty) {
      success = await NotificationService().deleteNotifications(serverIds);
    }
    if (!success) {
      // Le jeton a déjà été consommé : on rouvre la restauration une fois.
      pending._resolved = false;
      restoreRemoved(pending);
      return false;
    }
    await NotificationService().deleteCachedNotifications(pending.ids);
    return true;
  }
}
