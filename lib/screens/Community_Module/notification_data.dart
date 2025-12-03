// lib/screens/Community_Module/notification_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { like, comment, follow }

class NotificationData {
  final String? id;          // Database ID
  final String recipientId;  // User receiving the notification (e.g., 'You')
  final String senderName;   // User who triggered it
  final String senderInitials;
  final String type;         // 'like', 'comment', or 'follow'
  final String? postId;      // ID of the post (null if it's just a follow)
  final String? previewText; // Snippet of comment or post title
  final DateTime timestamp;
  final bool isRead;

  NotificationData({
    this.id,
    required this.recipientId,
    required this.senderName,
    required this.senderInitials,
    required this.type,
    this.postId,
    this.previewText,
    required this.timestamp,
    this.isRead = false,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderName': senderName,
      'senderInitials': senderInitials,
      'type': type,
      'postId': postId,
      'previewText': previewText,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  // Create from Firebase
  factory NotificationData.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationData(
      id: docId,
      recipientId: map['recipientId'] ?? '',
      senderName: map['senderName'] ?? 'Someone',
      senderInitials: map['senderInitials'] ?? '?',
      type: map['type'] ?? 'like',
      postId: map['postId'],
      previewText: map['previewText'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }
}