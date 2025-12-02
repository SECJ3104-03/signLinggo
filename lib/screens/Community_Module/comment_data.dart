// lib/screens/Community_Module/comment_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CommentData {
  final String? id; // Firebase Document ID
  final String author;
  final String initials;
  final String content;
  final DateTime timestamp; 
  final bool isLiked;
  final int likeCount;
  final bool isReply;

  CommentData({
    this.id,
    required this.author,
    required this.initials,
    required this.content,
    required this.timestamp,
    this.isLiked = false,
    this.likeCount = 0,
    this.isReply = false,
  });

  // Convert object to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'author': author,
      'initials': initials,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp), 
      'likeCount': likeCount,
      'isReply': isReply,
      'isLiked': isLiked, // Ensure we save this
    };
  }

  // Create object from Firebase Map
  factory CommentData.fromMap(Map<String, dynamic> map, String docId) {
    return CommentData(
      id: docId,
      author: map['author'] ?? 'Unknown',
      initials: map['initials'] ?? '?',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likeCount: map['likeCount'] ?? 0,
      isReply: map['isReply'] ?? false,
      // --- FIX: READ THE LIKED STATUS FROM DB ---
      isLiked: map['isLiked'] ?? false, 
    );
  }

  CommentData copyWith({
    String? id,
    String? author,
    String? initials,
    String? content,
    DateTime? timestamp,
    bool? isLiked,
    int? likeCount,
    bool? isReply,
  }) {
    return CommentData(
      id: id ?? this.id,
      author: author ?? this.author,
      initials: initials ?? this.initials,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isReply: isReply ?? this.isReply,
    );
  }
}