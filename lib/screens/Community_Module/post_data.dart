// lib/screens/Community_Module/post_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'comment_data.dart';

class PostData {
  final String id;
  final String initials;
  final String author;
  final DateTime timestamp;
  final String tag;
  final String title;
  final String content;
  final int likes;
  
  // --- NEW: Dedicated Integer for Feed Display ---
  final int commentCount; 
  
  // We keep this for compatibility, but the feed will use commentCount
  final List<CommentData> commentList; 
  
  final bool isLiked;
  final bool showFollowButton;
  final Gradient profileGradient;
  final bool isFollowed;
  final String? videoUrl;
  final String? imageUrl;
  final bool isEdited;

  const PostData({
    required this.id,
    required this.initials,
    required this.author,
    required this.timestamp,
    required this.tag,
    required this.title,
    required this.content,
    required this.likes,
    
    // --- NEW: Add to constructor with default 0 ---
    this.commentCount = 0, 
    
    this.commentList = const [],
    this.isLiked = false,
    this.showFollowButton = true,
    this.profileGradient = const LinearGradient(
      begin: Alignment(0.00, 0.00),
      end: Alignment(1.00, 1.00),
      colors: [Color(0xFF155CFB), Color(0xFF980FFA)],
    ),
    this.isFollowed = false,
    this.videoUrl,
    this.imageUrl,
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'initials': initials,
      'author': author,
      'timestamp': Timestamp.fromDate(timestamp),
      'tag': tag,
      'title': title,
      'content': content,
      'likes': likes,
      'commentCount': commentCount, // Save to DB
      'isLiked': isLiked,
      'showFollowButton': showFollowButton,
      'isFollowed': isFollowed,
      'videoUrl': videoUrl,
      'imageUrl': imageUrl,
      'isEdited': isEdited,
    };
  }

  factory PostData.fromMap(Map<String, dynamic> map, String docId) {
    return PostData(
      id: docId,
      initials: map['initials'] ?? '',
      author: map['author'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      tag: map['tag'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      likes: map['likes'] ?? 0,
      // Load from DB (Default to 0 if it doesn't exist yet)
      commentCount: map['commentCount'] ?? 0, 
      isLiked: map['isLiked'] ?? false,
      showFollowButton: map['showFollowButton'] ?? true,
      isFollowed: map['isFollowed'] ?? false,
      videoUrl: map['videoUrl'],
      imageUrl: map['imageUrl'],
      isEdited: map['isEdited'] ?? false,
      commentList: [], 
    );
  }

  PostData copyWith({
    String? id,
    String? initials,
    String? author,
    DateTime? timestamp,
    String? tag,
    String? title,
    String? content,
    int? likes,
    int? commentCount, // Add to copyWith
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