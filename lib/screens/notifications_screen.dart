import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (userProvider.user != null) {
      // Use addPostFrameCallback to ensure this happens after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationProvider.initializeNotifications(userProvider.user!.uid);
      });
    }
  }

  Widget _buildNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.comment;
        iconColor = Colors.blue;
        break;
      case 'friend_request':
        iconData = Icons.person_add;
        iconColor = Colors.green;
        break;
      case 'event':
        iconData = Icons.event;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              if (userProvider.user != null) {
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAllAsRead(userProvider.user!.uid);
              }
            },
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${notificationProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (notificationProvider.notifications.isEmpty) {
            return const Center(
              child: Text('No notifications yet'),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              itemCount: notificationProvider.notifications.length,
              itemBuilder: (context, index) {
                final notification = notificationProvider.notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    notificationProvider.deleteNotification(notification.id);
                  },
                  child: ListTile(
                    leading: _buildNotificationIcon(notification.type),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.message),
                        Text(
                          timeago.format(notification.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!notification.isRead) {
                        notificationProvider.markAsRead(notification.id);
                      }
                      // Handle notification tap based on type and relatedId
                      switch (notification.type) {
                        case 'post':
                          if (notification.relatedId != null) {
                            // Navigate to post
                          }
                          break;
                        case 'friend_request':
                          if (notification.relatedId != null) {
                            // Navigate to friend request
                          }
                          break;
                        case 'event':
                          if (notification.relatedId != null) {
                            // Navigate to event
                          }
                          break;
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}