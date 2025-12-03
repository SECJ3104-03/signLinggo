// lib/screens/Community_Module/notification_screen.dart

import 'package:flutter/material.dart';
import 'notification_data.dart';
import 'firestore_service.dart';
import 'real_time_widget.dart'; 

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Mark notifications as read when screen opens
    _firestoreService.markAllNotificationsAsRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<List<NotificationData>>(
        stream: _firestoreService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications"));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationItem(notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationData notif) {
    IconData icon;
    Color iconColor;
    String actionText;

    switch (notif.type) {
      case 'like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        actionText = "liked your post";
        break;
      
      // --- FIXED: ADDED THIS CASE ---
      case 'comment_like':
        icon = Icons.favorite_border;
        iconColor = Colors.pink;
        actionText = "liked your comment";
        break;
      // ------------------------------

      case 'comment':
        icon = Icons.chat_bubble;
        iconColor = Colors.blue;
        actionText = "commented: \"${notif.previewText ?? ''}\"";
        break;
      case 'follow':
        icon = Icons.person_add;
        iconColor = Colors.purple;
        actionText = "started following you";
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
        actionText = "sent a notification";
    }

    return Container(
      color: notif.isRead ? Colors.white : Colors.blue.withOpacity(0.05),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: Text(
                notif.senderInitials,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ),
          ],
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontSize: 14),
            children: [
              TextSpan(
                text: "${notif.senderName} ",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: actionText),
            ],
          ),
        ),
        subtitle: RealTimeTimestamp(
          timestamp: notif.timestamp,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () {
          // Future: Navigate to the post
        },
      ),
    );
  }
}