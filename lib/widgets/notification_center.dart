import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';

class NotificationCenter extends StatefulWidget {
  final String userId;

  const NotificationCenter({super.key, required this.userId});

  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  final _pushNotificationService = PushNotificationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pushNotificationService.streamUserNotifications(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No notifications yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final notifications = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications (${notifications.length})',
                      style: Theme.of(context).textTheme.titleLarge),
                  ElevatedButton.icon(
                    onPressed: () => _markAllAsRead(),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark All as Read'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification['read'] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: isRead ? 0 : 4,
                    child: ListTile(
                      leading: Icon(
                        _getNotificationIcon(notification['type']),
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                      title: Text(
                        notification['title'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(notification['body'] ?? ''),
                      trailing: PopupMenuButton(
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            child: const Text('Mark as read'),
                            onTap: () {
                              _markAsRead(notification['id']);
                            },
                          ),
                          PopupMenuItem(
                            child: const Text('Delete'),
                            onTap: () {
                              _deleteNotification(notification['id']);
                            },
                          ),
                        ],
                      ),
                      onTap: !isRead ? () => _markAsRead(notification['id']) : null,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order_placed':
        return Icons.shopping_cart;
      case 'delivery_assigned':
        return Icons.local_shipping;
      case 'delivery_in_progress':
        return Icons.directions_car;
      case 'delivery_completed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _pushNotificationService.markNotificationAsRead(notificationId);
  }

  Future<void> _markAllAsRead() async {
    await _pushNotificationService.markAllNotificationsAsRead(widget.userId);
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _pushNotificationService.deleteNotification(notificationId);
  }
}

/// Notification badge widget to show unread count
class NotificationBadge extends StatelessWidget {
  final String userId;

  const NotificationBadge({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final pushNotificationService = PushNotificationService();

    return FutureBuilder<int>(
      future: pushNotificationService.getUnreadNotificationCount(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == 0) {
          return IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotificationCenter(context),
          );
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => _showNotificationCenter(context),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '${snapshot.data}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: NotificationCenter(userId: userId),
      ),
    );
  }
}
