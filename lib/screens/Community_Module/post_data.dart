// lib/screens/Community_Module/post_data.dart

import 'package:flutter/material.dart';
import 'comment_data.dart'; // Import the new model

class PostData {
  final String initials;
  final String author;
  final String timeAgo;
  final String tag;
  final String title;
  final String content;
  final int likes;
  final List<CommentData> commentList;
  final bool isLiked;
  final bool showFollowButton;
  final Gradient profileGradient;
  final bool isFollowed;
  final String? videoUrl;
  
  // --- *** NEW FIELD *** ---
  final bool isEdited;
  // --- *** --- *** --- ---

  const PostData({
    required this.initials,
    required this.author,
    required this.timeAgo,
    required this.tag,
    required this.title,
    required this.content,
    required this.likes,
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
    
    // --- *** NEW FIELD *** ---
    // Add this to the constructor with a default value of false
    this.isEdited = false,
    // --- *** --- *** --- ---
  });

  // The copyWith method is updated
  PostData copyWith({
    String? initials,
    String? author,
    String? timeAgo,
    String? tag,
    String? title,
    String? content,
    int? likes,
    List<CommentData>? commentList,
    bool? isLiked,
    bool? showFollowButton,
    Gradient? profileGradient,
    bool? isFollowed,
    String? videoUrl,
    
    // --- *** NEW FIELD *** ---
    bool? isEdited,
    // --- *** --- *** --- ---
  }) {
    return PostData(
      initials: initials ?? this.initials,
      author: author ?? this.author,
      timeAgo: timeAgo ?? this.timeAgo,
      tag: tag ?? this.tag,
      title: title ?? this.title,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      commentList: commentList ?? this.commentList,
      isLiked: isLiked ?? this.isLiked,
      showFollowButton: showFollowButton ?? this.showFollowButton,
      profileGradient: profileGradient ?? this.profileGradient,
      isFollowed: isFollowed ?? this.isFollowed,
      videoUrl: videoUrl ?? this.videoUrl,
      
      // --- *** NEW FIELD *** ---
      isEdited: isEdited ?? this.isEdited,
      // --- *** --- *** --- ---
    );
  }
}