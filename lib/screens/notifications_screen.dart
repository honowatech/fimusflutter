import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await NotificationService().getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    await NotificationService().markAsRead(id);
    _fetchNotifications();
  }

  Future<void> _markAllAsRead() async {
    await NotificationService().markAllAsRead();
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Tout marquer comme lu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('Aucune notification.'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['read_at'] != null;
                    final data = notif['data'] ?? {};
                    return ListTile(
                      tileColor: isRead ? null : Colors.blue.withOpacity(0.1),
                      leading: Icon(
                        isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                      title: Text(data['message'] ?? 'Nouvelle notification'),
                      subtitle: Text(notif['created_at'] ?? ''),
                      onTap: () {
                        if (!isRead) {
                          _markAsRead(notif['id']);
                        }
                      },
                    );
                  },
                ),
    );
  }
}
