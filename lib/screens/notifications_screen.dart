import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _selectedIds = {};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetch();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final isLoading = provider.isLoading;

    final isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: Text(isSelectionMode ? '${_selectedIds.length}' : l10n.notifications),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                final idsToDelete = _selectedIds.toList();
                provider.deleteNotifications(idsToDelete).then((success) {
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de la suppression')),
                    );
                  }
                });
                _clearSelection();
              },
              tooltip: l10n.delete,
            )
          else
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: notifications.any((n) => !n.isRead)
                  ? () {
                      provider.markAllAsRead().then((success) {
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.errorMarkAllNotifRead)),
                          );
                        }
                      });
                    }
                  : null,
              tooltip: 'Tout marquer comme lu',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.fetch,
              child: notifications.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(child: Text(l10n.noNotifications)),
                      ],
                    )
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        final isRead = notif.isRead;
                        final isSelected = _selectedIds.contains(notif.id);

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.blue.withOpacity(0.2),
                          tileColor: isRead ? null : Colors.blue.withOpacity(0.1),
                          leading: isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(notif.id),
                                )
                              : Icon(
                                  isRead ? Icons.notifications_none : Icons.notifications_active,
                                  color: isRead ? Colors.grey : Colors.blue,
                                ),
                          title: Text(notif.message),
                          subtitle: Text(_formatDate(notif.createdAt)),
                          onLongPress: () => _toggleSelection(notif.id),
                          onTap: () {
                            if (isSelectionMode) {
                              _toggleSelection(notif.id);
                              return;
                            }
                            if (!isRead) {
                              provider.markAsRead(notif.id, index).then((success) {
                                if (!success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.errorMarkNotifRead)),
                                  );
                                }
                              });
                            }
                            NotificationService().handleNotificationData(notif.data);
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
