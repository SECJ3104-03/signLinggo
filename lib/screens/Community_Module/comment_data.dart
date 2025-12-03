// lib/screens/Community_Module/comment_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CommentData {
  final String? id; 
  final String authorId; // --- NEW: ID of the person who commented ---
  final String author;
  final String initials;
  final String content;
  final DateTime timestamp; 
  final int likeCount;
  final bool isReply;
  final bool isLiked; 

  CommentData({
    this.id,
    required this.authorId, // Required
    required this.author,
    required this.initials,
    required this.content,
    required this.timestamp,
    this.likeCount = 0,
    this.isReply = false,
    this.isLiked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId, // Save to DB
      'author': author,
      'initials': initials,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp), 
      'likeCount': likeCount,
      'isReply': isReply,
    };
  }

  factory CommentData.fromMap(Map<String, dynamic> map, String docId, String currentUserId) {
    List<String> likedBy = List<String>.from(map['likedBy'] ?? []);

    return CommentData(
      id: docId,
      authorId: map['authorId'] ?? '', // Load from DB
      author: map['author'] ?? 'Unknown',
      initials: map['initials'] ?? '?',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likeCount: map['likeCount'] ?? 0,
      isReply: map['isReply'] ?? false,
      isLiked: likedBy.contains(currentUserId), 
    );
  }

  CommentData copyWith({
    String? id,
    String? authorId,
    String? author,
    String? initials,
    String? content,
    DateTime? timestamp,
    int? likeCount,
    bool? isReply,
    bool? isLiked,
  }) {
    return CommentData(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      initials: initials ?? this.initials,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      likeCount: likeCount ?? this.likeCount,
      isReply: isReply ?? this.isReply,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}