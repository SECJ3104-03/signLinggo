// lib/screens/Community_Module/comment_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CommentData {
  final String? id; 
  final String authorId; 
  final String author;
  final String initials;
  final String content;
  final DateTime timestamp; 
  final int likeCount;
  final bool isReply;
  final bool isLiked; 
  final String? authorProfileImage; // --- NEW: Store profile picture ---

  CommentData({
    this.id,
    required this.authorId, 
    required this.author,
    required this.initials,
    required this.content,
    required this.timestamp,
    this.likeCount = 0,
    this.isReply = false,
    this.isLiked = false,
    this.authorProfileImage, // --- NEW ---
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId, 
      'author': author,
      'initials': initials,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp), 
      'likeCount': likeCount,
      'isReply': isReply,
      'authorProfileImage': authorProfileImage, // --- NEW: Save to DB ---
    };
  }

  factory CommentData.fromMap(Map<String, dynamic> map, String docId, String currentUserId) {
    List<String> likedBy = List<String>.from(map['likedBy'] ?? []);

    return CommentData(
      id: docId,
      authorId: map['authorId'] ?? '', 
      author: map['author'] ?? 'Unknown',
      initials: map['initials'] ?? '?',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      likeCount: map['likeCount'] ?? 0,
      isReply: map['isReply'] ?? false,
      isLiked: likedBy.contains(currentUserId), 
      authorProfileImage: map['authorProfileImage'], // --- NEW: Load from DB ---
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
    String? authorProfileImage, // --- NEW ---
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
      authorProfileImage: authorProfileImage ?? this.authorProfileImage, // --- NEW ---
    );
  }
}