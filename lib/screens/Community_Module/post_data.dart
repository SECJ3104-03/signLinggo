// lib/screens/Community_Module/post_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'comment_data.dart';

class PostData {
  final String id;
  final String authorId;
  final String initials;
  final String author;
  final DateTime timestamp;
  final String tag;
  final String title;
  final String content;
  final int likes;
  final int commentCount; 
  final List<CommentData> commentList; 
  
  // --- THESE ARE NOW CALCULATED ---
  final bool isLiked;
  final bool isFollowed;
  // --------------------------------

  final bool showFollowButton;
  final Gradient profileGradient;
  final String? videoUrl;
  final String? imageUrl;
  final bool isEdited;

  const PostData({
    required this.id,
    required this.authorId,
    required this.initials,
    required this.author,
    required this.timestamp,
    required this.tag,
    required this.title,
    required this.content,
    required this.likes,
    this.commentCount = 0, 
    this.commentList = const [],
    this.isLiked = false,
    this.isFollowed = false,
    this.showFollowButton = true,
    this.profileGradient = const LinearGradient(
      begin: Alignment(0.00, 0.00),
      end: Alignment(1.00, 1.00),
      colors: [Color(0xFF155CFB), Color(0xFF980FFA)],
    ),
    this.videoUrl,
    this.imageUrl,
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'initials': initials,
      'author': author,
      'timestamp': Timestamp.fromDate(timestamp),
      'tag': tag,
      'title': title,
      'content': content,
      'likes': likes,
      'commentCount': commentCount,
      // We don't save booleans. The DB uses arrays 'likedBy' and 'followers'.
      'showFollowButton': showFollowButton,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'isEdited': isEdited,
    };
  }

  // --- UPDATED: Receive currentUserId to calculate state ---
  factory PostData.fromMap(Map<String, dynamic> map, String docId, String currentUserId) {
    // 1. Get Lists
    List<String> likedBy = List<String>.from(map['likedBy'] ?? []);
    List<String> followers = List<String>.from(map['followers'] ?? []);

    return PostData(
      id: docId,
      authorId: map['authorId'] ?? '',
      initials: map['initials'] ?? '',
      author: map['author'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      tag: map['tag'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      likes: map['likes'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      
      // 2. Calculate State based on ID
      isLiked: likedBy.contains(currentUserId),
      isFollowed: followers.contains(currentUserId),
      
      showFollowButton: map['showFollowButton'] ?? true,
      videoUrl: map['videoUrl'],
      imageUrl: map['imageUrl'],
      isEdited: map['isEdited'] ?? false,
      commentList: [], 
    );
  }

  PostData copyWith({
    String? id,
    String? authorId,
    String? initials,
    String? author,
    DateTime? timestamp,
    String? tag,
    String? title,
    String? content,
    int? likes,
    int? commentCount,
    List<CommentData>? commentList,
    bool? isLiked,
    bool? showFollowButton,
    Gradient? profileGradient,
    bool? isFollowed,
    String? videoUrl,
    String? imageUrl,
    bool? isEdited,
  }) {
    return PostData(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      initials: initials ?? this.initials,
      author: author ?? this.author,
      timestamp: timestamp ?? this.timestamp,
      tag: tag ?? this.tag,
      title: title ?? this.title,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      commentList: commentList ?? this.commentList,
      isLiked: isLiked ?? this.isLiked,
      showFollowButton: showFollowButton ?? this.showFollowButton,
      profileGradient: profileGradient ?? this.profileGradient,
      isFollowed: isFollowed ?? this.isFollowed,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}